// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {MigrationLib} from '../libraries/MigrationLib.sol';

// Handles
import {LensHandles} from '../namespaces/LensHandles.sol';
import {TokenHandleRegistry} from '../namespaces/TokenHandleRegistry.sol';

contract LensV2Migration {
    address internal immutable FEE_FOLLOW_MODULE;
    address internal immutable PROFILE_FOLLOW_MODULE;
    address internal immutable NEW_FEE_FOLLOW_MODULE;

    LensHandles internal immutable lensHandles;
    TokenHandleRegistry internal immutable tokenHandleRegistry;

    constructor(
        address legacyFeeFollowModule,
        address legacyProfileFollowModule,
        address newFeeFollowModule,
        address lensHandlesAddress,
        address tokenHandleRegistryAddress
    ) {
        FEE_FOLLOW_MODULE = legacyFeeFollowModule;
        PROFILE_FOLLOW_MODULE = legacyProfileFollowModule;
        NEW_FEE_FOLLOW_MODULE = newFeeFollowModule;
        lensHandles = LensHandles(lensHandlesAddress);
        tokenHandleRegistry = TokenHandleRegistry(tokenHandleRegistryAddress);
    }

    function batchMigrateProfiles(uint256[] calldata profileIds) external {
        MigrationLib.batchMigrateProfiles(profileIds, lensHandles, tokenHandleRegistry);
    }

    function batchMigrateFollows(
        uint256[] calldata followerProfileIds,
        uint256[] calldata idsOfProfileFollowed,
        uint256[] calldata followTokenIds
    ) external {
        MigrationLib.batchMigrateFollows(followerProfileIds, idsOfProfileFollowed, followTokenIds);
    }

    function batchMigrateFollowModules(uint256[] calldata profileIds) external {
        MigrationLib.batchMigrateFollowModules(
            profileIds,
            FEE_FOLLOW_MODULE,
            PROFILE_FOLLOW_MODULE,
            NEW_FEE_FOLLOW_MODULE
        );
    }
}
