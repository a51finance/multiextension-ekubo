#[starknet::interface]
pub trait IMockExtension<TContractState> {}

#[starknet::contract]
pub mod MockextensionTwo {
    use starknet::{ContractAddress};
    use ekubo::interfaces::core::{IExtension, SwapParameters, UpdatePositionParameters};
    use ekubo::types::bounds::{Bounds};
    use ekubo::types::delta::{Delta};
    use ekubo::types::i129::{i129};
    use ekubo::types::keys::{PoolKey};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockextensionTwoImpl of IExtension<ContractState> {
        fn before_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {// assert(false, 'Call point not used two');
        }

        fn after_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            assert(false, 'Call point not used');
        }

        fn before_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
        ) {
            assert(false, 'Call point not used');
        }

        fn after_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
            delta: Delta,
        ) {
            assert(false, 'Call point not used');
        }

        fn before_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
        ) {
            assert(false, 'Call point not used');
        }

        fn after_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
            delta: Delta,
        ) {
            assert(false, 'Call point not used');
        }

        fn before_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
        ) {
            assert(false, 'Call point not used');
        }

        fn after_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
            delta: Delta,
        ) {
            assert(false, 'Call point not used');
        }
    }
}
