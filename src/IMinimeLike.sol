// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IMinimeLike {
    event ClaimedTokens(
        address indexed token,
        address indexed controller,
        uint256 amount
    );
    event NewCloneToken(address indexed cloneToken, uint256 snapshotBlock);
}
