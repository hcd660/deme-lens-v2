// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IReferenceModule} from '../../interfaces/IReferenceModule.sol';
import {HubRestricted} from '../../base/HubRestricted.sol';
import {Types} from '../../libraries/constants/Types.sol';
import {FollowValidationLib} from '../libraries/FollowValidationLib.sol';

/**
 * @title FollowerOnlyReferenceModule
 * @author Lens Protocol
 *
 * @notice A simple reference module that validates that comments, quotes or mirrors originate from a profile that
 * follows the profile of the original publication.
 */
contract FollowerOnlyReferenceModule is HubRestricted, IReferenceModule {
    constructor(address hub) HubRestricted(hub) {}

    /**
     * @inheritdoc IReferenceModule
     *
     * @dev There is nothing needed at initialization.
     */
    function initializeReferenceModule(
        uint256, /* profileId */
        uint256, /* pubId */
        address, /* transactionExecutor */
        bytes calldata /* data */
    ) external pure returns (bytes memory) {
        return '';
    }

    /**
     * @inheritdoc IReferenceModule
     *
     * @dev Validates that the commenting profile's owner is a follower.
     */
    function processComment(Types.ProcessCommentParams calldata processCommentParams)
        external
        view
        override
        returns (bytes memory)
    {
        FollowValidationLib.validateIsFollowing({
            hub: HUB,
            followerProfileId: processCommentParams.profileId,
            followedProfileId: processCommentParams.pointedProfileId
        });
        return '';
    }

    /**
     * @inheritdoc IReferenceModule
     *
     * @dev Validates that the quoting profile's owner is a follower.
     */
    function processQuote(Types.ProcessQuoteParams calldata processQuoteParams)
        external
        view
        override
        returns (bytes memory)
    {
        FollowValidationLib.validateIsFollowing({
            hub: HUB,
            followerProfileId: processQuoteParams.profileId,
            followedProfileId: processQuoteParams.pointedProfileId
        });
        return '';
    }

    /**
     * @inheritdoc IReferenceModule
     *
     * @dev Validates that the mirroring profile's owner is a follower.
     */
    function processMirror(Types.ProcessMirrorParams calldata processMirrorParams)
        external
        view
        override
        returns (bytes memory)
    {
        FollowValidationLib.validateIsFollowing({
            hub: HUB,
            followerProfileId: processMirrorParams.profileId,
            followedProfileId: processMirrorParams.pointedProfileId
        });
        return '';
    }
}
