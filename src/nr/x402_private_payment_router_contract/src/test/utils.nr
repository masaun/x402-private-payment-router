use crate::X402PrivatePaymentRouter;
use aztec::{
    protocol_types::address::AztecAddress, test::helpers::test_environment::TestEnvironment,
};

// @dev - Import the PrivateVault contract for unified deployment
use private_vault::PrivateVault;

// @dev - Import the Token contract for unified deployment
use token::Token;

pub global mint_amount: u128 = 10_000 as u128;

pub unconstrained fn setup_contract(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, payer) = if with_account_contracts {
        let owner = env.create_contract_account();
        let payer = env.create_contract_account();
        (owner, payer)
    } else {
        let owner = env.create_light_account();
        let payer = env.create_light_account();
        (owner, payer)
    };

    let contract_address = deploy_x402_private_payment_router_contract(&mut env, owner);

    (&mut env, contract_address, owner, payer)
}

/// @notice - Unified setup function that deploys ALL THREE contracts (Token, PrivateVault, X402PrivatePaymentRouter)
/// in the SAME TestEnvironment. This is critical for nested cross-contract calls to work in TXE.
/// 
/// The issue with nested calls (A -> B -> C) is that TXE needs to find the artifact for contract C
/// when it's called from within B's context. If C was deployed in a different TestEnvironment context,
/// the artifact lookup fails with "Function artifact not found".
pub unconstrained fn setup_all_contracts(
    with_account_contracts: bool,
) -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys - ALL contracts will share this environment
    let mut env = TestEnvironment::new();
    let (admin, payer) = if with_account_contracts {
        let admin = env.create_contract_account();
        let payer = env.create_contract_account();
        (admin, payer)
    } else {
        let admin = env.create_light_account();
        let payer = env.create_light_account();
        (admin, payer)
    };

    // 1. Deploy Token contract FIRST with initial supply to admin
    let token_contract_address = deploy_token_with_initial_supply(&mut env, admin, mint_amount, admin);

    // 2. Transfer public tokens to private for admin
    env.call_private(
        admin,
        Token::at(token_contract_address).transfer_public_to_private(admin, admin, mint_amount, 0),
    );

    // 3. Deploy PrivateVault contract (NOTE: The PrivateVault must use the same Token contract address with the TestEnvironment of the X402PrivatePaymentRouter contract)
    let private_vault_contract_address = deploy_private_vault_contract(&mut env, admin, token_contract_address);

    // 4. Deploy X402PrivatePaymentRouter contract
    let x402_contract_address = deploy_x402_private_payment_router_contract(&mut env, admin);

    (env, x402_contract_address, private_vault_contract_address, token_contract_address, admin, payer)
}

pub unconstrained fn deploy_x402_private_payment_router_contract(
    env: &mut TestEnvironment,
    owner: AztecAddress,
) -> AztecAddress {
    let initializer_call_interface = X402PrivatePaymentRouter::interface().constructor(owner);
    let contract_address =
        env.deploy("@x402_private_payment_router_contract/X402PrivatePaymentRouter").with_public_initializer(owner, initializer_call_interface);

    contract_address
}

pub unconstrained fn deploy_private_vault_contract(
    env: &mut TestEnvironment,
    owner: AztecAddress,
    token_contract_address: AztecAddress,
) -> AztecAddress {
    let initializer_call_interface = PrivateVault::interface().constructor(owner, token_contract_address);
    let contract_address =
        env.deploy("@private_vault_contract/PrivateVault").with_public_initializer(owner, initializer_call_interface);

    contract_address
}

pub unconstrained fn deploy_token_with_initial_supply(
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
