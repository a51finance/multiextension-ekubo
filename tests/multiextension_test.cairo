use ekubo_multiextension::multiextension::IMultiextensionDispatcherTrait;
use starknet::{contract_address_const, get_contract_address, ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use ekubo::interfaces::core::{ICoreDispatcherTrait, ICoreDispatcher};
use ekubo::types::call_points::{CallPoints};
use ekubo::types::keys::{PoolKey};
use ekubo::types::i129::{i129};
use ekubo_multiextension::types::init_params::MultiextensionInitParams;
use ekubo_multiextension::types::packet_extension::PacketExtension;
// use ekubo_multiextension::multiextension::IMultiextensionSafeDispatcher;
// use ekubo_multiextension::multiextension::IMultiextensionSafeDispatcherTrait;
use ekubo_multiextension::multiextension::IMultiextensionDispatcher;
// use ekubo_multiextension::multiextension::IMultiextensionDispatcherTrait;
use ekubo_multiextension::mock::token::{IERC20Dispatcher};


fn ekubo_core() -> ICoreDispatcher {
    ICoreDispatcher {
        contract_address: contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b,
        >(),
    }
}

fn default_owner() -> ContractAddress {
    contract_address_const::<0xdeadbeefdeadbeef>()
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

fn deploy_mockextension(name: ByteArray) -> ContractAddress {
    let contract_class = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![])
        .expect('Deploy mockextension failed');
    contract_address
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
        core: ekubo_core(), init_timeout: 100, owner: default_owner(),
    };

    let multiextension = deploy_multiextension(init_params);
    let pool_key = get_ekubo_pool_key(multiextension.contract_address);

    (multiextension, pool_key)
}

// #[test]
// fn temp () {
//     let active: u256 = 389180780512873979206060336218813876722004499628491695972352;
//     let extension = active / 0x100000000000000000000000000000000000;
//     print!("extension = {} ",extension);
// }

#[test]
#[fork("mainnet")]
fn test_init() {
    let (multiextension, pool_key) = setup();
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

    let (mockExtensionOne, mockExtensionTwo) = (
        deploy_mockextension("MockextensionOne"), deploy_mockextension("MockextensionTwo"),
    );

    // let mcFelt:felt252 = mockExtensionOne.into();
    // print!("address = {} ",mcFelt);

    let extensions = array![
        PacketExtension {
            extension: mockExtensionTwo, extensionQueue: 200, extensionDataDist: 100,
        },
        PacketExtension {
            extension: mockExtensionTwo, extensionQueue: 200, extensionDataDist: 100,
        },
        PacketExtension {
            extension: mockExtensionTwo, extensionQueue: 286331153, extensionDataDist: 100,
        },
        PacketExtension {
            extension: mockExtensionTwo, extensionQueue: 200, extensionDataDist: 100,
        },
        PacketExtension {
            extension: mockExtensionOne, extensionQueue: 1118481, extensionDataDist: 100,
        },
    ];

    // 389180678745591968580628335859831605021785274946596863467520

    multiextension.init_extensions(extensions, 196960369429610926656313877409557991465454657536);

    // let ab = multiextension.run_mock();
    // let cd:felt252 = mockExtensionOne.into();

    // let count = multiextension.mock_function();
    // print!("count = {} and {}", count.at(0).unwrap(), count.at(1).unwrap());

    ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });
    // print!("ab = {}", ab);
// print!("cd = {}", cd);
}
