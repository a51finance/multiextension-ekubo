use ekubo_multiextension::mock::mock_extension::IMockExtensionDispatcherTrait;
use ekubo_multiextension::multiextension::IMultiextensionDispatcherTrait;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use ekubo::interfaces::core::{ICoreDispatcher, ICoreDispatcherTrait};
use ekubo::interfaces::positions::{IPositionsDispatcher, IPositionsDispatcherTrait};
use ekubo::interfaces::router::{IRouterDispatcher, IRouterDispatcherTrait, RouteNode, TokenAmount};
use ekubo::interfaces::mathlib::{IMathLibDispatcherTrait, dispatcher as mathlib};
use ekubo::types::call_points::CallPoints;
use ekubo::types::keys::PoolKey;
use ekubo::types::i129::i129;
use ekubo::types::bounds::Bounds;

use ekubo_multiextension::types::init_params::MultiextensionInitParams;
use ekubo_multiextension::multiextension::IMultiextensionDispatcher;
use ekubo_multiextension::mock::token::{IERC20Dispatcher, IERC20DispatcherTrait};
use ekubo_multiextension::mock::mock_extension::IMockExtensionDispatcher;
use ekubo_multiextension::components::activate_extension::{ExtStruct, generate_extension_data};

use crate::activated_extensions_test::{deploy_mock_extension, create_extension_struct};


fn ekubo_core() -> ICoreDispatcher {
    ICoreDispatcher {
        contract_address: contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b,
        >(),
    }
}

fn positions() -> IPositionsDispatcher {
    IPositionsDispatcher {
        contract_address: contract_address_const::<
            0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067,
        >(),
    }
}

fn router() -> IRouterDispatcher {
    IRouterDispatcher {
        contract_address: contract_address_const::<
            0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e,
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

fn initialize_multiextension(
    multiextension: IMultiextensionDispatcher,
) -> (ContractAddress, ContractAddress) {
    let mock_extensions = (deploy_mock_extension(1), deploy_mock_extension(2));
    let (extension_one, extension_two) = mock_extensions;
    let input_extensions: Array<ExtStruct> = array![
        create_extension_struct(extension_one, 0), create_extension_struct(extension_two, 1),
    ];
    let (activated_extensions, extensions) = generate_extension_data(input_extensions.span());
    multiextension.init_extensions(extensions.span(), activated_extensions);
    mock_extensions
}

fn setup() -> (IMultiextensionDispatcher, PoolKey, (ContractAddress, ContractAddress)) {
    let init_params = MultiextensionInitParams {
        core: ekubo_core(), init_timeout: 100, owner: get_contract_address(),
    };

    let multiextension = deploy_multiextension(init_params);
    let mock_extensions = initialize_multiextension(multiextension);
    let pool_key = get_ekubo_pool_key(multiextension.contract_address);

    (multiextension, pool_key, mock_extensions)
}

#[test]
#[fork("mainnet")]
fn test_call_points() {
    let (_, pool_key, _) = setup();
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
fn test_pool_init() {
    let (_, pool_key, mock_extensions) = setup();
    ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });

    let (extension_one, extension_two) = mock_extensions;
    let mock_one = IMockExtensionDispatcher { contract_address: extension_one };
    let mock_two = IMockExtensionDispatcher { contract_address: extension_two };

    assert_eq!(mock_one.get_before_execute(), 1);
    assert_eq!(mock_one.get_after_execute(), 1);

    assert_eq!(mock_two.get_before_execute(), 2);
    assert_eq!(mock_two.get_after_execute(), 2);
}

#[test]
#[fork("mainnet")]
fn test_position_update() {
    let (_, pool_key, mock_extensions) = setup();
    ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });

    let (extension_one, extension_two) = mock_extensions;
    let mock_one = IMockExtensionDispatcher { contract_address: extension_one };
    let mock_two = IMockExtensionDispatcher { contract_address: extension_two };

    IERC20Dispatcher { contract_address: pool_key.token0 }
        .transfer(positions().contract_address, 1_000_000);
    IERC20Dispatcher { contract_address: pool_key.token1 }
        .transfer(positions().contract_address, 1_000_000);
    positions()
        .mint_and_deposit(
            pool_key,
            // full range bounds
            Bounds {
                lower: i129 { mag: 88368108, sign: true },
                upper: i129 { mag: 88368108, sign: false },
            },
            0,
        );

    assert_eq!(mock_one.get_before_execute(), 11);
    assert_eq!(mock_one.get_after_execute(), 11);

    assert_eq!(mock_two.get_before_execute(), 12);
    assert_eq!(mock_two.get_after_execute(), 12);
}

#[test]
#[fork("mainnet")]
fn test_swap() {
    let (_, pool_key, mock_extensions) = setup();
    ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });

    let (extension_one, extension_two) = mock_extensions;
    let mock_one = IMockExtensionDispatcher { contract_address: extension_one };
    let mock_two = IMockExtensionDispatcher { contract_address: extension_two };

    let tick = i129 { mag: 200, sign: false };

    router()
        .swap(
            RouteNode {
                pool_key, sqrt_ratio_limit: mathlib().tick_to_sqrt_ratio(tick), skip_ahead: 0,
            },
            TokenAmount { token: pool_key.token1, amount: i129 { mag: 1, sign: false } },
        );

    assert_eq!(mock_one.get_before_execute(), 11);
    assert_eq!(mock_one.get_after_execute(), 11);

    assert_eq!(mock_two.get_before_execute(), 12);
    assert_eq!(mock_two.get_after_execute(), 12);
}