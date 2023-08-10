// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import 'test/modules/act/collect/BaseFeeCollectModule.base.sol';
import {MultirecipientFeeCollectModule, MultirecipientFeeCollectModuleInitData, RecipientData} from 'contracts/modules/act/collect/MultirecipientFeeCollectModule.sol';

contract MultirecipientCollectModuleBase is BaseFeeCollectModuleBase {
    function testMultirecipientCollectModuleBase() public {
        // Prevents being counted in Foundry Coverage
    }

    using stdJson for string;
    uint16 constant BPS_MAX = 10000;
    uint256 MAX_RECIPIENTS = 5;

    MultirecipientFeeCollectModule multirecipientFeeCollectModule;
    MultirecipientFeeCollectModuleInitData multirecipientExampleInitData;

    function setUp() public virtual override {
        super.setUp();
    }

    // Deploy & Whitelist MultirecipientFeeCollectModule
    constructor() BaseTest() {
        if (fork && keyExists(string(abi.encodePacked('.', forkEnv, '.MultirecipientFeeCollectModule')))) {
            multirecipientFeeCollectModule = MultirecipientFeeCollectModule(
                json.readAddress(string(abi.encodePacked('.', forkEnv, '.MultirecipientFeeCollectModule')))
            );
            console.log('Testing against already deployed module at:', address(multirecipientFeeCollectModule));
        } else {
            vm.prank(deployer);
            multirecipientFeeCollectModule = new MultirecipientFeeCollectModule(
                hubProxyAddr,
                collectPublicationAction,
                address(moduleGlobals)
            );
        }
        baseFeeCollectModule = address(multirecipientFeeCollectModule);
        currency = new MockCurrency();
        vm.prank(modulesGovernance);
        moduleGlobals.whitelistCurrency(address(currency), true);
    }

    function getEncodedInitData() internal virtual override returns (bytes memory) {
        multirecipientExampleInitData.amount = exampleInitData.amount;
        multirecipientExampleInitData.collectLimit = exampleInitData.collectLimit;
        multirecipientExampleInitData.currency = exampleInitData.currency;
        multirecipientExampleInitData.referralFee = exampleInitData.referralFee;
        multirecipientExampleInitData.followerOnly = exampleInitData.followerOnly;
        multirecipientExampleInitData.endTimestamp = exampleInitData.endTimestamp;
        if (multirecipientExampleInitData.recipients.length == 0)
            multirecipientExampleInitData.recipients.push(
                RecipientData({recipient: exampleInitData.recipient, split: BPS_MAX})
            );

        return abi.encode(multirecipientExampleInitData);
    }
}
