// use Multiextension::InternalTrait;

use core::dict::{Felt252Dict};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, CheatSpan, declare, cheat_block_timestamp,
};
use starknet::{ContractAddress, contract_address_const, get_contract_address, get_block_timestamp};
use starknet::storage::{
    StorageBase, StoragePointerWriteAccess, StoragePointerReadAccess, StoragePathEntry, Mutable,
    Map,
};

use ekubo::interfaces::core::{ICoreDispatcher};
// use ekubo::types::call_points::{CallPoints};
use ekubo::types::keys::{PoolKey};
// use ekubo::types::i129::{i129};

use ekubo_multiextension::types::init_params::MultiextensionInitParams;
use ekubo_multiextension::types::packet_extension::PacketExtension;
use ekubo_multiextension::multiextension::{
    Multiextension, IMultiextension, IMultiextensionDispatcher, IMultiextensionDispatcherTrait,
};
use ekubo_multiextension::multiextension::Multiextension::InternalTrait;

use ekubo_multiextension::mock::token::{IERC20Dispatcher};
// use ekubo_multiextension::multiextension::Multiextension::{InternalTrait};
use ekubo_multiextension::constants::{BEFORE_SWAP_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT};


use ekubo_multiextension::components::bit_math::{
    ExtensionMethod, activate_extension, set_queue_position,
};

use ekubo_multiextension::components::activate_extension::{ExtMethodStruct, ExtStruct, generate_extension_data};


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

fn deploy_mockLockExtension(
    core: ICoreDispatcher, multiextension: ContractAddress,
) -> ContractAddress {
    let contract_class = declare("MockextensionOne").unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![core.contract_address.into(), multiextension.into()])
        .expect('Deploy mockextension failed');
    contract_address
}

fn deploy_mock_extension () -> ContractAddress {
    let contract_class = declare("Mockextension").unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![])
        .expect('Deploy mockextension failed');
    contract_address
}

fn deploy_mock_extensions(count: u8) -> Array<PacketExtension> {
    let mut mock_extensions: Array<PacketExtension> = array![];
    for _ in 0..count {
        let contract_address = deploy_mock_extension();
        mock_extensions.append(PacketExtension { extension: contract_address, extension_queue: 0 })
    };
    mock_extensions
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

fn check_stored_extension(
    state_extensions: StorageBase<Mutable<Map<u32, PacketExtension>>>,
    check_extensions: Span<PacketExtension>,
) {
    for index in 0..check_extensions.len() {
        let check_extension = *(check_extensions.get(index).unwrap().unbox());
        let state_extensions = state_extensions.entry(index).read();
        assert_eq!(check_extension.extension, state_extensions.extension);
    };
}

#[ignore]
#[test]
fn test_init_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    assert_eq!(state.extension_count.read(), mock_extensions.len());
    check_stored_extension(state.extensions, mock_extensions.span());
}

#[ignore]
#[test]
#[should_panic(expected: ('MAX_EXTENSIONS_COUNT_EXCEEDED',))]
fn test_init_extensions_more_than_limit() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(17);
    state.init_extensions(mock_extensions.span(), 0);
}

#[ignore]
#[test]
#[should_panic(expected: ('ALREADY_INITIALIZED',))]
fn test_re_init_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    state.init_extensions(mock_extensions.span(), 0);
}

#[ignore]
#[test]
#[fork("mainnet",)] 
//this make sure the contract read get block timestamp for change_extensions_timer
fn test_change_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    state.change_extensions(mock_extensions.span(), 0);
    assert_eq!(state.pending_extensions_count.read(), mock_extensions.len());
    check_stored_extension(state.pending_extensions, mock_extensions.span());
    assert_eq!(state.change_extensions_timer.read(), get_block_timestamp());
}

#[ignore]
#[test]
#[should_panic(expected: ('CHANGE_PENDING',))]
fn test_change_extensions_with_pending() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    state.change_extensions(mock_extensions.span(), 0);
    state.change_extensions(mock_extensions.span(), 0);
}

#[ignore]
#[test]
#[should_panic(expected: ('NOT_INITIALIZED',))]
fn test_change_extensions_with_not_init() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.change_extensions(mock_extensions.span(), 0);
}

#[ignore]
#[test]
#[fork("mainnet")]
fn test_accept_new_extensions_with_timelock() {
    let timeout = 100; //100s;
    let multiextension = deploy_multiextension(
        MultiextensionInitParams {
            core: ekubo_core(), init_timeout: timeout, owner: get_contract_address(),
        },
    );
    multiextension.init_extensions(deploy_mock_extensions(2).span(), 0);
    let new_extensions = deploy_mock_extensions(3);
    multiextension.change_extensions(new_extensions.span(), 1);
    cheat_block_timestamp(
        multiextension.contract_address, get_block_timestamp() + timeout + 1, CheatSpan::Indefinite,
    );
    multiextension.accept_new_extensions();
}

#[ignore]
#[test]
#[fork("mainnet")]
fn test_accept_new_extensions() {
    //here timeout = 0
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    let new_extensions = deploy_mock_extensions(3);
    let new_activeted_extension = 1;
    state.change_extensions(new_extensions.span(), new_activeted_extension);

    //to pass the timelock check
    state.change_extensions_timer.write(get_block_timestamp() - 1);
    state.accept_new_extensions();
    assert_eq!(state.extension_count.read(), new_extensions.len());
    assert_eq!(state.activated_extensions.read(), new_activeted_extension);
    assert_eq!(state.change_extensions_timer.read(), 0);
    assert_eq!(state.pending_activated_extensions.read(), 0);
    assert_eq!(state.pending_extensions_count.read(), 0);
    check_stored_extension(state.extensions, new_extensions.span());
}

#[ignore]
#[test]
#[fork("mainnet")]
#[should_panic(expected: ('EXTENSIONS_APPROVAL_TIMEOUT',))]
fn test_accept_new_extensions_with_fail_timelock() {
    //here timeout = 0
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    state.change_extensions(deploy_mock_extensions(3).span(), 1);
    state.accept_new_extensions();
}

#[ignore]
#[test]
#[fork("mainnet")]
fn test_reject_new_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    state.change_extensions(deploy_mock_extensions(3).span(), 1);
    state.reject_new_extensions();
    assert_eq!(state.change_extensions_timer.read(), 0);
    assert_eq!(state.pending_activated_extensions.read(), 0);
    assert_eq!(state.pending_extensions_count.read(), 0);
}

#[ignore]
#[test]
#[fork("mainnet")]
#[should_panic(expected: ('NO_EXTENSIONS_PENDING_APPROVAL',))]
fn test_reject_new_extensions_without_change() {
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    state.reject_new_extensions();
}

#[test]
fn test_activated_extensions() {
    // let (extension_one, _) = (deploy_mock_extension(), deploy_mock_extension());

    let hello = ExtMethodStruct { method: ExtensionMethod::BeforeInitPool, position: 0, activate:true};
    
    // let input_extensions: Array<ExtStruct> = array![
    //     ExtStruct { extension: extension_one, methods: @array![ExtMethodStruct {method:ExtensionMethod::BeforeInitPool,position:0,activate:true}]}
    // ];

    // let a0ne = activate_extension(0, ExtensionMethod::BeforeInitPool ,15,true);
    // let aTwo:felt252 = activate_extension(196960369429610926656313877409557991465454657536,
    // ExtensionMethod::BeforeSwap ,1 ,false).try_into().unwrap();
    // let aTHree:felt252 = activate_extension(aTwo, ExtensionMethod::AfterInitPool ,1
    // ,true).try_into().unwrap();
    // print!("active = {} ",aTwo);

    // let ab = set_queue_position(286331153, ExtensionMethod::AfterInitPool, 2);
    // print!("active = {} ", ab);
    // let newA = activate_extension(
//     196960369429610926656313877409557991465454657536, ExtensionMethod::BeforeSwap, 3, true,
// );
// let mut active_extensions: Felt252Dict<felt252> = Default::default();
// let mut state = Multiextension::contract_state_for_testing();
// state.init_extensions(deploy_mock_extensions(5).span(), newA);
// let extensions_count = state
//     ._get_activated_extensions(
//         ref active_extensions, BEFORE_SWAP_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT,
//     );
// print!("extensions_count = {} ", extensions_count)
}
// #[test]
// #[fork("mainnet")]
// fn test_init() {
//     let (_, pool_key) = setup();
//     assert_eq!(
//         ekubo_core().get_call_points(pool_key.extension),
//         CallPoints {
//             before_initialize_pool: true,
//             after_initialize_pool: true,
//             before_swap: true,
//             after_swap: true,
//             before_update_position: true,
//             after_update_position: true,
//             before_collect_fees: true,
//             after_collect_fees: true,
//         },
//     );
// }

// ---------------------------------------------------------------------------------
// #[test]
// #[fork("mainnet")]
// fn test_lock() {
//     let lockExtension = deploy_mockLockExtension(ekubo_core());
//     let pool_key = get_ekubo_pool_key(lockExtension);

//     let locker: felt252 = lockExtension.into();
//     println!("lockExtension = {} ", locker);

//     let lockContract = IMockExtensionDispatcher { contract_address: lockExtension };

//     let locker: felt252 = lockContract.get_locker().into();
//     println!("before count = {} ", lockContract.get_count());
//     println!("before locker = {} ", locker);

//     ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });

//     let locker: felt252 = lockContract.get_locker().into();
//     println!("after count = {} ", lockContract.get_count());
//     println!("after locker = {} ", locker);
// }

// #[test]
// #[fork("mainnet")]
// fn test_init() {
//     let (multiextension, pool_key) = setup();
//     assert_eq!(
//         ekubo_core().get_call_points(pool_key.extension),
//         CallPoints {
//             before_initialize_pool: true,
//             after_initialize_pool: true,
//             before_swap: true,
//             after_swap: true,
//             before_update_position: true,
//             after_update_position: true,
//             before_collect_fees: true,
//             after_collect_fees: true,
//         },
//     );

//     let stored_caller: felt252 = multiextension.get_temp().into();
//     let caller: felt252 = get_contract_address().into();

//     print!("stored_caller = {}", stored_caller);
//     print!("caller = {}", caller);

//     // let (mockExtensionOne, mockExtensionTwo) = (
//     //     deploy_mockextension("MockextensionOne"), deploy_mockextension("MockextensionTwo"),
//     // );

//     // let mockExtensionTwo = deploy_mockextension("MockextensionTwo");

//     // let mone = deploy_mockLockExtension(ekubo_core(), multiextension.contract_address);

//     // let lockContract = IMockExtensionDispatcher { contract_address: mone };
//     // let core: felt252 = mone.into();

//     // print!("before lock = {}", lockContract.get_count());

//     // let extensions = array![
//     //     PacketExtension { extension: mockExtensionTwo, extension_queue: 200 },
//     //     PacketExtension { extension: mockExtensionTwo, extension_queue: 200 },
//     //     PacketExtension { extension: mockExtensionTwo, extension_queue: 286331153 },
//     //     PacketExtension { extension: mockExtensionTwo, extension_queue: 200 },
//     //     PacketExtension { extension: mone, extension_queue: 1118481 },
//     // ];

//     // multiextension.init_extensions(extensions,
//     196960369429610926656313877409557991465454657536);

//     // ekubo_core().initialize_pool(pool_key, i129 { mag: 100, sign: false });

//     // print!("after lock = {}", lockContract.get_count());

//     // let lock_core: felt252 = lockContract.get_locker().into();
//     // print!("actual mone = {}", core);
//     // print!("called mone = {}", lock_core);
//     // print!("ab = {}", ab);
// // print!("cd = {}", cd);
// }


