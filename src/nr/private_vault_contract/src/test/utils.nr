use crate::PrivateVault;
use token::Token; // @dev - Import the Token contract (token_contract/src/main.nr)
use aztec::{
    protocol_types::address::AztecAddress, 
    test::helpers::test_environment::TestEnvironment,
};

pub global mint_amount: u128 = 10_000 as u128;
pub global initial_supply: u128 = 1_000_000 as u128;

pub unconstrained fn setup_contract(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, user) = if with_account_contracts {
        let owner = env.create_contract_account();
        let user = env.create_contract_account();
        (owner, user)
    } else {
        let owner = env.create_light_account();
        let user = env.create_light_account();
        (owner, user)
    };

    let private_vault_contract_address = deploy_private_vault_contract(&mut env, owner);
    let token_contract_address = deploy_token_contract_with_initial_supply(&mut env, owner, initial_supply, owner);

    // @dev - Return values
    (&mut env, private_vault_contract_address, token_contract_address, owner, user)
}

pub unconstrained fn deploy_private_vault_contract(
    env: &mut TestEnvironment,
    owner: AztecAddress,
) -> AztecAddress {
    let initializer_call_interface = PrivateVault::interface().constructor(owner);
    let contract_address =
        env.deploy("PrivateVault").with_public_initializer(owner, initializer_call_interface);

    contract_address
}

pub unconstrained fn deploy_token_contract_with_initial_supply(
    env: &mut TestEnvironment,
    owner: AztecAddress,
    initial_supply: u128,
    to: AztecAddress,
) -> AztecAddress {
    // Deploy token contract
    let initializer_call_interface = Token::interface().constructor_with_initial_supply(
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
        initial_supply,
        to,
        AztecAddress::zero(),
    );
    let token_contract_address = env.deploy("@token_contract/Token").with_public_initializer(
        owner,
        initializer_call_interface,
    );

    token_contract_address
}