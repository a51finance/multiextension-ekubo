use ekubo_multiextension::types::accepted_method::AcceptedMethod;
use ekubo_multiextension::types::packet_extension::PacketExtension;

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
    use starknet::{ContractAddress, get_block_timestamp};
    use starknet::storage::{
        Vec, MutableVecTrait, Mutable, StorageBase, StoragePointerWriteAccess,
        StoragePointerReadAccess,
    };
    use ekubo::components::owned::{Owned as owned_component};
    use ekubo::interfaces::core::{
        ICoreDispatcher, ICoreDispatcherTrait, IExtension, SwapParameters, UpdatePositionParameters,
    };
    use ekubo::types::bounds::{Bounds};
    use ekubo::types::call_points::{CallPoints};
    use ekubo::types::delta::{Delta};
    use ekubo::types::i129::{i129};
    use ekubo::types::keys::{PoolKey};
    use ekubo_multiextension::types::init_params::MultiextensionInitParams;
    use ekubo_multiextension::errors::Errors;
    use ekubo_multiextension::constants::{MAX_EXTENSIONS_COUNT};

    use super::{AcceptedMethod, PacketExtension, IMultiextension};

    component!(path: owned_component, storage: owned, event: OwnedEvent);
    #[abi(embed_v0)]
    impl Owned = owned_component::OwnedImpl<ContractState>;
    impl OwnableImpl = owned_component::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        pub core: ICoreDispatcher,
        pub activated_extensions: u256,
        pub change_extensions_timer: u64,
        pub pending_activated_extensions: u256,
        pub timeout: u64,
        pub extensions: Vec<PacketExtension>,
        pub pending_extensions: Vec<PacketExtension>,
        pub pending_accepted_methods: Vec<AcceptedMethod>,
        #[substorage(v0)]
        owned: owned_component::Storage,
    }

    #[derive(starknet::Event, Drop)]
    struct ExtensionsUpdated {
        updated_extensions: Array<PacketExtension>,
        updated_activated_extensions: u256,
        timestamp: u64,
    }

    #[derive(starknet::Event, Drop)]
    struct NewExtensionsAccepted {
        accepted_extensions: Array<PacketExtension>,
        timestamp: u64,
    }

    #[derive(starknet::Event, Drop)]
    struct NewExtensionsRejected {
        timestamp: u64,
    }

    #[derive(starknet::Event, Drop)]
    struct ExtensionsTimeoutExceeded {
        timestamp: u64,
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    enum Event {
        ExtensionsUpdated: ExtensionsUpdated,
        NewExtensionsAccepted: NewExtensionsAccepted,
        NewExtensionsRejected: NewExtensionsRejected,
        ExtensionsTimeoutExceeded: ExtensionsTimeoutExceeded,
        OwnedEvent: owned_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, params: MultiextensionInitParams) {
        self.core.write(params.core);
        self.activated_extensions.write(params.init_activated_extensions);
        self.timeout.write(params.init_timeout);
        self.initialize_owned(params.owner);
        self._set_call_points();
        self._set_extensions(params.init_extensions, self.extensions);
    }

    enum Error {
        MaxExtensionsCountExceeded: felt252,
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn _set_extensions(
            ref self: ContractState,
            new_extensions: Array<PacketExtension>,
            cell_extensions: StorageBase<Mutable<Vec<PacketExtension>>>,
        ) {
            assert(
                new_extensions.len() <= MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED,
            );

            for index in 0..new_extensions.len() {
                let extension = *(new_extensions.get(index).unwrap().unbox());
                cell_extensions.append().write(extension);
            }
        }
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
        ) {
            self._set_extensions(updated_extensions, self.pending_extensions);
            self.pending_activated_extensions.write(updated_activated_extensions);
            let timestamp = get_block_timestamp();
            self.change_extensions_timer.write(timestamp);
            // self.emit(ExtensionsUpdated {updated_extensions, updated_activated_extensions,
        // timestamp})
        }

        fn accept_new_extensions(ref self: ContractState) {
            assert(
                self.change_extensions_timer.read() != 0, Errors::NO_EXTENSIONS_PENDING_APPROVAL,
            );

            let timestamp = get_block_timestamp();

            assert(
                timestamp <= self.change_extensions_timer.read() + self.timeout.read(),
                Errors::EXTENSIONS_APPROVAL_TIMEOUT,
            );
        }

        fn reject_new_extensions(ref self: ContractState) {}
    }

    #[abi(embed_v0)]
    impl EkuboMultiextension of IExtension<ContractState> {
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
