// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {ITradeFactorySwapper} from "@periphery/swappers/interfaces/ITradeFactorySwapper.sol";

interface IStrategyInterface is IStrategy, ITradeFactorySwapper {
    function manualRewardsClaim() external;
    function setTradeFactory(address _tradeFactory) external;
    function addToken(address _token) external;
    function removeToken(address _token) external;
}
