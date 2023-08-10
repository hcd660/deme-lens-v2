// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ITokenHandleRegistry} from '../interfaces/ITokenHandleRegistry.sol';
import {RegistryTypes} from './constants/Types.sol';
import {RegistryErrors} from './constants/Errors.sol';
import {RegistryEvents} from './constants/Events.sol';
import {ILensHub} from '../interfaces/ILensHub.sol';
import {ILensHandles} from '../interfaces/ILensHandles.sol';

/**
 * @title TokenHandleRegistry
 * @author Lens Protocol
 * @notice This contract is used to link a token with a handle.
 * @custom:upgradeable Transparent upgradeable proxy without initializer.
 */
contract TokenHandleRegistry is ITokenHandleRegistry {
    // First version of TokenHandleRegistry only works with Lens Profiles and .lens namespace.
    address immutable LENS_HUB;
    address immutable LENS_HANDLES;

    // Using _handleHash(Handle) and _tokenHash(Token) as keys given that structs cannot be used as them.
    mapping(bytes32 handle => RegistryTypes.Token token) handleToToken;
    mapping(bytes32 token => RegistryTypes.Handle handle) tokenToHandle;

    modifier onlyHandleOwner(uint256 handleId, address transactionExecutor) {
        if (IERC721(LENS_HANDLES).ownerOf(handleId) != transactionExecutor) {
            revert RegistryErrors.NotHandleOwner();
        }
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId, address transactionExecutor) {
        if (IERC721(LENS_HUB).ownerOf(tokenId) != transactionExecutor) {
            revert RegistryErrors.NotTokenOwner();
        }
        _;
    }

    constructor(address lensHub, address lensHandles) {
        LENS_HUB = lensHub;
        LENS_HANDLES = lensHandles;
    }

    // Lens V1 to Lens V2 migration function
    // WARNING: It is able to link the Token and Handle even if they're not in the same wallet.
    //          But it is designed to be only called from LensHub migration function, which assures that they are.
    function migrationLink(uint256 handleId, uint256 tokenId) external {
        if (msg.sender != LENS_HUB) {
            revert RegistryErrors.OnlyLensHub();
        }
        _link(
            RegistryTypes.Handle({collection: LENS_HANDLES, id: handleId}),
            RegistryTypes.Token({collection: LENS_HUB, id: tokenId})
        );
    }

    /// @inheritdoc ITokenHandleRegistry
    function link(
        uint256 handleId,
        uint256 tokenId
    ) external onlyTokenOwner(tokenId, msg.sender) onlyHandleOwner(handleId, msg.sender) {
        _link(
            RegistryTypes.Handle({collection: LENS_HANDLES, id: handleId}),
            RegistryTypes.Token({collection: LENS_HUB, id: tokenId})
        );
    }

    /// @inheritdoc ITokenHandleRegistry
    function unlink(uint256 handleId, uint256 tokenId) external {
        // We revert here only in the case if both tokens exists and the caller is not the owner of any of them
        if (
            ILensHandles(LENS_HANDLES).exists(handleId) &&
            ILensHandles(LENS_HANDLES).ownerOf(handleId) != msg.sender &&
            ILensHub(LENS_HUB).exists(tokenId) &&
            ILensHub(LENS_HUB).ownerOf(tokenId) != msg.sender
        ) {
            revert RegistryErrors.NotHandleNorTokenOwner();
        }

        RegistryTypes.Handle memory handle = RegistryTypes.Handle({collection: LENS_HANDLES, id: handleId});
        RegistryTypes.Token memory tokenPointedByHandle = handleToToken[_handleHash(handle)];

        // We check if the tokens are (were) linked for the case if some of them doesn't exist
        if (tokenPointedByHandle.id != tokenId) {
            revert RegistryErrors.NotLinked();
        }
        _unlink(handle, tokenPointedByHandle);
    }

    /// @inheritdoc ITokenHandleRegistry
    function resolve(uint256 handleId) external view returns (uint256) {
        if (!ILensHandles(LENS_HANDLES).exists(handleId)) {
            revert RegistryErrors.DoesNotExist();
        }
        uint256 resolvedTokenId = _resolveHandleToToken(RegistryTypes.Handle({collection: LENS_HANDLES, id: handleId}))
            .id;
        if (resolvedTokenId == 0 || !ILensHub(LENS_HUB).exists(resolvedTokenId)) {
            return 0;
        }
        return resolvedTokenId;
    }

    /// @inheritdoc ITokenHandleRegistry
    function getDefaultHandle(uint256 tokenId) external view returns (uint256) {
        if (!ILensHub(LENS_HUB).exists(tokenId)) {
            revert RegistryErrors.DoesNotExist();
        }
        uint256 defaultHandleId = _resolveTokenToHandle(RegistryTypes.Token({collection: LENS_HUB, id: tokenId})).id;
        if (defaultHandleId == 0 || !ILensHandles(LENS_HANDLES).exists(defaultHandleId)) {
            return 0;
        }
        return defaultHandleId;
    }

    //////////////////////////////////////
    ///        INTERNAL FUNCTIONS      ///
    //////////////////////////////////////

    function _resolveHandleToToken(
        RegistryTypes.Handle memory handle
    ) internal view returns (RegistryTypes.Token storage) {
        return handleToToken[_handleHash(handle)];
    }

    function _resolveTokenToHandle(
        RegistryTypes.Token memory token
    ) internal view returns (RegistryTypes.Handle storage) {
        return tokenToHandle[_tokenHash(token)];
    }

    function _link(RegistryTypes.Handle memory handle, RegistryTypes.Token memory token) internal {
        _deleteTokenToHandleLinkageIfAny(handle);
        handleToToken[_handleHash(handle)] = token;

        _deleteHandleToTokenLinkageIfAny(token);
        tokenToHandle[_tokenHash(token)] = handle;

        emit RegistryEvents.HandleLinked(handle, token, block.timestamp);
    }

    function _deleteTokenToHandleLinkageIfAny(RegistryTypes.Handle memory handle) internal {
        RegistryTypes.Token memory tokenPointedByHandle = handleToToken[_handleHash(handle)];
        if (tokenPointedByHandle.collection != address(0) || tokenPointedByHandle.id != 0) {
            delete tokenToHandle[_tokenHash(tokenPointedByHandle)];
            emit RegistryEvents.HandleUnlinked(handle, tokenPointedByHandle, block.timestamp);
        }
    }

    function _deleteHandleToTokenLinkageIfAny(RegistryTypes.Token memory token) internal {
        RegistryTypes.Handle memory handlePointedByToken = tokenToHandle[_tokenHash(token)];
        if (handlePointedByToken.collection != address(0) || handlePointedByToken.id != 0) {
            delete handleToToken[_handleHash(handlePointedByToken)];
            emit RegistryEvents.HandleUnlinked(handlePointedByToken, token, block.timestamp);
        }
    }

    function _unlink(RegistryTypes.Handle memory handle, RegistryTypes.Token memory token) internal {
        delete handleToToken[_handleHash(handle)];
        // tokenToHandle is removed too, as the first version linkage is one-to-one.
        delete tokenToHandle[_tokenHash(token)];
        emit RegistryEvents.HandleUnlinked(handle, token, block.timestamp);
    }

    function _handleHash(RegistryTypes.Handle memory handle) internal pure returns (bytes32) {
        return keccak256(abi.encode(handle.collection, handle.id));
    }

    function _tokenHash(RegistryTypes.Token memory token) internal pure returns (bytes32) {
        return keccak256(abi.encode(token.collection, token.id));
    }
}
