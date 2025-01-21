use ekubo_multiextension::types::accepted_method::AcceptedMethod;
use ekubo_multiextension::types::packet_extension::{PacketExtension};

#[starknet::interface]
pub trait IMultiextension<TContractState> {
    fn change_extensions(
        ref self: TContractState,
        updated_extensions: Array<PacketExtension>,
        updated_accepted_methods: Array<AcceptedMethod>,
        updated_activated_extensions: u256,
    );
    fn accept_new_extensions(ref self: TContractState);
    fn reject_new_extensions(ref self: TContractState);
}

#[starknet::contract]
pub mod Multiextension {
    use core::starknet::storage::{Vec, StoragePointerReadAccess, StoragePointerWriteAccess};
    use ekubo::interfaces::core::{
        ICoreDispatcher, ICoreDispatcherTrait, IExtension, SwapParameters, UpdatePositionParameters,
    };
    use ekubo::types::bounds::{Bounds};
    use ekubo::types::call_points::{CallPoints};
    use ekubo::types::delta::{Delta};
    use ekubo::types::i129::{i129};
    use ekubo::types::keys::{PoolKey};

    use super::{AcceptedMethod, PacketExtension, IMultiextension};

    #[storage]
    struct Storage {
        pub core: ICoreDispatcher,
        pub activatedExtensions: u256,
        pub changeHooksTimer: u256,
        pub pendingActivatedExtensions: u256,
        pub timeout: u256,
        pub extensions: Vec<PacketExtension>,
        pub pendingExtensions: Vec<PacketExtension>,
        pub pendingAcceptedMethods: Vec<AcceptedMethod>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, core: ICoreDispatcher) {
        self.core.write(core);
        self._set_call_points();
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn _set_extensions(ref self: ContractState, new_extensions: Array<PacketExtension>) {}
        fn _accept_methods(ref self: ContractState, new_accepted_methods: Array<AcceptedMethod>) {}
        fn _set_call_points(ref self: ContractState) {
            self
                .core
                .read()
                .set_call_points(
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
    }

    #[abi(embed_v0)]
    impl MultiextensionImpl of IMultiextension<ContractState> {
        fn change_extensions(
            ref self: ContractState,
            updated_extensions: Array<PacketExtension>,
            updated_accepted_methods: Array<AcceptedMethod>,
            updated_activated_extensions: u256,
        ) {}

        fn accept_new_extensions(ref self: ContractState) {}

        fn reject_new_extensions(ref self: ContractState) {}
    }

    #[abi(embed_v0)]
    impl OracleExtension of IExtension<ContractState> {
        fn before_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            assert(false, 'Call point not used');
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
