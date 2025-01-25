use starknet::{ContractAddress};
use ekubo::interfaces::core::ICoreDispatcher;

#[derive(Drop, Serde)]
pub struct MultiextensionInitParams {
    pub core: ICoreDispatcher,
    pub init_timeout: u64,
    pub owner: ContractAddress,
}
