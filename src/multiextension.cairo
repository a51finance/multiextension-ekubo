use ekubo_multiextension::types::packet_extension::PacketExtension;

#[starknet::interface]
pub trait IMultiextension<TContractState> {
    fn init_extensions(
        ref self: TContractState,
        init_extensions: Span<PacketExtension>,
        init_activated_extensions: u256,
    );
    fn change_extensions(
        ref self: TContractState,
        updated_extensions: Span<PacketExtension>,
        updated_activated_extensions: u256,
    );
    fn accept_new_extensions(ref self: TContractState);
    fn reject_new_extensions(ref self: TContractState);
}

#[starknet::contract]
pub mod Multiextension {
    use core::num::traits::Pow;
    use core::dict::Felt252Dict;
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_block_timestamp, contract_address_const};
    use starknet::storage::{
        Map, Mutable, StorageBase, StoragePointerWriteAccess, StoragePointerReadAccess,
        StoragePathEntry,
    };
    use ekubo::components::owned::{Owned as owned_component};
    use ekubo::interfaces::core::{
        ICoreDispatcher, ICoreDispatcherTrait, IExtension, IExtensionDispatcher,
        IExtensionDispatcherTrait, SwapParameters, UpdatePositionParameters,
    };
    use ekubo::types::bounds::Bounds;
    use ekubo::types::call_points::CallPoints;
    use ekubo::types::delta::Delta;
    use ekubo::types::i129::i129;
    use ekubo::types::keys::PoolKey;
    use ekubo_multiextension::types::init_params::MultiextensionInitParams;
    use ekubo_multiextension::errors::Errors;
    use ekubo_multiextension::constants::{
        MAX_EXTENSIONS_COUNT, BEFORE_INIT_POOL_BIT_SHIFT, AFTER_INIT_POOL_BIT_SHIFT,
        BEFORE_SWAP_BIT_SHIFT, AFTER_SWAP_BIT_SHIFT, BEFORE_UPDATE_POSITION_BIT_SHIFT,
        AFTER_UPDATE_POSITION_BIT_SHIFT, BEFORE_COLLECT_FEES_BIT_SHIFT,
        AFTER_COLLECT_FEES_BIT_SHIFT, BEFORE_INIT_POOL_QUEUE_BIT_SHIFT,
        AFTER_INIT_POOL_QUEUE_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT, AFTER_SWAP_QUEUE_BIT_SHIFT,
        BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT, AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT,
        BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT, AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
    };

    use super::{PacketExtension, IMultiextension};

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
        pub extension_count: u32,
        pub extensions: Map<u32, PacketExtension>,
        pub pending_extensions_count: u32,
        pub pending_extensions: Map<u32, PacketExtension>,
        pub initialized: bool,
        #[substorage(v0)]
        owned: owned_component::Storage,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExtensionsUpdated {
        updated_extensions: Span<PacketExtension>,
        updated_activated_extensions: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewExtensionsAccepted {
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewExtensionsRejected {
        timestamp: u64,
    }

    #[derive(starknet::Event, Drop)]
    #[event]
    pub enum Event {
        ExtensionsUpdated: ExtensionsUpdated,
        NewExtensionsAccepted: NewExtensionsAccepted,
        NewExtensionsRejected: NewExtensionsRejected,
        OwnedEvent: owned_component::Event,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, params: MultiextensionInitParams) {
        self.core.write(params.core);
        self.timeout.write(params.init_timeout);
        self.initialize_owned(params.owner);
        self._set_call_points();
    }

    fn get_queue_position(extension_queue: u32, bit_shift: u32) -> u32 {
        (extension_queue / bit_shift) & 0xF
    }

    #[generate_trait]
    pub impl Internal of InternalTrait {
        fn _set_extensions(
            ref self: ContractState,
            new_extensions: Span<PacketExtension>,
            cell_extensions: StorageBase<Mutable<Map<u32, PacketExtension>>>,
        ) {
            assert(
                new_extensions.len() <= MAX_EXTENSIONS_COUNT, Errors::MAX_EXTENSIONS_COUNT_EXCEEDED,
            );

            for index in 0..new_extensions.len() {
                let extension = *(new_extensions.get(index).unwrap().unbox());
                cell_extensions.entry(index).write(extension);
            };
        }

        fn _set_call_points(self: @ContractState) {
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

        fn _get_activated_extensions(
            self: @ContractState,
            ref active_extensions: Felt252Dict<felt252>,
            bit_shift: u256,
            queue_bit_shift: u32,
        ) -> u8 {
            let extension_info = (self.activated_extensions.read() / bit_shift) & 0xFFFFF;
            let extension_count: u8 = ((extension_info / 0x10000) & 0xF).try_into().unwrap();
            let extension_flags = extension_info & 0x0FFFF;

            for index in 0..extension_count {
                active_extensions.insert(index.into(), contract_address_const::<0>().into());
            };

            for index in 0..self.extension_count.read() {
                let flag_check = 1 * 2_u256.pow(15 - index);
                if ((extension_flags & flag_check) != 0) {
                    let packet = self.extensions.entry(index).read();
                    let queue_position = get_queue_position(
                        packet.extension_queue, queue_bit_shift,
                    );
                    active_extensions.insert(queue_position.into(), packet.extension.into());
                }
            };

            extension_count
        }
    }

    #[abi(embed_v0)]
    impl MultiextensionImpl of IMultiextension<ContractState> {
        fn init_extensions(
            ref self: ContractState,
            init_extensions: Span<PacketExtension>,
            init_activated_extensions: u256,
        ) {
            self.require_owner();
            assert(!self.initialized.read(), Errors::ALREADY_INITIALIZED);
            self._set_extensions(init_extensions, self.extensions);
            self.activated_extensions.write(init_activated_extensions);
            self.extension_count.write(init_extensions.len());
            self.initialized.write(true);
        }

        fn change_extensions(
            ref self: ContractState,
            updated_extensions: Span<PacketExtension>,
            updated_activated_extensions: u256,
        ) {
            self.require_owner();
            assert(self.initialized.read(), Errors::NOT_INITIALIZED);
            assert(self.pending_extensions_count.read() == 0, Errors::CHANGE_PENDING);
            self._set_extensions(updated_extensions, self.pending_extensions);
            self.pending_activated_extensions.write(updated_activated_extensions);
            self.pending_extensions_count.write(updated_extensions.len());
            let timestamp = get_block_timestamp();
            self.change_extensions_timer.write(timestamp);
            self
                .emit(
                    ExtensionsUpdated {
                        updated_extensions: updated_extensions,
                        updated_activated_extensions,
                        timestamp,
                    },
                )
        }

        fn accept_new_extensions(ref self: ContractState) {
            self.require_owner();
            assert(
                self.change_extensions_timer.read() != 0, Errors::NO_EXTENSIONS_PENDING_APPROVAL,
            );

            let timestamp = get_block_timestamp();

            assert(
                timestamp > self.change_extensions_timer.read() + self.timeout.read(),
                Errors::EXTENSIONS_APPROVAL_TIMEOUT,
            );

            for index in 0..self.pending_extensions_count.read() {
                let pending_extension = self.pending_extensions.entry(index).read();
                self.extensions.entry(index).write(pending_extension);
            };

            self.extension_count.write(self.pending_extensions_count.read());
            self.activated_extensions.write(self.pending_activated_extensions.read());

            self.change_extensions_timer.write(0);
            self.pending_activated_extensions.write(0);
            self.pending_extensions_count.write(0);

            self.emit(NewExtensionsAccepted { timestamp });
        }

        fn reject_new_extensions(ref self: ContractState) {
            self.require_owner();
            assert(
                self.change_extensions_timer.read() != 0, Errors::NO_EXTENSIONS_PENDING_APPROVAL,
            );

            let timestamp = get_block_timestamp();

            self.change_extensions_timer.write(0);
            self.pending_activated_extensions.write(0);
            self.pending_extensions_count.write(0);

            self.emit(NewExtensionsRejected { timestamp });
        }
    }

    #[abi(embed_v0)]
    impl EkuboMultiextension of IExtension<ContractState> {
        fn before_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    BEFORE_INIT_POOL_BIT_SHIFT,
                    BEFORE_INIT_POOL_QUEUE_BIT_SHIFT,
                );

            for index in 0..extensions_count {
                let contract_address: ContractAddress = active_extensions
                    .get(index.into())
                    .try_into()
                    .unwrap();

                IExtensionDispatcher { contract_address }
                    .before_initialize_pool(caller, pool_key, initial_tick);
            };
        }

        fn after_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    AFTER_INIT_POOL_BIT_SHIFT,
                    AFTER_INIT_POOL_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }
                    .after_initialize_pool(caller, pool_key, initial_tick);
            }
        }

        fn before_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions, BEFORE_SWAP_BIT_SHIFT, BEFORE_SWAP_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }.before_swap(caller, pool_key, params);
            }
        }

        fn after_swap(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: SwapParameters,
            delta: Delta,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions, AFTER_SWAP_BIT_SHIFT, AFTER_SWAP_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }.before_swap(caller, pool_key, params);
            }
        }

        fn before_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    BEFORE_UPDATE_POSITION_BIT_SHIFT,
                    BEFORE_UPDATE_POSITION_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }
                    .before_update_position(caller, pool_key, params);
            }
        }

        fn after_update_position(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            params: UpdatePositionParameters,
            delta: Delta,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    AFTER_UPDATE_POSITION_BIT_SHIFT,
                    AFTER_UPDATE_POSITION_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }
                    .after_update_position(caller, pool_key, params, delta);
            }
        }

        fn before_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    BEFORE_COLLECT_FEES_BIT_SHIFT,
                    BEFORE_COLLECT_FEES_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }
                    .before_collect_fees(caller, pool_key, salt, bounds);
            }
        }

        fn after_collect_fees(
            ref self: ContractState,
            caller: ContractAddress,
            pool_key: PoolKey,
            salt: felt252,
            bounds: Bounds,
            delta: Delta,
        ) {
            let mut active_extensions: Felt252Dict<felt252> = Default::default();
            let extensions_count = self
                ._get_activated_extensions(
                    ref active_extensions,
                    AFTER_COLLECT_FEES_BIT_SHIFT,
                    AFTER_COLLECT_FEES_QUEUE_BIT_SHIFT,
                );
            for index in 0..extensions_count {
                let contract_address = (active_extensions.get(index.into())).try_into().unwrap();
                IExtensionDispatcher { contract_address }
                    .after_collect_fees(caller, pool_key, salt, bounds, delta);
            }
        }
    }
}
