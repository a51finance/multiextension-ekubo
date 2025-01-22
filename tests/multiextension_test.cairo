use ekubo::interfaces::core::ICoreDispatcherTrait;
use starknet::{contract_address_const, ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

// use ekubo_multiextension::multiextension::IMultiextensionSafeDispatcher;
// use ekubo_multiextension::multiextension::IMultiextensionSafeDispatcherTrait;
// use ekubo_multiextension::multiextension::IMultiextensionDispatcher;
// use ekubo_multiextension::multiextension::IMultiextensionDispatcherTrait;

use ekubo::interfaces::core::{ICoreDispatcher};
use ekubo::types::call_points::{CallPoints};

fn ekubo_core() -> ICoreDispatcher {
    ICoreDispatcher {
        contract_address: contract_address_const::<
            0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b,
        >(),
    }
}

fn deploy_multiextension(core: ICoreDispatcher) -> ContractAddress {
    let contract = declare("Multiextension").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![core.contract_address.into()]).unwrap();
    contract_address
}

fn setup() -> ContractAddress {
    let contract_address = deploy_multiextension(ekubo_core());
    contract_address
}

#[test]
#[fork("mainnet")]
fn test_increase_balance() {
    let multiextension_address = setup();
    assert_eq!(
        ekubo_core().get_call_points(multiextension_address),
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
    )
}

