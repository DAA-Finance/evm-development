// SPDX-License-Identifier: unlicensed
pragma solidity >=0.7.0 <0.9.0;

import {IAaveProtocolDataProvider,IAaveLendingPool, IAaveLendingPoolAddressesProvider} from "./interfaces.sol";
import { Adaptor} from "../../Adaptor.sol";
import { Registry } from "../../../utils/Registry.sol";
import {IERC20Minimal} from "../../../../interfaces/IERC20Minimal.sol";

contract AaveConnector is Adaptor, Registry {

    address constant internal maticAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant internal wmaticAddr = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    constructor(){}

    function getGrossDebt(address asset,address _target) public override view returns (uint grossDebt) {
        // (address aToken, address aStableDebt, address aVariableDebt) = aaveProvider.getReserveTokensAddresses(asset);
        (uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        uint256 principalStableDebt,
        uint256 scaledVariableDebt,
        uint256 stableBorrowRate,
        uint256 liquidityRate,
        uint40 stableRateLastUpdated,
        bool usageAsCollateralEnabled) = aaveProvider.getUserReserveData(asset, _target);
        return currentVariableDebt;
    }

    function getGrossValue(address asset, address _target) public override view returns (uint grossValue) {
        // (address aToken, address aStableDebt, address aVariableDebt) = aaveProvider.getReserveTokensAddresses(asset);
        (uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        uint256 principalStableDebt,
        uint256 scaledVariableDebt,
        uint256 stableBorrowRate,
        uint256 liquidityRate,
        uint40 stableRateLastUpdated,
        bool usageAsCollateralEnabled) = aaveProvider.getUserReserveData(asset, _target);
        return currentATokenBalance;
    }


    /**
     * @dev Deposit ETH/ERC20_Token.
     * @notice Deposit a token to Aave v2 for lending / collaterization.
     * @param token The address of the token to deposit.(For MATIC: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt The amount of the token to deposit. (For max: `uint256(-1)`)
    */
    function deposit(
        address token,
        uint256 amt
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {

        IAaveLendingPool aave = IAaveLendingPool(aaveAddressProvider.getLendingPool());
        bool isEth = token == maticAddr;
        address _token = isEth ? wmaticAddr : token;

        IERC20Minimal tokenContract = IERC20Minimal(_token);

        approve(tokenContract, address(aave), amt);

        aave.deposit(_token, amt, msg.sender, 0); //referral code here is 0

        _eventName = "LogDeposit(address,uint256)";
        _eventParam = abi.encode(token, amt);
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Aave v2
     * @param token The address of the token to borrow.(For MATIC: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt The amount of the token to borrow.
     * @param rateMode The type of borrow debt. (For Stable: 1, Variable: 2)
    */
    function borrow(
        address token,
        uint256 amt,
        uint256 rateMode
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {

        IAaveLendingPool aave = IAaveLendingPool(aaveAddressProvider.getLendingPool());
       
        bool isEth = token == maticAddr;
        address _token = isEth ? wmaticAddr : token;

        aave.borrow(_token, amt, rateMode, 0, msg.sender);
        IERC20Minimal tokenContract = IERC20Minimal(_token);
        approve(tokenContract, msg.sender, amt);
        tokenContract.transfer(msg.sender,amt);


        _eventName = "LogBorrow(address,uint256,uint256)";
        _eventParam = abi.encode(token, amt, rateMode);
    }

    function approve(IERC20Minimal token, address spender, uint256 amount) internal {
        try token.approve(spender, amount) {

        } catch {
            token.approve(spender, 0);
            token.approve(spender, amount);
        }
    }

}