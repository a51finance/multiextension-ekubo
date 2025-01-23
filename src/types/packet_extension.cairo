use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PacketExtension {
    pub extension: ContractAddress,
    pub extensionQueue: u32,
    pub extensionDataDist: u256,
}
