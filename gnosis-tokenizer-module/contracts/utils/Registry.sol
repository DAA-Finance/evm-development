// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import {IAaveProtocolDataProvider} from "../connectors/polygon/aave/interfaces.sol";
import {IAaveLendingPoolAddressesProvider} from "../connectors/polygon/aave/interfaces.sol";

contract Registry {
    // Aave Lending Pool Provider
    IAaveProtocolDataProvider constant internal aaveProvider = IAaveProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);
    IAaveLendingPoolAddressesProvider constant internal aaveAddressProvider = IAaveLendingPoolAddressesProvider(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);
}
