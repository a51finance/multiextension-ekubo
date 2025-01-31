use starknet::{ContractAddress};

#[starknet::interface]
pub trait IMockExtension<TContractState> {
    fn get_count(self: @TContractState) -> u8;
    fn get_locker(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod MockextensionOne {
    use starknet::{ContractAddress};
    use starknet::storage::{StoragePointerWriteAccess, StoragePointerReadAccess};
    use ekubo::interfaces::core::{
        IExtension, ICoreDispatcher, ICoreDispatcherTrait, ILocker, IForwardee,
        IForwardeeDispatcher, SwapParameters, UpdatePositionParameters,
    };
    use ekubo::components::shared_locker::{
        call_core_with_callback, consume_callback_data, forward_lock,
    };
    use ekubo::types::bounds::{Bounds};
    use ekubo::types::delta::{Delta};
    use ekubo::types::i129::{i129};
    use ekubo::types::keys::{PoolKey};
    use ekubo::types::call_points::{CallPoints};

    use super::IMockExtension;

    #[storage]
    struct Storage {
        pub core: ICoreDispatcher,
        pub multiextension: ContractAddress,
        pub count: u8,
        pub locker: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, core: ICoreDispatcher, multiextension: ContractAddress,
    ) {
        self.core.write(core);
        self.multiextension.write(multiextension);
        core
            .set_call_points(
                CallPoints {
                    before_initialize_pool: true,
                    after_initialize_pool: false,
                    before_swap: false,
                    after_swap: true,
                    before_update_position: true,
                    after_update_position: false,
                    before_collect_fees: false,
                    after_collect_fees: false,
                },
            );
    }

    #[abi(embed_v0)]
    impl MockextensionImp of IMockExtension<ContractState> {
        fn get_count(self: @ContractState) -> u8 {
            self.count.read()
        }

        fn get_locker(self: @ContractState) -> ContractAddress {
            self.locker.read()
        }
    }

    #[abi(embed_v0)]
    impl MockextensionOneImpl of IExtension<ContractState> {
        fn before_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) {
            let core = self.core.read();
            call_core_with_callback::<(PoolKey, u8), ()>(core, @(pool_key, 5));
        }

        fn after_initialize_pool(
            ref self: ContractState, caller: ContractAddress, pool_key: PoolKey, initial_tick: i129,
        ) { // assert(false, 'Call point not used');
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

    #[abi(embed_v0)]
    impl LockedImpl of ILocker<ContractState> {
        fn locked(ref self: ContractState, id: u32, data: Span<felt252>) -> Span<felt252> {
            // self.locker.write(self.core.read().contract_address);
            // let (_, count) = consume_callback_data::<(PoolKey, u8)>(self.core.read(), data);
            // self.count.write(count);

            let core = self.core.read();
            forward_lock::<
                u8, (),
            >(core, IForwardeeDispatcher { contract_address: self.multiextension.read() }, @2);
            array![].span()
        }
    }

    #[abi(embed_v0)]
    impl ForwardeeImpl of IForwardee<ContractState> {
        fn forwarded(
            ref self: ContractState, original_locker: ContractAddress, id: u32, data: Span<felt252>,
        ) -> Span<felt252> {
            let count = consume_callback_data::<u8>(self.core.read(), data);
            self.count.write(count);
            self.locker.write(original_locker);
            array![].span()
        }
    }
}
