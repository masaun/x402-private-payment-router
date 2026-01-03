import { Wallet } from "@aztec/aztec.js/wallet";
import {
  X402PrivatePaymentRouterContract,
} from "../artifacts/X402PrivatePaymentRouter.js";
import {
  PrivateVaultContract,
} from "../artifacts/PrivateVault.js";
import {
  TokenContract,
} from "../artifacts/Token.js";
import { AztecAddress } from "@aztec/stdlib/aztec-address";

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
  const contract = await TokenContract.deploy(
    deployer,
    name,
    symbol,
    decimals,
    asset,
    upgradeAuthority,
  )
    .send({ from: deployerAddress })
    .deployed();
  return contract;
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
  const contract = await PrivateVaultContract.deploy(
    deployer,
    admin,
    tokenContractAddress,
  )
    .send({ from: deployerAddress })
    .deployed();
  return contract;
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
  const contract = await X402PrivatePaymentRouterContract.deploy(
    deployer,
    admin,
  )
    .send({ from: deployerAddress })
    .deployed();
  return contract;
}