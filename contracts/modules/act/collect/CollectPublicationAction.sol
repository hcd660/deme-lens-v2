// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IPublicationActionModule} from '../../../interfaces/IPublicationActionModule.sol';
import {ICollectModule} from '../../../interfaces/ICollectModule.sol';
import {ICollectNFT} from '../../../interfaces/ICollectNFT.sol';
import {Types} from '../../../libraries/constants/Types.sol';
import {Events} from '../../../libraries/constants/Events.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {Errors} from '../../../libraries/constants/Errors.sol';
import {HubRestricted} from '../../../base/HubRestricted.sol';
import {IModuleGlobals} from '../../../interfaces/IModuleGlobals.sol';

contract CollectPublicationAction is HubRestricted, IPublicationActionModule {
    struct CollectData {
        address collectModule;
        address collectNFT;
    }

    event CollectModuleWhitelisted(address collectModule, bool whitelist, uint256 timestamp);

    address public immutable COLLECT_NFT_IMPL;
    address public immutable MODULE_GLOBALS;

    mapping(address collectModule => bool isWhitelisted) internal _collectModuleWhitelisted;
    mapping(uint256 profileId => mapping(uint256 pubId => CollectData collectData)) internal _collectDataByPub;

    constructor(address hub, address collectNFTImpl, address moduleGlobals) HubRestricted(hub) {
        COLLECT_NFT_IMPL = collectNFTImpl;
        MODULE_GLOBALS = moduleGlobals;
    }

    function whitelistCollectModule(address collectModule, bool whitelist) external {
        address governance = IModuleGlobals(MODULE_GLOBALS).getGovernance();
        if (msg.sender != governance) {
            revert Errors.NotGovernance();
        }
        _collectModuleWhitelisted[collectModule] = whitelist;
        emit CollectModuleWhitelisted(collectModule, whitelist, block.timestamp);
    }

    function initializePublicationAction(
        uint256 profileId,
        uint256 pubId,
        address transactionExecutor,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (address collectModule, bytes memory collectModuleInitData) = abi.decode(data, (address, bytes));
        if (!_collectModuleWhitelisted[collectModule]) {
            revert Errors.NotWhitelisted();
        }
        _collectDataByPub[profileId][pubId].collectModule = collectModule;
        ICollectModule(collectModule).initializePublicationCollectModule(
            profileId,
            pubId,
            transactionExecutor,
            collectModuleInitData
        );
        return data;
    }

    function processPublicationAction(
        Types.ProcessActionParams calldata processActionParams
    ) external override onlyHub returns (bytes memory) {
        address collectModule = _collectDataByPub[processActionParams.publicationActedProfileId][
            processActionParams.publicationActedId
        ].collectModule;
        if (collectModule == address(0)) {
            revert Errors.CollectNotAllowed();
        }
        address collectNFT = _getOrDeployCollectNFT({
            publicationCollectedProfileId: processActionParams.publicationActedProfileId,
            publicationCollectedId: processActionParams.publicationActedId,
            collectNFTImpl: COLLECT_NFT_IMPL
        });
        uint256 tokenId = ICollectNFT(collectNFT).mint(processActionParams.actorProfileOwner);
        bytes memory collectActionResult = _processCollect(collectModule, processActionParams);

        emit Events.Collected({
            collectActionParams: processActionParams,
            collectModule: collectModule,
            collectNFT: collectNFT,
            tokenId: tokenId,
            collectActionResult: collectActionResult,
            timestamp: block.timestamp
        });

        return abi.encode(tokenId, collectActionResult);
    }

    function getCollectData(uint256 profileId, uint256 pubId) external view returns (CollectData memory) {
        return _collectDataByPub[profileId][pubId];
    }

    function _getOrDeployCollectNFT(
        uint256 publicationCollectedProfileId,
        uint256 publicationCollectedId,
        address collectNFTImpl
    ) private returns (address) {
        address collectNFT = _collectDataByPub[publicationCollectedProfileId][publicationCollectedId].collectNFT;
        if (collectNFT == address(0)) {
            collectNFT = _deployCollectNFT(publicationCollectedProfileId, publicationCollectedId, collectNFTImpl);
            _collectDataByPub[publicationCollectedProfileId][publicationCollectedId].collectNFT = collectNFT;
        }
        return collectNFT;
    }

    function _processCollect(
        address collectModule,
        Types.ProcessActionParams calldata processActionParams
    ) private returns (bytes memory) {
        return
            ICollectModule(collectModule).processCollect(
                Types.ProcessCollectParams({
                    publicationCollectedProfileId: processActionParams.publicationActedProfileId,
                    publicationCollectedId: processActionParams.publicationActedProfileId,
                    collectorProfileId: processActionParams.actorProfileId,
                    collectorProfileOwner: processActionParams.actorProfileOwner,
                    transactionExecutor: processActionParams.transactionExecutor,
                    referrerProfileIds: processActionParams.referrerProfileIds,
                    referrerPubIds: processActionParams.referrerPubIds,
                    referrerPubTypes: processActionParams.referrerPubTypes,
                    data: processActionParams.actionModuleData
                })
            );
    }

    function _deployCollectNFT(uint256 profileId, uint256 pubId, address collectNFTImpl) private returns (address) {
        address collectNFT = Clones.clone(collectNFTImpl);

        ICollectNFT(collectNFT).initialize(profileId, pubId);
        emit Events.CollectNFTDeployed(profileId, pubId, collectNFT, block.timestamp);

        return collectNFT;
    }

    function isCollectModuleWhitelisted(address collectModule) external view returns (bool) {
        return _collectModuleWhitelisted[collectModule];
    }
}
