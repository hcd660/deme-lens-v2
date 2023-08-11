import '@nomiclabs/hardhat-ethers';
import { hexlify, keccak256, RLP } from 'ethers/lib/utils';
import fs from 'fs';

import {
    LensHub__factory,
    CollectNFT__factory,
    FeeFollowModule__factory,
    FollowerOnlyReferenceModule__factory,
    FollowNFT__factory,
    ModuleGlobals__factory,
    TransparentUpgradeableProxy__factory,
    UIDataProvider__factory,
    RevertFollowModule__factory,
    ProfileCreationProxy__factory,
    ProfileLib__factory,
    MigrationLib__factory,
    GovernanceLib__factory,
    MetaTxLib__factory,
    PublicationLib__factory,
    FollowLib__factory,
    LegacyCollectLib__factory,
    ValidationLib__factory,
    ActionLib__factory,
    ProfileTokenURILib__factory,
    TokenURIMainFontLib__factory,
    TokenURISecondaryFontLib__factory,
    FollowTokenURILib__factory,
    CollectPublicationAction__factory,
    LensHandles__factory,
    HandleTokenURILib__factory,
    TokenHandleRegistry__factory, LensHubInitializable__factory,
} from "../typechain-types";
import { deployContract, waitForTx } from '../tasks/helpers/utils';
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const TREASURY_FEE_BPS = 50;
const LENS_HUB_NFT_NAME = 'Lens Protocol Profiles';
const LENS_HUB_NFT_SYMBOL = 'LPP';

async function main() {
  // Note that the use of these signers is a placeholder and is not meant to be used in
  // production.
  const [deployer, governance, treasuryAddress]: SignerWithAddress[] = await ethers.getSigners();
  const proxyAdminAddress = deployer.address;
  const profileCreatorAddress = deployer.address;

  // Nonce management in case of deployment issues
  let deployerNonce = await ethers.provider.getTransactionCount(deployer.address);

  console.log('\n\t-- Deploying Module Globals --', deployerNonce);
  const moduleGlobals = await deployContract(
    new ModuleGlobals__factory(deployer).deploy(
        governance.address,
      treasuryAddress.address,
      TREASURY_FEE_BPS,
      {
        gasPrice: 2000000000,
        nonce: deployerNonce++,
      }
    )
  );

  console.log('\n\t-- Deploying Logic Libs --');

  const profileLib = await deployContract(
    new ProfileLib__factory(deployer).deploy({
        gasPrice: 2000000000,
        nonce: deployerNonce++,
      })
  );

    const migrationLib = await deployContract(
        new MigrationLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const governanceLib = await deployContract(
        new GovernanceLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const metaTxLib = await deployContract(
        new MetaTxLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const followLib = await deployContract(
        new FollowLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const publicationLib = await deployContract(
        new PublicationLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const validationLib = await deployContract(
        new ValidationLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const validationLibs = {'contracts/libraries/ValidationLib.sol:ValidationLib': validationLib.address}

    const legacyCollectLib = await deployContract(
        new LegacyCollectLib__factory(validationLibs, deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const actionLib = await deployContract(
        new ActionLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const tokenURIMainFontLib = await deployContract(
        new TokenURIMainFontLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const tokenURISecondaryFontLib = await deployContract(
        new TokenURISecondaryFontLib__factory(deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const profileTokenURILibLibraryAddressesLibs = {
        "contracts/libraries/token-uris/TokenURIMainFontLib.sol:TokenURIMainFontLib": tokenURIMainFontLib.address,
        "contracts/libraries/token-uris/TokenURISecondaryFontLib.sol:TokenURISecondaryFontLib": tokenURISecondaryFontLib.address
    }

    const profileTokenURILib = await deployContract(
        new ProfileTokenURILib__factory(profileTokenURILibLibraryAddressesLibs, deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );


    const hubLibs = {
    'contracts/libraries/ProfileLib.sol:ProfileLib': profileLib.address,
    'contracts/libraries/MigrationLib.sol:MigrationLib': migrationLib.address,
    'contracts/libraries/GovernanceLib.sol:GovernanceLib': governanceLib.address,
    'contracts/libraries/MetaTxLib.sol:MetaTxLib':metaTxLib.address,
    'contracts/libraries/FollowLib.sol:FollowLib':followLib.address,
    'contracts/libraries/PublicationLib.sol:PublicationLib':publicationLib.address,
    'contracts/libraries/LegacyCollectLib.sol:LegacyCollectLib':legacyCollectLib.address,
    'contracts/libraries/ActionLib.sol:ActionLib':actionLib.address,
    'contracts/libraries/token-uris/ProfileTokenURILib.sol:ProfileTokenURILib':profileTokenURILib.address,
  };


  // Here, we pre-compute the nonces and addresses used to deploy the contracts.
  // const nonce = await deployer.getTransactionCount();
  const followNFTNonce = hexlify(deployerNonce + 1);
    const actionModuleNonce = hexlify(deployerNonce + 2);
  const collectNFTNonce = hexlify(deployerNonce + 3);
  const lensHandlesNonce = hexlify(deployerNonce + 4);
  const tokenHandleRegistryNonce = hexlify(deployerNonce + 5);
  const newFeeFollowModuleNonce = hexlify(deployerNonce + 6);
  const hubProxyNonce = hexlify(deployerNonce + 7);

  const followNFTImplAddress =
    '0x' + keccak256(RLP.encode([deployer.address, followNFTNonce])).substr(26);

    const actionModuleAddress =
        '0x' + keccak256(RLP.encode([deployer.address, actionModuleNonce])).substr(26);

  const collectNFTImplAddress =
    '0x' + keccak256(RLP.encode([deployer.address, collectNFTNonce])).substr(26);
    const lensHandlesAddress =
        '0x' + keccak256(RLP.encode([deployer.address, lensHandlesNonce])).substr(26);
    const tokenHandleRegistryAddress =
        '0x' + keccak256(RLP.encode([deployer.address, tokenHandleRegistryNonce])).substr(26);

    const newFeeFollowModule =
        '0x' + keccak256(RLP.encode([deployer.address, newFeeFollowModuleNonce])).substr(26);
  const hubProxyAddress =
    '0x' + keccak256(RLP.encode([deployer.address, hubProxyNonce])).substr(26);


  console.log('\n\t-- followNFTImplAddress --', followNFTImplAddress);
  console.log('\n\t-- collectNFTImplAddress --', collectNFTImplAddress);
  console.log('\n\t-- hubProxyAddress --', hubProxyAddress);

  // Next, we deploy first the hub implementation, then the followNFT implementation, the collectNFT, and finally the
  // hub proxy with initialization.
  console.log('\n\t-- Deploying Hub Implementation --');
  const tokenGuardianCooldown = 0;
  const lensHubImpl = await deployContract(
    new LensHubInitializable__factory(hubLibs, deployer).deploy(
        moduleGlobals.address
        , followNFTImplAddress
        , collectNFTImplAddress
        , lensHandlesAddress
        , tokenHandleRegistryAddress
        , newFeeFollowModule
        , tokenGuardianCooldown
        ,{
          gasPrice: 2000000000,
          nonce: deployerNonce++,
        })
  );

  console.log('\n\t-- Deploying Hub Implementation end --');

    // Next, we deploy first the hub implementation, then the followNFT implementation, the collectNFT, and finally the
    // hub proxy with initialization.

    const followTokenURILib = await deployContract(
        new FollowTokenURILib__factory(profileTokenURILibLibraryAddressesLibs, deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

   const  followNFTLibraryAddresses = {
        ["contracts/libraries/token-uris/FollowTokenURILib.sol:FollowTokenURILib"]: followTokenURILib.address
    }

  console.log('\n\t-- Deploying Follow & Collect NFT Implementations --');
    //1
  await deployContract(
    new FollowNFT__factory(followNFTLibraryAddresses, deployer).deploy(hubProxyAddress, {
      gasPrice: 2000000000,
      nonce: deployerNonce++,
    })
  );
    console.log('\n\t-- 1 end --');
  //2
    await deployContract(
        new CollectPublicationAction__factory(deployer).deploy(hubProxyAddress, collectNFTImplAddress, moduleGlobals.address, {
            gasPrice: 2000000000,
            nonce: deployerNonce++
        })
    );
    console.log('\n\t-- 2 end --');
    //3
  await deployContract(
    new CollectNFT__factory(deployer).deploy(hubProxyAddress, actionModuleAddress, {
      gasPrice: 2000000000,
      nonce: deployerNonce++
    })
  );
    console.log('\n\t-- 3 end --');
    const handleTokenURILib = await deployContract(
        new HandleTokenURILib__factory(profileTokenURILibLibraryAddressesLibs, deployer).deploy({
            gasPrice: 2000000000,
            nonce: deployerNonce++,
        })
    );

    const lensHandlesLibraryAddresses = {
        ["contracts/libraries/token-uris/HandleTokenURILib.sol:HandleTokenURILib"]: handleTokenURILib.address
    }
    //4
    await deployContract(
        new LensHandles__factory(lensHandlesLibraryAddresses, deployer).deploy(deployer.address, hubProxyAddress, tokenGuardianCooldown, {
            gasPrice: 2000000000,
            nonce: deployerNonce++
        })
    );
    console.log('\n\t-- 4 end --');
    //5
    await deployContract(
        new TokenHandleRegistry__factory(deployer).deploy(hubProxyAddress, lensHandlesAddress, {
            gasPrice: 2000000000,
            nonce: deployerNonce++
        })
    );
    console.log('\n\t-- 5 end --');
    //6 newFeeFollowModuleNonce
    await deployContract(
        new FeeFollowModule__factory(deployer).deploy(hubProxyAddress, moduleGlobals.address, {
            gasPrice: 2000000000,
            nonce: deployerNonce++
        })
    );
    console.log('\n\t-- 6 end --');

  let data = lensHubImpl.interface.encodeFunctionData('initialize', [
    LENS_HUB_NFT_NAME,
    LENS_HUB_NFT_SYMBOL,
      governance.address,
  ]);

  console.log('\n\t-- Deploying Hub Proxy --');
  let proxy = await deployContract(
    new TransparentUpgradeableProxy__factory(deployer).deploy(
      lensHubImpl.address,
      proxyAdminAddress,
      data,
      {
        gasPrice: 2000000000,
        nonce: deployerNonce++,
      }
    )
  );

    const lensHub = LensHub__factory.connect(proxy.address, governance);


  // Save and log the addresses
  const addrs = {
    'lensHub proxy': lensHub.address,
    'lensHub impl:': lensHubImpl.address,
    'follow NFT impl': followNFTImplAddress,
    'collect NFT impl': collectNFTImplAddress,
    'module globals': moduleGlobals.address,
      'tokenHandleRegistryAddress': tokenHandleRegistryAddress,
      lensHandlesAddress,
      newFeeFollowModule,
  };
  const json = JSON.stringify(addrs, null, 2);
  console.log(json);

  fs.writeFileSync('addresses.json', json, 'utf-8');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e);
    process.exit(1);
  });

//  npx hardhat run scripts/deploy.ts --network local
