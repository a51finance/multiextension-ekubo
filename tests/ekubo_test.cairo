use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare
};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
use ekubo::types::call_points::CallPoints;
use ekubo::types::keys::PoolKey;
use ekubo::types::i129::i129;

use ekubo_multiextension::types::init_params::MultiextensionInitParams;
use ekubo_multiextension::multiextension::IMultiextensionDispatcher;
use ekubo_multiextension::mock::token::IERC20Dispatcher;

fn ekubo_core() -> ICoreDispatcher {
    ICoreDispatcher {
        contract_address: contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b,
        >(),
    }
}

fn deploy_token() -> IERC20Dispatcher {
    let contract_class = declare("Token").unwrap().contract_class();
    let recipient = get_contract_address();
    let amount: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    let (contract_address, _) = contract_class
        .deploy(@array![recipient.into(), amount.low.into(), amount.high.into()])
        .expect('Deploy token failed');

    IERC20Dispatcher { contract_address }
}

fn deploy_multiextension(params: MultiextensionInitParams) -> IMultiextensionDispatcher {
    let contract_class = declare("Multiextension").unwrap().contract_class();
    let init_params = array![
        params.core.contract_address.into(), params.init_timeout.into(), params.owner.into(),
    ];
    let (contract_address, _) = contract_class
        .deploy(@init_params)
        .expect('Deploy multiextension failed');
    IMultiextensionDispatcher { contract_address }
}

fn get_ekubo_pool_key(extension: ContractAddress) -> PoolKey {
    let (tokenA, tokenB) = (deploy_token(), deploy_token());
    let (token0, token1) = if tokenA.contract_address < tokenB.contract_address {
        (tokenA, tokenB)
    } else {
        (tokenB, tokenA)
    };

    let pool_key = PoolKey {
        token0: token0.contract_address,
        token1: token1.contract_address,
        fee: 0,
        tick_spacing: 354892,
        extension,
    };

    pool_key
}

fn setup() -> (IMultiextensionDispatcher, PoolKey) {
    let init_params = MultiextensionInitParams {
        core: ekubo_core(), init_timeout: 100, owner: get_contract_address(),
    };

    let multiextension = deploy_multiextension(init_params);
    let pool_key = get_ekubo_pool_key(multiextension.contract_address);

    (multiextension, pool_key)
}

#[test]
#[fork("mainnet")]
fn test_call_points() {
    let (_, pool_key) = setup();
    assert_eq!(
        ekubo_core().get_call_points(pool_key.extension),
        CallPoints {
            before_initialize_pool: true,
            after_initialize_pool: true,
            before_swap: true,
            after_swap: true,
            before_update_position: true,
            after_update_position: true,
            before_collect_fees: true,
            after_collect_fees: true,
        },
    );
}

#[test]
#[fork("mainnet")]
fn test_pool_init_order() {
    let (_, pool_key) = setup();
    ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });
}