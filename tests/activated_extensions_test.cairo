use core::dict::Felt252Dict;
use starknet::ContractAddress;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

use ekubo_multiextension::components::activate_extension::{
    ExtMethodStruct, ExtStruct, generate_extension_data,
};
use ekubo_multiextension::components::bit_math::ExtensionMethod;
use ekubo_multiextension::constants::{
    BEFORE_INIT_POOL_BIT_SHIFT, AFTER_INIT_POOL_BIT_SHIFT, BEFORE_SWAP_BIT_SHIFT,
    AFTER_SWAP_BIT_SHIFT, BEFORE_UPDATE_POSITION_BIT_SHIFT, AFTER_UPDATE_POSITION_BIT_SHIFT,
    BEFORE_COLLECT_FEES_BIT_SHIFT, AFTER_COLLECT_FEES_BIT_SHIFT, BEFORE_INIT_POOL_QUEUE_BIT_SHIFT,
    AFTER_INIT_POOL_QUEUE_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT, AFTER_SWAP_QUEUE_BIT_SHIFT,
    BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT, AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT,
    BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT, AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
};
use ekubo_multiextension::multiextension::Multiextension::InternalTrait;
use ekubo_multiextension::multiextension::{Multiextension, IMultiextension};

fn deploy_mock_extension() -> ContractAddress {
    let contract_class = declare("Mockextension").unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![])
        .expect('Deploy mockextension failed');
    contract_address
}

fn assert_extension_order(
    bit_shift: u256,
    queue_bit_shift: u32,
    input_extensions: Span<ExtStruct>,
    mock_extensions: (ContractAddress, ContractAddress),
    ref state: Multiextension::ContractState,
) {
    let (extension_one, extension_two) = mock_extensions;
    let mut active_extensions: Felt252Dict<felt252> = Default::default();
    let extensions_count = state
        ._get_activated_extensions(ref active_extensions, bit_shift, queue_bit_shift);
    assert_eq!(extensions_count.into(), input_extensions.len());
    assert_eq!(active_extensions.get(1), extension_one.into());
    assert_eq!(active_extensions.get(0), extension_two.into());
}

fn create_extension_struct(extension: ContractAddress, position: u8) -> ExtStruct {
    ExtStruct {
        extension,
        methods: array![
            ExtMethodStruct { method: ExtensionMethod::BeforeInitPool, position, activate: true },
            ExtMethodStruct { method: ExtensionMethod::AfterInitPool, position, activate: true },
            ExtMethodStruct { method: ExtensionMethod::BeforeSwap, position, activate: true },
            ExtMethodStruct { method: ExtensionMethod::AfterSwap, position, activate: true },
            ExtMethodStruct {
                method: ExtensionMethod::BeforeUpdatePosition, position, activate: true,
            },
            ExtMethodStruct {
                method: ExtensionMethod::AfterUpdatePosition, position, activate: true,
            },
            ExtMethodStruct {
                method: ExtensionMethod::BeforeCollectFees, position, activate: true,
            },
            ExtMethodStruct { method: ExtensionMethod::AfterCollectFees, position, activate: true },
        ]
            .span(),
    }
}

#[test]
fn test_activated_extensions() {
    let mock_extensions = (deploy_mock_extension(), deploy_mock_extension());
    let (extension_one, extension_two) = mock_extensions;
    let input_extensions: Array<ExtStruct> = array![
        create_extension_struct(extension_one, 1), create_extension_struct(extension_two, 0),
    ];

    let (activated_extensions, extensions) = generate_extension_data(input_extensions.span());
    let mut state = Multiextension::contract_state_for_testing();
    state.init_extensions(extensions.span(), activated_extensions);

    assert_extension_order(
        BEFORE_INIT_POOL_BIT_SHIFT,
        BEFORE_INIT_POOL_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        AFTER_INIT_POOL_BIT_SHIFT,
        AFTER_INIT_POOL_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        BEFORE_SWAP_BIT_SHIFT,
        BEFORE_SWAP_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        AFTER_SWAP_BIT_SHIFT,
        AFTER_SWAP_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        BEFORE_UPDATE_POSITION_BIT_SHIFT,
        BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        AFTER_UPDATE_POSITION_BIT_SHIFT,
        AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        BEFORE_COLLECT_FEES_BIT_SHIFT,
        BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
    assert_extension_order(
        AFTER_COLLECT_FEES_BIT_SHIFT,
        AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
        input_extensions.span(),
        mock_extensions,
        ref state,
    );
}
