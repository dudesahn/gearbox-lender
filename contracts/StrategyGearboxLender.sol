// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Base4626Compounder, ERC20, SafeERC20, Math} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";
import {IStaking} from "./interfaces/GearboxInterfaces.sol";

contract StrategyGearboxLender is Base4626Compounder, TradeFactorySwapper {
    using SafeERC20 for ERC20;

    /**
     * @notice Address of the Gearbox staked dToken (sdToken) contract.
     * @dev This is a staking contract based on 1inch staking that accepts deposits of the dToken (our vault state var).
     */
    IStaking public immutable staking;

    /**
     * @dev Vault must match stakingToken for the staking pool.
     * @param _asset Underlying asset to use for this strategy.
     * @param _name Name to use for this strategy. Ideally "StrategyGearboxLenderASSET", ie StrategyGearboxLenderUSDC.
     * @param _vault ERC4626 vault token to use. In Gearbox V3, these are the dTokens.
     * @param _staking Staking pool to use. In Gearbox V3, these are the sdTokens.
     */
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _staking
    ) Base4626Compounder(_asset, _name, _vault) {
        staking = IStaking(_staking);
        require(_vault == staking.stakingToken(), "token mismatch");

        ERC20(_vault).safeApprove(_staking, type(uint256).max);
    }

    /* ========== BASE4626 FUNCTIONS ========== */

    /**
     * @notice Balance of vault tokens staked in the staking contract
     */
    function balanceOfStake() public view virtual override returns (uint256) {
        return staking.balanceOf(address(this));
    }

    function _stake() internal override {
        staking.deposit(balanceOfVault());
    }

    function _unStake(uint256 _amount) internal virtual override {
        staking.withdraw(_amount);
    }

    function vaultsMaxWithdraw()
        public
        view
        virtual
        override
        returns (uint256)
    {
        // We need to use the staking contract address for maxRedeem
        // Convert the vault shares to `asset`.
        return vault.convertToAssets(vault.maxRedeem(address(staking)));
    }

    /* ========== TRADE FACTORY FUNCTIONS ========== */

    /**
     * @notice Use to manually claim rewards from our staking contract.
     * @dev Can only be called by management. Mostly helpful to make life easier for trade factory.
     */
    function manualRewardsClaim() external onlyManagement {
        _claimRewards();
    }

    function _claimRewards() internal override {
        staking.claim();
    }

    /**
     * @notice Use to update our trade factory.
     * @dev Can only be called by management.
     * @param _tradeFactory Address of new trade factory.
     */
    function setTradeFactory(address _tradeFactory) external onlyManagement {
        _setTradeFactory(_tradeFactory, address(asset));
    }

    /**
     * @notice Use to add tokens to our rewardTokens array. Also enables token on trade factory if one is set.
     * @dev Can only be called by management.
     * @param _token Address of token to add.
     */
    function addToken(address _token) external onlyManagement {
        _addToken(_token, address(asset));
    }

    /**
     * @notice Use to remove tokens from our rewardTokens array. Also disables token on trade factory.
     * @dev Can only be called by management.
     * @param _token Address of token to remove.
     */
    function removeToken(address _token) external onlyManagement {
        _removeToken(_token, address(asset));
    }
}
