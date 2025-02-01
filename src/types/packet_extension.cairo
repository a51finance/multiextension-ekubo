use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct PacketExtension {
    pub extension: ContractAddress,
    pub extension_queue: u32,
}
