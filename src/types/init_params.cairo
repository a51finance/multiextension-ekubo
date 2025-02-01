use starknet::{ContractAddress};
use ekubo::interfaces::core::ICoreDispatcher;

//multiextension constructor params
#[derive(Drop, Serde)]
pub struct MultiextensionInitParams {
    pub core: ICoreDispatcher,
    pub init_timeout: u64,
    pub owner: ContractAddress,
}
