// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IUniverseWhitelist} from "damanfi-protocol/IUniverseWhitelist.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title UniverseRegistry. UUPS-upgradeable curator-permissioned implementation of `IUniverseWhitelist`.
/// @notice The contract is curation-agnostic by construction. The
///         flagship Daman deployment seeds this contract from the
///         HLAL (Wahed-FTSE-USA) ETF holdings on each rebalance, but
///         the contract itself takes no opinion on what the universe
///         is or how it was curated.
///
/// @dev Hardening:
///      - UUPS-upgradeable. Owner is a TimelockController set via
///        `initialize`. The owner authorizes upgrades; the
///        operational curator (which adds/removes assets) is
///        separate.
///      - `Pausable`: `addAsset` / `removeAsset` / `setSource` gate
///        on `whenNotPaused`. `isEligible` and `listAssets` reads
///        stay open so consumer contracts can continue to read the
///        whitelist during pause.
///      - Storage: 30-slot `__gap` at end.
contract UniverseRegistry is
    IUniverseWhitelist,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    address public curator;
    bytes32 private _sourceTag;
    uint64 private _lastUpdatedAt;

    address[] private _assets;
    mapping(address => uint256) private _indexPlusOne;

    uint256[30] private __gap;

    event CuratorRotated(address indexed previous, address indexed next);

    error ZeroAddress();
    error EmptySource();

    modifier onlyCurator() {
        if (msg.sender != curator) revert UnauthorizedCurator(msg.sender);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialCurator,
        bytes32 initialSourceTag,
        address initialOwner
    ) external initializer {
        if (initialCurator == address(0)) revert ZeroAddress();
        if (initialOwner == address(0)) revert ZeroAddress();
        if (initialSourceTag == bytes32(0)) revert EmptySource();
        __Ownable_init(initialOwner);
        __Pausable_init();
        __UUPSUpgradeable_init();
        curator = initialCurator;
        _sourceTag = initialSourceTag;
        _lastUpdatedAt = uint64(block.timestamp);
        emit UniverseUpdated(initialSourceTag, _lastUpdatedAt);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rotateCurator(address next) external onlyCurator {
        if (next == address(0)) revert ZeroAddress();
        emit CuratorRotated(curator, next);
        curator = next;
    }

    function setSource(bytes32 nextSourceTag) external onlyCurator whenNotPaused {
        if (nextSourceTag == bytes32(0)) revert EmptySource();
        _sourceTag = nextSourceTag;
        _lastUpdatedAt = uint64(block.timestamp);
        emit UniverseUpdated(nextSourceTag, _lastUpdatedAt);
    }

    function addAsset(address asset, bytes32 source) external onlyCurator whenNotPaused {
        if (asset == address(0)) revert ZeroAddress();
        if (_indexPlusOne[asset] != 0) revert AssetAlreadyListed(asset);
        _assets.push(asset);
        _indexPlusOne[asset] = _assets.length;
        _lastUpdatedAt = uint64(block.timestamp);
        emit AssetAdded(asset, source);
    }

    function removeAsset(address asset, bytes32 reason) external onlyCurator whenNotPaused {
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
