use snforge_std::{
    ContractClassTrait, DeclareResultTrait, CheatSpan, declare, cheat_block_timestamp,
};
use starknet::{contract_address_const, get_contract_address, get_block_timestamp};
use starknet::storage::{
    StorageBase, StoragePointerWriteAccess, StoragePointerReadAccess, StoragePathEntry, Mutable,
    Map,
};
use ekubo::interfaces::core::ICoreDispatcher;

use ekubo_multiextension::types::init_params::MultiextensionInitParams;
use ekubo_multiextension::types::packet_extension::PacketExtension;
use ekubo_multiextension::multiextension::{
    Multiextension, IMultiextension, IMultiextensionDispatcher, IMultiextensionDispatcherTrait,
};

fn ekubo_core() -> ICoreDispatcher {
    ICoreDispatcher {
        contract_address: contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b,
        >(),
    }
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

fn deploy_mock_extensions(count: u8) -> Array<PacketExtension> {
    let mut mock_extensions: Array<PacketExtension> = array![];
    for _ in 0..count {
        let contract_class = declare("Mockextension").unwrap().contract_class();
        let (contract_address, _) = contract_class
        .deploy(@array![])
        .expect('Deploy mockextension failed');
        mock_extensions.append(PacketExtension { extension: contract_address, extension_queue: 0 })
    };
    mock_extensions
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

#[test]
fn test_init_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    assert_eq!(state.extension_count.read(), mock_extensions.len());
    check_stored_extension(state.extensions, mock_extensions.span());
}

#[test]
#[should_panic(expected: ('MAX_EXTENSIONS_COUNT_EXCEEDED',))]
fn test_init_extensions_more_than_limit() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(17);
    state.init_extensions(mock_extensions.span(), 0);
}

#[test]
#[should_panic(expected: ('ALREADY_INITIALIZED',))]
fn test_re_init_extensions() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    state.init_extensions(mock_extensions.span(), 0);
}

#[test]
#[fork("mainnet")]
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

#[test]
#[should_panic(expected: ('CHANGE_PENDING',))]
fn test_change_extensions_with_pending() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.init_extensions(mock_extensions.span(), 0);
    state.change_extensions(mock_extensions.span(), 0);
    state.change_extensions(mock_extensions.span(), 0);
}

#[test]
#[should_panic(expected: ('NOT_INITIALIZED',))]
fn test_change_extensions_with_not_init() {
    let mut state = Multiextension::contract_state_for_testing();
    let mock_extensions = deploy_mock_extensions(2);
    state.change_extensions(mock_extensions.span(), 0);
}

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

#[test]
#[fork("mainnet")]
fn test_accept_new_extensions() {
    //here timeout = 0
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    let new_extensions = deploy_mock_extensions(3);
    let new_activated_extension = 1;
    state.change_extensions(new_extensions.span(), new_activated_extension);

    //to pass the timelock check
    state.change_extensions_timer.write(get_block_timestamp() - 1);
    state.accept_new_extensions();
    assert_eq!(state.extension_count.read(), new_extensions.len());
    assert_eq!(state.activated_extensions.read(), new_activated_extension);
    assert_eq!(state.change_extensions_timer.read(), 0);
    assert_eq!(state.pending_activated_extensions.read(), 0);
    assert_eq!(state.pending_extensions_count.read(), 0);
    check_stored_extension(state.extensions, new_extensions.span());
}

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

#[test]
#[fork("mainnet")]
#[should_panic(expected: ('NO_EXTENSIONS_PENDING_APPROVAL',))]
fn test_reject_new_extensions_without_change() {
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(deploy_mock_extensions(2).span(), 0);
    state.reject_new_extensions();
}

