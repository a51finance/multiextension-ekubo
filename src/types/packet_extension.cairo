use starknet::{ContractAddress};

// Tick bounds for a position
#[derive(Copy, Drop, Serde)]
pub struct PacketExtension {
    pub extension: ContractAddress,
    pub extensionQueue: u32,
    pub extensionDataDist: u256,
}
