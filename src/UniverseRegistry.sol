// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IUniverseWhitelist} from "damanfi-protocol/IUniverseWhitelist.sol";

/// @title UniverseRegistry. Curator-permissioned reference implementation of `IUniverseWhitelist`.
/// @notice The contract is curation-agnostic by construction. The
///         flagship Daman deployment seeds this contract from the
///         HLAL (Wahed-FTSE-USA) ETF holdings on each rebalance, but
///         the contract itself takes no opinion on what the universe
///         is or how it was curated. Other deployments may seed from
///         any source.
///
/// @dev Single-curator policy. The curator address is set at deploy
///      and may be rotated by the current curator. For richer policies
///      (multisig, oracle-driven, attestation-based), deploy a
///      different implementation of `IUniverseWhitelist`.
contract UniverseRegistry is IUniverseWhitelist {
    address public curator;
    bytes32 private _sourceTag;
    uint64 private _lastUpdatedAt;

    address[] private _assets;
    mapping(address => uint256) private _indexPlusOne;

    event CuratorRotated(address indexed previous, address indexed next);

    error ZeroAddress();
    error EmptySource();

    modifier onlyCurator() {
        if (msg.sender != curator) revert UnauthorizedCurator(msg.sender);
        _;
    }

    constructor(address initialCurator, bytes32 initialSourceTag) {
        if (initialCurator == address(0)) revert ZeroAddress();
        if (initialSourceTag == bytes32(0)) revert EmptySource();
        curator = initialCurator;
        _sourceTag = initialSourceTag;
        _lastUpdatedAt = uint64(block.timestamp);
        emit UniverseUpdated(initialSourceTag, _lastUpdatedAt);
    }

    function rotateCurator(address next) external onlyCurator {
        if (next == address(0)) revert ZeroAddress();
        emit CuratorRotated(curator, next);
        curator = next;
    }

    function setSource(bytes32 nextSourceTag) external onlyCurator {
        if (nextSourceTag == bytes32(0)) revert EmptySource();
        _sourceTag = nextSourceTag;
        _lastUpdatedAt = uint64(block.timestamp);
        emit UniverseUpdated(nextSourceTag, _lastUpdatedAt);
    }

    function addAsset(address asset, bytes32 source) external onlyCurator {
        if (asset == address(0)) revert ZeroAddress();
        if (_indexPlusOne[asset] != 0) revert AssetAlreadyListed(asset);
        _assets.push(asset);
        _indexPlusOne[asset] = _assets.length;
        _lastUpdatedAt = uint64(block.timestamp);
        emit AssetAdded(asset, source);
    }

    function removeAsset(address asset, bytes32 reason) external onlyCurator {
        uint256 idx = _indexPlusOne[asset];
        if (idx == 0) revert AssetNotListed(asset);
        uint256 lastIdx = _assets.length;
        if (idx != lastIdx) {
            address moved = _assets[lastIdx - 1];
            _assets[idx - 1] = moved;
            _indexPlusOne[moved] = idx;
        }
        _assets.pop();
        delete _indexPlusOne[asset];
        _lastUpdatedAt = uint64(block.timestamp);
        emit AssetRemoved(asset, reason);
    }

    function isEligible(address asset) external view returns (bool) {
        return _indexPlusOne[asset] != 0;
    }

    function listAssets() external view returns (address[] memory) {
        return _assets;
    }

    function sourceTag() external view returns (bytes32) {
        return _sourceTag;
    }

    function lastUpdatedAt() external view returns (uint64) {
        return _lastUpdatedAt;
    }
}
