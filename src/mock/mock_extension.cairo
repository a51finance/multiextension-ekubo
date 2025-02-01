#[starknet::interface]
pub trait IMockExtension<TContractState> {}

#[starknet::contract]
pub mod Mockextension {
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress};
    use starknet::storage::{StoragePointerWriteAccess, StoragePointerReadAccess};
    use ekubo::interfaces::core::{IExtension, SwapParameters, UpdatePositionParameters};
    use ekubo::types::bounds::Bounds;
    use ekubo::types::delta::Delta;
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;

    #[storage]
    struct Storage {
        order: u8
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExtensionOrder {
        order: u8,
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    pub enum Event {
        ExtensionOrder: ExtensionOrder,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, order: u8) {
        self.order.write(order);
    }

    #[abi(embed_v0)]
    impl MockextensionImpl of IExtension<ContractState> {
        fn before_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn after_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn before_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn after_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
            delta: Delta,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn before_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn after_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
            delta: Delta,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn before_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }

        fn after_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
            delta: Delta,
        ) {
            self.emit(ExtensionOrder {order:self.order.read()});
        }
    }
}
