import ape
from ape import Contract
from utils.constants import MAX_BPS, ZERO_ADDRESS
from utils.helpers import (
    days_to_secs,
    increase_time,
    withdraw_and_check,
    withdraw_and_check_lossy,
)
import pytest


def test_trade_handler(
    chain,
    asset,
    strategy,
    user,
    deposit,
    amount,
    RELATIVE_APPROX,
    allow_lossy,
    gear,
    trade_factory,
    management,
):
    user_balance_before = asset.balanceOf(user)

    # Deposit to the strategy
    deposit()

    assert strategy.totalAssets() == amount
    increase_time(chain, 100)

    # setup our tokens to dump
    assert strategy.tradeFactory() == ZERO_ADDRESS
    strategy.setTradeFactory(trade_factory, sender=management)
    assert strategy.tradeFactory() == trade_factory.address
    strategy.addToken(gear.address, sender=management)
    assert gear.balanceOf(strategy) == 0
    strategy.manualRewardsClaim(sender=management)
    real_profit = gear.balanceOf(strategy)
    assert real_profit > 0
    print("⚙️ GEAR Profit:", real_profit / 1e18)

    # check that TF can yoink GEAR
    assert gear.allowance(strategy, trade_factory) > 0
