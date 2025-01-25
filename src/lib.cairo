pub mod types {
    pub mod accepted_method;
    pub mod packet_extension;
    pub mod init_params;
}

// #[cfg(test)]
pub mod mock {
    pub mod mock_extension_one;
    pub mod mock_extension_two;
    pub mod token;
}

pub mod constants;
pub mod errors;
pub mod multiextension;
