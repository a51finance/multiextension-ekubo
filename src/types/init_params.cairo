use starknet::{ContractAddress};
use ekubo::interfaces::core::ICoreDispatcher;
use ekubo_multiextension::types::packet_extension::PacketExtension;

#[derive(Drop, Serde)]
pub struct MultiextensionInitParams {
    pub core: ICoreDispatcher,
    pub init_extensions: Array<PacketExtension>,
    pub init_activated_extensions: u256,
    pub init_timeout: u64,
    pub owner: ContractAddress,
}
