// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Checkpoints} from "../lib/openzeppelin-contracts/contracts/utils/structs/Checkpoints.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import {MinimeLikeFactory} from "./MinimeLikeFactory.sol";

import {IMinimeLike} from "./IMinimeLike.sol";

contract MinimeLike is IMinimeLike, ERC20 {
    using Checkpoints for Checkpoints.Trace208;

    mapping(address => Checkpoints.Trace208) internal _balanceHistories;

    Checkpoints.Trace208 internal _totalSupplyHistory;

    address public parentToken;

    uint256 public parentSnapShotBlock;

    uint256 public creationBlock;

    address public tokenFactory;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function migrateToken(
        address _tokenFactory,
        address _parentToken,
        uint256 _parentSnapShotBlock
    ) external {
        tokenFactory = _tokenFactory;
        parentToken = _parentToken;
        parentSnapShotBlock = _parentSnapShotBlock;
        creationBlock = block.number;
    }

    function balanceOf(address _owner) public view override returns (uint256) {
        return balanceOfAt(_owner, block.number);
    }

    function totalSupply() public view override returns (uint) {
        return totalSupplyAt(block.number);
    }

    function balanceOfAt(
        address _owner,
        uint256 _blockNumber
    ) public view returns (uint256) {
        return _calculateBalanceAt(_owner, _blockNumber);
    }

    function totalSupplyAt(uint256 _blockNumber) public view returns (uint) {
        return _calculateTotalSupplyAt(_blockNumber);
    }

    function createCloneToken(uint256 _snapshotBlock) public returns (address) {
        return _createClone(_snapshotBlock);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == to) {
            return;
        }

        _updateBalances(from, to, amount);
        emit Transfer(from, to, amount);
    }

    function _getBalanceAt(
        address _addr,
        uint32 _block
    ) internal view returns (uint256) {
        return _balanceHistories[_addr].upperLookupRecent(_block);
    }

    function _getTotalSupplyAt(uint32 _block) internal view returns (uint256) {
        return _totalSupplyHistory.upperLookupRecent(_block);
    }

    function _calculateBalanceAt(
        address _owner,
        uint256 _blockNumber
    ) private view returns (uint256) {
        (bool exists, , ) = _balanceHistories[_owner].latestCheckpoint();
        if (
            !exists ||
            _balanceHistories[_owner]._checkpoints[0]._key > _blockNumber
        ) {
            return _fallbackBalance(_owner, _blockNumber);
        } else {
            return _getBalanceAt(_owner, uint32(_blockNumber));
        }
    }

    function _calculateTotalSupplyAt(
        uint256 _blockNumber
    ) private view returns (uint256) {
        (bool exists, , ) = _totalSupplyHistory.latestCheckpoint();
        if (
            !exists || _totalSupplyHistory._checkpoints[0]._key > _blockNumber
        ) {
            return _fallbackTotalSupply(_blockNumber);
        } else {
            return _getTotalSupplyAt(uint32(_blockNumber));
        }
    }

    function _createClone(uint256 _snapshotBlock) private returns (address) {
        uint256 snapshot = _snapshotBlock == 0
            ? block.number - 1
            : _snapshotBlock;
        return
            MinimeLikeFactory(tokenFactory).createCloneToken(
                address(this),
                snapshot
            );
    }

    function _updateBalances(address from, address to, uint256 amount) private {
        uint256 totalSupply = totalSupply();
        uint32 blockNumber = uint32(block.number);
        if (from == address(0)) {
            uint208 newTotalSupply = uint208(totalSupply + amount);
            _totalSupplyHistory.push(blockNumber, newTotalSupply);
        } else {
            _updateFromBalance(from, amount, blockNumber);
        }

        if (to == address(0)) {
            uint208 newTotalSupply = uint208(totalSupply - amount);
            _totalSupplyHistory.push(blockNumber, newTotalSupply);
        } else {
            _updateToBalance(to, amount, blockNumber);
        }
    }

    function _updateFromBalance(
        address from,
        uint256 amount,
        uint32 blockNumber
    ) private {
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(from, fromBalance, amount);
        }
        uint208 newFromBalance = uint208(fromBalance - amount);
        _balanceHistories[from].push(blockNumber, newFromBalance);
    }

    function _updateToBalance(
        address to,
        uint256 amount,
        uint32 blockNumber
    ) private {
        uint256 toBalance = balanceOf(to);
        uint208 newToBalance = uint208(toBalance + amount);
        _balanceHistories[to].push(blockNumber, newToBalance);
    }

    function _fallbackBalance(
        address _owner,
        uint256 _blockNumber
    ) private view returns (uint256) {
        if (parentToken != address(0)) {
            uint32 block = uint32(Math.min(_blockNumber, parentSnapShotBlock));
            return MinimeLike(parentToken).balanceOfAt(_owner, block);
        } else {
            return 0;
        }
    }

    function _fallbackTotalSupply(
        uint256 _blockNumber
    ) private view returns (uint256) {
        if (parentToken != address(0)) {
            uint32 block = uint32(Math.min(_blockNumber, parentSnapShotBlock));
            return MinimeLike(parentToken).totalSupplyAt(block);
        } else {
            return 0;
        }
    }
}
