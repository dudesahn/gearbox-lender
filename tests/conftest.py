import pytest
from ape import Contract, project


############ CONFIG FIXTURES ############

# Adjust the string based on the `asset` your strategy will use
# You may need to add the token address to `tokens` fixture.
@pytest.fixture(scope="session")
def asset(tokens):
    yield Contract(tokens["usdc"])


# Adjust the amount that should be used for testing based on `asset`.
@pytest.fixture(scope="session")
def amount(asset, user, whale):
    amount = 100 * 10 ** asset.decimals()

    asset.transfer(user, amount, sender=whale)
    yield amount


# whether or not we allow one wei losses at times for conversion slippage
@pytest.fixture(scope="session")
def allow_lossy():
    yield True


############ STANDARD FIXTURES ############


@pytest.fixture(scope="session")
def daddy(accounts):
    yield accounts["0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52"]


@pytest.fixture(scope="session")
def user(accounts):
    yield accounts[0]


@pytest.fixture(scope="session")
def rewards(accounts):
    yield accounts[1]


@pytest.fixture(scope="session")
def management(accounts):
    yield accounts[2]


@pytest.fixture(scope="session")
def keeper(accounts):
    yield accounts[3]


@pytest.fixture(scope="session")
def tokens():
    tokens = {
        "weth": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "usdc": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "wbtc": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        "gho": "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
        "dai": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    }
    yield tokens


@pytest.fixture(scope="session")
def d_tokens():
    d_tokens = {
        "weth": "0xda0002859B2d05F66a753d8241fCDE8623f26F4f",
        "usdc": "0xda00000035fef4082F78dEF6A8903bee419FbF8E",
        "wbtc": "0xda00010eDA646913F273E10E7A5d1F659242757d",
        "gho": "0x4d56c9cBa373AD39dF69Eb18F076b7348000AE09",
        "dai": "0xe7146F53dBcae9D6Fa3555FE502648deb0B2F823",
    }
    yield d_tokens


@pytest.fixture(scope="session")
def staking_pools():
    staking_pools = {
        "weth": "0x0418fEB7d0B25C411EB77cD654305d29FcbFf685",
        "usdc": "0x9ef444a6d7F4A5adcd68FD5329aA5240C90E14d2",
        "wbtc": "0xA8cE662E45E825DAF178DA2c8d5Fae97696A788A",
        "gho": "0xE2037090f896A858E3168B978668F22026AC52e7",
        "dai": "0xC853E4DA38d9Bd1d01675355b8c8f3BBC1451973",
    }
    yield staking_pools


@pytest.fixture(scope="session")
def whale(accounts):
    # In order to get some funds for the token you are about to use,
    # The Balancer vault stays steady ballin on almost all tokens
    # NOTE: If `asset` is a balancer pool this may cause issues on amount checks.
    yield accounts["0xBA12222222228d8Ba445958a75a0704d566BF2C8"]


@pytest.fixture(scope="session")
def gear():
    yield Contract("0xBa3335588D9403515223F109EdC4eB7269a9Ab5D")


@pytest.fixture(scope="session")
def trade_factory():
    yield Contract("0xb634316E06cC0B358437CbadD4dC94F1D3a92B3b")


@pytest.fixture(scope="session")
def weth(tokens):
    yield Contract(tokens["weth"])


@pytest.fixture(scope="session")
def weth_amount(user, weth):
    weth_amount = 10 ** weth.decimals()
    user.transfer(weth, weth_amount)
    yield weth_amount


@pytest.fixture(scope="session")
def factory(strategy):
    yield Contract(strategy.FACTORY())


@pytest.fixture(scope="session")
def set_protocol_fee(factory):
    def set_protocol_fee(protocol_fee=0):
        owner = factory.governance()
        factory.set_protocol_fee_recipient(owner, sender=owner)
        factory.set_protocol_fee_bps(protocol_fee, sender=owner)

    yield set_protocol_fee


@pytest.fixture(scope="session")
def create_strategy(management, keeper, rewards, d_tokens, staking_pools):
    def create_strategy(asset, performanceFee=1_000):
        strategy = management.deploy(
            project.StrategyGearboxLender,
            asset,
            "StrategyGearboxLenderUSDC",
            d_tokens["usdc"],
            staking_pools["usdc"],
        )
        strategy = project.IStrategyInterface.at(strategy.address)

        strategy.setKeeper(keeper, sender=management)
        strategy.setPerformanceFeeRecipient(rewards, sender=management)
        strategy.setPerformanceFee(performanceFee, sender=management)

        return strategy

    yield create_strategy


@pytest.fixture(scope="session")
def create_oracle(management):
    def create_oracle(_management=management):
        oracle = _management.deploy(project.StrategyAprOracle)

        return oracle

    yield create_oracle


@pytest.fixture(scope="session")
def strategy(asset, create_strategy):
    strategy = create_strategy(asset)

    yield strategy


@pytest.fixture(scope="session")
def oracle(create_oracle):
    oracle = create_oracle()

    yield oracle


############ HELPER FUNCTIONS ############


@pytest.fixture(scope="session")
def deposit(strategy, asset, user, amount):
    def deposit(_strategy=strategy, _asset=asset, assets=amount, account=user):
        _asset.approve(_strategy, assets, sender=account)
        _strategy.deposit(assets, account, sender=account)

    yield deposit


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    yield 1e-5
