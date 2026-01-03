import { Wallet } from "@aztec/aztec.js/wallet";
import {
  X402PrivatePaymentRouterContract,
  X402PrivatePaymentRouterContractArtifact,
} from "../artifacts/X402PrivatePaymentRouter.js";
import {
  PrivateVaultContract,
  PrivateVaultContractArtifact,
} from "../artifacts/PrivateVault.js";
import {
  TokenContract,
  TokenContractArtifact,
} from "../artifacts/Token.js";
import { AztecAddress } from "@aztec/stdlib/aztec-address";
import { Contract } from "@aztec/aztec.js/contracts";

/**
 * Deploys the Token contract.
 * @param deployer - The wallet to deploy the contract with.
 * @param name - The name of the token.
 * @param symbol - The symbol of the token.
 * @param decimals - The decimals of the token.
 * @param asset - The asset address.
 * @param upgradeAuthority - The upgrade authority address.
 * @returns A deployed contract instance.
 */
export async function deployToken(
  deployer: Wallet,
  name: string,
  symbol: string,
  decimals: bigint | number,
  asset: AztecAddress,
  upgradeAuthority: AztecAddress,
): Promise<TokenContract> {
  const deployerAddress = (await deployer.getAccounts())[0]!.item;
  const deployMethod = await Contract.deploy(
    deployer,
    TokenContractArtifact,
    [name, symbol, decimals, asset, upgradeAuthority],
    "constructor",
  );
  const tx = await deployMethod.send({
    from: deployerAddress,
  });
  const contract = await tx.deployed();
  return contract as TokenContract;
}

/**
 * Deploys the PrivateVault contract.
 * @param deployer - The wallet to deploy the contract with.
 * @param admin - The address of the admin of the contract.
 * @param tokenContractAddress - The address of the token contract.
 * @returns A deployed contract instance.
 */
export async function deployPrivateVault(
  deployer: Wallet,
  admin: AztecAddress,
  tokenContractAddress: AztecAddress,
): Promise<PrivateVaultContract> {
  const deployerAddress = (await deployer.getAccounts())[0]!.item;
  const deployMethod = await Contract.deploy(
    deployer,
    PrivateVaultContractArtifact,
    [admin, tokenContractAddress],
    "constructor",
  );
  const tx = await deployMethod.send({
    from: deployerAddress,
  });
  const contract = await tx.deployed();
  return contract as PrivateVaultContract;
}

/**
 * Deploys the X402PrivatePaymentRouter contract.
 * @param deployer - The wallet to deploy the contract with.
 * @param admin - The address of the admin of the contract.
 * @returns A deployed contract instance.
 */
export async function deployX402PrivatePaymentRouter(
  deployer: Wallet,
  admin: AztecAddress,
): Promise<X402PrivatePaymentRouterContract> {
  const deployerAddress = (await deployer.getAccounts())[0]!.item;
  const deployMethod = await Contract.deploy(
    deployer,
    X402PrivatePaymentRouterContractArtifact,
    [admin],
    "constructor",
  );
  const tx = await deployMethod.send({
    from: deployerAddress,
  });
  const contract = await tx.deployed();
  return contract as X402PrivatePaymentRouterContract;
}
