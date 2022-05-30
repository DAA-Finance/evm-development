// SPDX-License-Identifier: unlicensed
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract OracleHandler is Ownable, ChainlinkClient{
    using SafeERC20 for IERC20; 
    using EnumerableSet for EnumerableSet.AddressSet;
    using Chainlink for Chainlink.Request;

    mapping(address => AggregatorV3Interface) public priceFeeds;

    // chainlink variables
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    address public constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; //on polygon

    constructor(){
        AggregatorV3Interface ethFeed = AggregatorV3Interface(0xF9680D99D6C9589e2a93a78A04A279e509205945);
        priceFeeds[WETH] = ethFeed;
    }

    /**
     * Returns the latest price
     */
    function getETHLatestPrice() public view returns (int) 
    {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeeds[WETH].latestRoundData();
        return price;
    }

    function getExchangeRate(address token) public view returns (uint){
        (
            uint80 roundID, 
            int usdPrice,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeeds[token].latestRoundData();
        uint8 quoteDecimals = priceFeeds[token].decimals();
        uint scaledPrice = uint(scalePrice(usdPrice,quoteDecimals, 6)); // base currency has 6 decimals
        return scaledPrice;
    }

    function getDerivedPrice(address _base, address _quote, uint8 _decimals)
        public
        view
        returns (int256)
    {
        require(_decimals > uint8(0) && _decimals <= uint8(18), "Invalid _decimals");
        int256 decimals = int256(10 ** uint256(_decimals));
        ( , int256 basePrice, , , ) = AggregatorV3Interface(_base).latestRoundData();
        uint8 baseDecimals = AggregatorV3Interface(_base).decimals();
        basePrice = scalePrice(basePrice, baseDecimals, _decimals);

        ( , int256 quotePrice, , , ) = AggregatorV3Interface(_quote).latestRoundData();
        uint8 quoteDecimals = AggregatorV3Interface(_quote).decimals();
        quotePrice = scalePrice(quotePrice, quoteDecimals, _decimals);

        return basePrice * decimals / quotePrice;
    }

    function scalePrice(int256 _price, uint8 _priceDecimals, uint8 _decimals)
        public
        pure
        returns (int256)
    {
        if (_priceDecimals < _decimals) {
            return _price * int256(10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _decimals));
        }
        return _price;
    }

    function addTokenOracle(address token, address quoter) external onlyOwner {
        AggregatorV3Interface tokenFeed = AggregatorV3Interface(quoter);
        priceFeeds[token] = tokenFeed;
    }

}
