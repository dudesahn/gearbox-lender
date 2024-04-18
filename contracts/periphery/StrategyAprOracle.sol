// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import "forge-std/console2.sol"; // @todo: remove all logs

// example of FE APY calcs: https://github.com/Gearbox-protocol/sdk/blob/next/src/gearboxRewards/apy.ts
// https://github.com/Gearbox-protocol/defillama/blob/7127e015b2dc3f47043292e8801d01930560003c/src/yield-server/index.ts#L242

interface IStrategy {
    function vault() external view returns (address);
    function staking() external view returns (address);
    function asset() external view returns (address);
}

interface IVault {
    function convertToShares(uint256) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function expectedLiquidity() external view returns (uint256);
    function baseInterestRate() external view returns (uint256);
    function totalBorrowed() external view returns (uint256);
    function quotaRevenue() external view returns (uint256);
    function withdrawFee() external view returns (uint256);
    function supplyRate() external view returns (uint256);
}

interface IStaking {
    function totalSupply() external view returns (uint256);
    function farmInfo() external view returns (uint40, uint32, uint184, uint256);
}

interface ICurvePool {
    function price_oracle() external view returns (uint256);
}

interface IChainLink {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract StrategyAprOracle is AprOracleBase {

    // Curve pool for GEAR pricing
    address internal constant GEAR_ETH_CURVE_POOL = 0x0E9B5B092caD6F1c5E6bc7f89Ffe1abb5c95F1C2;

    // Tokens
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // ChainLink feeds
    address internal constant CL_WETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant CL_BTC_USD = 0xdeb288F737066589598e9214E782fa5A8eD689e8;

    // Gearbox constants
    uint256 internal constant RAY = 1e27;
    uint16 internal constant PERCENTAGE_FACTOR = 1e4;
    uint256 internal constant SECONDS_PER_YEAR = 31536000;

    constructor() AprOracleBase("Strategy Apr Oracle Example", msg.sender) {}

    /**
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(address _strategy, int256 _delta) external view override returns (uint256) {
        IStrategy strategy = IStrategy(_strategy);
        IVault vault = IVault(strategy.vault());
        IStaking staking = IStaking(strategy.staking());

        // Step 1: Calculate native yield
        uint256 assets;
        if (_delta < 0) {
            assets = vault.expectedLiquidity() - uint256(-_delta);
        } else {
            assets = vault.expectedLiquidity() + uint256(_delta);
        }

        uint256 nativeYield = (vault.baseInterestRate() * vault.totalBorrowed() + vault.quotaRevenue() * RAY)
            * (PERCENTAGE_FACTOR - vault.withdrawFee()) / PERCENTAGE_FACTOR / assets / 1e9;

        // Step 2: Get exchange rate for the asset
        uint256 exchangeRate;
        if (strategy.asset() == WETH) {
            exchangeRate = 1e18;
        } else if (strategy.asset() == WBTC) {
            // Get latest BTC/USD and ETH/USD prices from ChainLink
            (, int256 btcPrice,,,) = IChainLink(CL_BTC_USD).latestRoundData();
            (, int256 ethPrice,,,) = IChainLink(CL_WETH_USD).latestRoundData();
            exchangeRate = (uint256(btcPrice) * 1e18) / uint256(ethPrice); // Convert BTC price to ETH price
        } else { 
            // Assumes other assets are stablecoins at 1:1 with ETH
            (, int256 price,,,) = IChainLink(CL_WETH_USD).latestRoundData();
            exchangeRate = 1e26 / uint256(price); // ChainLink returns 8 decimals, normalize to 1e18
        }

        // @todo need to consider stable with 6 decimals

        // Get GEAR price in the asset from Curve pool
        uint256 gearInAssetPrice = ICurvePool(GEAR_ETH_CURVE_POOL).price_oracle() * exchangeRate / 1e18;

        // Get farm information from staking contract
        (uint40 farmFinishTime, uint32 farmDuration, uint184 farmReward,) = staking.farmInfo();

        if (farmFinishTime <= block.timestamp) {
            // Farm is finished, no reward yield
            return 0;
        }
        if (farmDuration == 0) {
            // Farm duration is zero, no reward yield
            return 0;
        }

        // Calculate total supply including the delta converted to shares
        uint256 supply;
        if (_delta < 0) {
            supply = staking.totalSupply() - vault.convertToShares(uint256(-_delta));
        } else {
            supply = staking.totalSupply() + vault.convertToShares(uint256(_delta));
        }
        
        // Calculate reward in asset price
        uint256 rewardInAssetPrice = uint256(farmReward) * gearInAssetPrice / 1e18;

        // Calculate duration ratio
        uint256 durationRatio = (SECONDS_PER_YEAR * 1e18) / uint256(farmDuration);

        // Calculate reward yield
        uint256 rewardYield = ((rewardInAssetPrice * 1e18) / vault.convertToAssets(supply)) * durationRatio / 1e18;

        // Return total APR (native yield + reward yield)
        return nativeYield + rewardYield;
    }
}