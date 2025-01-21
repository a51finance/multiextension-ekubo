use starknet::{ContractAddress};

// Tick bounds for a position
#[derive(Copy, Drop, Serde)]
pub struct AcceptedMethod {
    pub extension: ContractAddress,
    pub signature: felt252,
    pub status: bool,
}
