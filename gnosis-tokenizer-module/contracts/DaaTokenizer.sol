// SPDX-License-Identifier: unlicensed
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GnosisSafe } from "../interfaces/IGnosisSafe.sol";

import "./utils/Enum.sol";

/// @title Module DAA - A Smart Contract allowing tokenization of deposits and shares redemption.
/// @dev Test only - Not prod ready

interface IPositionManager{
    function getNetPositionValue(address asset) external view returns (uint);
}

interface ITokenizedShare{
    function totalSupply() external view returns (uint);
    function mint(address receiver, uint amount) external returns (bool);
    function burn(address sender, uint amount) external;
}

interface IOracleHandler{
    function getETHLatestPrice() external view returns (int);
    function getDerivedPrice(address _base, address _quote, uint8 _decimals)
        external
        view
        returns (int256);
    function scalePrice(int256 _price, uint8 _priceDecimals, uint8 _decimals)
        external
        pure
        returns (int256);
    function getExchangeRate(address token) external view returns (uint);
}


contract DaaTokenizer {
    using SafeERC20 for IERC20; 
    using EnumerableSet for EnumerableSet.AddressSet;

    
    address public owner;
    address payable public _whitelisted;
    GnosisSafe public _safe;
    IPositionManager public _positionManager;
    ITokenizedShare public _tokenizedShare;
    IOracleHandler public _oracleHandler;
    EnumerableSet.AddressSet private _spenders;
    bool public initialized;

    // list of allowed asset addresses
    EnumerableSet.AddressSet private allowedAssets;
    // list of base currencies
    address[] public baseCurrencies;
    // authorized currency tickers on platform
    mapping(string => bool)  _AuthorizedCurrencyTickers;
    // mapping token name to blockchain addresses
    mapping(string => address) private _erc20Contracts;


    event DepositReceived(address indexed safe, address token, uint amount, uint sharesIssued);
    event Withdrawal(address indexed safe, address withdrawer, uint nOfShares, uint baseCurrencyAmount);

    // constructor(){}

    function initialize(GnosisSafe safe) public {
        require(!initialized); //dev: Already initialized
        owner = msg.sender;
        _whitelisted = payable(address(this));
        _safe = safe;
        addSupportedCurrency("USDC", 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, true);//check address checksum
        initialized = true;
    }

    /// @dev Deposit funds
    /// @param currencyTicker string description of the deposited currency (e.g. USDC)
    /// @param amount The amount to be deposited
    function deposit(
        string calldata currencyTicker,
        uint256 amount
    )
        external 
        returns (uint)
    {
        require(_AuthorizedCurrencyTickers[currencyTicker]); // dev: currency not allowed
        // calculate fund nav
        uint pricePerShare = getPricePerShare();
        // transfer deposit to safe
        address erc20contract = _erc20Contracts[currencyTicker];
        IERC20(erc20contract).safeTransferFrom(msg.sender, address(_safe), amount);
        // calculate shares to issue
        uint tokenValue = getTokenValueUsd(erc20contract, amount);
        uint sharesToIssue = tokenValue * 10**6  / pricePerShare ;
        _tokenizedShare.mint(msg.sender, sharesToIssue);

        emit DepositReceived(address(_safe) , erc20contract, amount, sharesToIssue);
        return sharesToIssue;
    }

    /// @dev Redeem deposited funds by burning shares
    /// @param nOfShares to burn, (e.g. 1 share - 1000000)
    function redeem(uint nOfShares) external returns (bool){
        require(nOfShares > 0); //dev: number of shares to redeem must be > 0
        uint baseAmount = calcBaseAmount(nOfShares);   
        _burnShares(msg.sender,nOfShares);
        _withdraw(msg.sender, baseAmount);
        emit Withdrawal(address(_safe), msg.sender, nOfShares, baseAmount);
    }

    /// @dev Withdraw tokenizer funds back to Safe
    /// @param token The address of token 
    /// @amount The amount of token to send
    function withdrawToSafe(address token, uint amount) 
        external 
        isAuthorized(msg.sender)
    {
        // transfer from address(this) to safe
        _sendFunds(_safe,token,amount);
    }

    // should be onlyOwner or internal, depending on flexibility wanted
    function setPositionManager(IPositionManager positionManager) external onlyOwner {
        _positionManager = IPositionManager(positionManager);
    }

    // should be onlyOwner or internal, depending on flexibility wanted
    function setTokenizedShare(ITokenizedShare tokenizedShare) external onlyOwner {
        _tokenizedShare = ITokenizedShare(tokenizedShare);
    }

    // should be onlyOwner or internal, depending on flexibility wanted
    function setOracleHandler(IOracleHandler oracleHandler) external onlyOwner {
        _oracleHandler = IOracleHandler(oracleHandler);
    }

    function checkFundsAvailability(address token, uint amount) public view returns (uint){
        uint liquidBalance = IERC20(token).balanceOf(address(this));
        uint availableAmount = 0;
        if (liquidBalance >= amount){
            availableAmount = amount;
        } else if (liquidBalance>0){
            availableAmount = liquidBalance;
        }
        return availableAmount;
    }

    function getPricePerShare() public view returns (uint) {
        uint sharesOutstanding = getTotalSharesOutstanding();
        if (sharesOutstanding == 0){
            return 10**6;
        } else {
            uint nav = calculateNav();
            return nav * 10**6 / sharesOutstanding;
        }
    }

    function calcBaseAmount(uint shares) public view returns(uint){
        uint pricePerShare = getPricePerShare();
        return (shares * pricePerShare / 10**6);
    }

    function calculateNav() public view returns (uint) {
        // this allows smooth provision of a liquidity buffer to tokenizer
        return (_calculateNav(address(_safe))+_calculateNav(address(this)));
    }

    function _calculateNav(address _targetAddress) internal view returns (uint){
        uint256[] memory internalBalances = new uint256[](allowedAssets.length());
        uint256[] memory usdBalances = new uint256[](allowedAssets.length());
        uint nav = 0;

        uint length = allowedAssets.length();
        for (uint256 i; i < length; i++) {
            internalBalances[i] = IERC20(allowedAssets.at(i)).balanceOf(address(_targetAddress));
        }

        uint256[] memory allBalances = addExternalAssetsNominal(allowedAssets, internalBalances);

        usdBalances = calcAssetsValueUsd(allowedAssets, allBalances);

        for (uint256 i; i < length; i++) {
            nav += usdBalances[i];
        } 
        
        return nav;
    }

    /// @dev Add supported currency for deposits
    /// @param currencyTicker String representing the currency (e.g. "USDC")
    /// @param erc20Contract The contract address of the currency
    function addSupportedCurrency(
        string memory currencyTicker,
        address erc20Contract,
        bool isBase
    ) 
        public
        onlyOwner 
    {
        _AuthorizedCurrencyTickers[currencyTicker] = true;
        _erc20Contracts[currencyTicker] = erc20Contract;
        allowedAssets.add(erc20Contract);
        if (isBase){ _addBaseCurrency(erc20Contract);}
    }

    /// @dev Get the amount of shares minted to date
    function getTotalSharesOutstanding() public view returns (uint){
        return _tokenizedShare.totalSupply();
    }

    function _withdraw(address _to, uint amount) internal {
        uint len = baseCurrencies.length;
        uint[] memory baseCurrencyAmount = new uint[](len);
        uint available = 0;
        uint amountLeft = amount;
        for (uint i =0; i< len; i++) {
            baseCurrencyAmount[i] = 0;
            if(amountLeft > 0){
                available = checkFundsAvailability(baseCurrencies[i], amountLeft);
                amountLeft -= available;
                baseCurrencyAmount[i] = available;
            }
        }
        require(amountLeft == 0, "Not enough funds in tokenizer");
        for (uint i =0; i< len; i++) {
            if ( baseCurrencyAmount[i]> 0){
                _sendFunds(_to, baseCurrencies[i], baseCurrencyAmount[i]);
            }
        }
    }

    function _sendFunds(address receiver, address token, uint amount) internal {
        IERC20(token).approve(address(this),amount);
        IERC20(token).safeTransferFrom(address(this), receiver, amount);
    }

    function _burnShares(address sender, uint amount) internal {
        _tokenizedShare.burn(sender, amount);
    }

    function _addBaseCurrency(address token) internal {
        require(IERC20Metadata(token).decimals() == 6); //dev: base currency needs 6 decimals 
        baseCurrencies.push(token);
    }

    function addExternalAssetsNominal(
        EnumerableSet.AddressSet storage assets,
        uint[] memory balances
    ) 
        internal 
        view 
        returns (uint256[] memory)
    {
        uint length = assets.length();
        for (uint256 i; i < length; i++) { 
            balances[i] += _positionManager.getNetPositionValue(assets.at(i));
        }
        return balances;
    }

    function calcAssetsValueUsd(EnumerableSet.AddressSet storage assets, uint[] memory balances) 
        internal 
        view 
        returns (uint[] memory)
    {
        uint len = balances.length;
        address asset;
        uint usdBalance;
        for(uint i = 0; i< len; i++){
            asset = assets.at(i);
            usdBalance = getTokenValueUsd(asset,balances[i]);
            balances[i] = usdBalance;
        }
        return balances;
    }

    function getTokenValueUsd(
        address token,
        uint amount
    ) 
        internal 
        view 
        returns (uint)
    {
        // assumes usd peg of base currency to hold
        if (isBaseCurrency(token)){
            return amount;
        } else {
            uint scaledPrice = _oracleHandler.getExchangeRate(token);
            uint tokenDecimals = IERC20Metadata(token).decimals();
            uint finalAmount = (scaledPrice*amount / 10**tokenDecimals);
            return finalAmount;
        }
    }

    // to do: test if using addressSet is more gas efficient
    function isBaseCurrency(address token) internal view returns (bool){
        uint len = baseCurrencies.length;
        for (uint i =0; i < len; i++){
            if (baseCurrencies[i] == token){
                return true;
            }
        }
        return false;
    }

    modifier isAuthorized(address sender) {
        address[] memory spenders = _safe.getOwners();
        uint256 len = spenders.length;
        for (uint256 i = 0; i < len; i++) {
            address spender = spenders[i];
            _spenders.add(spender);
        }
        require(_spenders.contains(sender), "Sender not authorized");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner); // dev: Not owner
        _;
    }

    receive() external payable{}
}
