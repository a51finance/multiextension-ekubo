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

pub fn activate_extension(
    activated_extensions: u256, method: ExtensionMethod, extension_id: u8, activate: bool,
) -> u256 {
    assert(extension_id.into() < MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED);
    let method_shift = get_method_bit_shift(method);
    let method_bits = (activated_extensions / method_shift) & 0xFFFFF;

    let mut method_flags = method_bits & 0x0FFFF;
    let mut method_count = (method_bits / 0x10000) & 0xF;
    let extension_flag = 1 * 2_u256.pow(15 - extension_id.into());

    if activate {
        method_flags = method_flags | extension_flag;
        method_count += 1;
    } else {
        method_flags = method_flags & ~extension_flag;
        method_count -= 1;
    }

    let new_method_count = method_count * 2_u256.pow(16);
    let new_method_bits = new_method_count | method_flags;

    let new_activated_extensions = (activated_extensions & ~(0xFFFFF * method_shift))
        | (new_method_bits * method_shift);
    new_activated_extensions
}

pub fn set_queue_position(queue: u32, method: ExtensionMethod, position: u8) -> u32 {
    assert(position.into() < MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED);
    let queue_shift = get_queue_bit_shift(method);
    let mask = 0xF * queue_shift;
    let mut new_queue = queue & ~mask;
    new_queue = new_queue | ((position.into() & 0xF) * queue_shift);
    new_queue
}
