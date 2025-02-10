use core::num::traits::Pow;

use ekubo_multiextension::constants::{
    MAX_EXTENSIONS_COUNT, BEFORE_INIT_POOL_BIT_SHIFT, AFTER_INIT_POOL_BIT_SHIFT,
    BEFORE_SWAP_BIT_SHIFT, AFTER_SWAP_BIT_SHIFT, BEFORE_UPDATE_POSITION_BIT_SHIFT,
    AFTER_UPDATE_POSITION_BIT_SHIFT, BEFORE_COLLECT_FEES_BIT_SHIFT, AFTER_COLLECT_FEES_BIT_SHIFT,
    BEFORE_INIT_POOL_QUEUE_BIT_SHIFT, AFTER_INIT_POOL_QUEUE_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT,
    AFTER_SWAP_QUEUE_BIT_SHIFT, BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT,
    AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT, BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT,
    AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
};
use ekubo_multiextension::errors::Errors;

// Ekubo lifecycle methods
#[derive(Drop, Copy)]
pub enum ExtensionMethod {
    BeforeInitPool,
    AfterInitPool,
    BeforeSwap,
    AfterSwap,
    BeforeUpdatePosition,
    AfterUpdatePosition,
    BeforeCollectFees,
    AfterCollectFees,
}

//get the method data bit shifter for given method
fn get_method_bit_shift(method: ExtensionMethod) -> u256 {
    match method {
        ExtensionMethod::BeforeInitPool => BEFORE_INIT_POOL_BIT_SHIFT,
        ExtensionMethod::AfterInitPool => AFTER_INIT_POOL_BIT_SHIFT,
        ExtensionMethod::BeforeSwap => BEFORE_SWAP_BIT_SHIFT,
        ExtensionMethod::AfterSwap => AFTER_SWAP_BIT_SHIFT,
        ExtensionMethod::BeforeUpdatePosition => BEFORE_UPDATE_POSITION_BIT_SHIFT,
        ExtensionMethod::AfterUpdatePosition => AFTER_UPDATE_POSITION_BIT_SHIFT,
        ExtensionMethod::BeforeCollectFees => BEFORE_COLLECT_FEES_BIT_SHIFT,
        ExtensionMethod::AfterCollectFees => AFTER_COLLECT_FEES_BIT_SHIFT,
    }
}

//get the execution order bit shifter for given method
fn get_queue_bit_shift(method: ExtensionMethod) -> u32 {
    match method {
        ExtensionMethod::BeforeInitPool => BEFORE_INIT_POOL_QUEUE_BIT_SHIFT,
        ExtensionMethod::AfterInitPool => AFTER_INIT_POOL_QUEUE_BIT_SHIFT,
        ExtensionMethod::BeforeSwap => BEFORE_SWAP_QUEUE_BIT_SHIFT,
        ExtensionMethod::AfterSwap => AFTER_SWAP_QUEUE_BIT_SHIFT,
        ExtensionMethod::BeforeUpdatePosition => BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT,
        ExtensionMethod::AfterUpdatePosition => AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT,
        ExtensionMethod::BeforeCollectFees => BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT,
        ExtensionMethod::AfterCollectFees => AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
    }
}

//add or remove method from an extension
pub fn activate_extension(
    activated_extensions: u256, method: ExtensionMethod, extension_id: u8, activate: bool,
) -> u256 {
    //extension id should be less tha MAX_EXTENSIONS_COUNT
    assert(extension_id.into() < MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED);

    //get shift for provided method
    let method_shift = get_method_bit_shift(method);
    //extract 20 bits of method
    let method_bits = (activated_extensions / method_shift) & 0xFFFFF;

    //get 16 bits of flags from method
    let mut method_flags = method_bits & 0x0FFFF;
    //get 4 bits of method count
    let mut method_count = (method_bits / 0x10000) & 0xF;
    //create current extension flag
    let extension_flag = 1 * 2_u256.pow(15 - extension_id.into());

    //to activate merge flag with method flags and increment count
    if activate {
        method_flags = method_flags | extension_flag;
        method_count += 1;
    } // to deactivate make the flag of that bit 0 and decrement the count
    else {
        method_flags = method_flags & ~extension_flag;
        method_count -= 1;
    }

    //shift new method count at the low 4 bits of method
    let new_method_count = method_count * 2_u256.pow(16);
    //merge new count with flags
    let new_method_bits = new_method_count | method_flags;

    // update the activated extensions
    let new_activated_extensions = (activated_extensions & ~(0xFFFFF * method_shift))
        | (new_method_bits * method_shift);

    new_activated_extensions
}

//set the order in which method should called on an extension
pub fn set_queue_position(queue: u32, method: ExtensionMethod, position: u8) -> u32 {
    //extension id should be less tha MAX_EXTENSIONS_COUNT
    assert(position.into() < MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED);
    //get shift for provided method
    let queue_shift = get_queue_bit_shift(method);

    //clear method order bits with NOT of mask
    let mask = 0xF * queue_shift;
    let mut new_queue = queue & ~mask;

    //set new bits for method order
    new_queue = new_queue | ((position.into() & 0xF) * queue_shift);

    new_queue
}
