// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {MinimeLike} from "./MinimeLike.sol";

contract MinimeLikeFactory {
    event NewFactoryCloneToken(
        address indexed _cloneToken,
        address indexed _parentToken,
        uint _snapshotBlock
    );

    /// @notice Update the DApp by creating a new token with new functionalities
    ///  the msg.sender becomes the controller of this clone token
    /// @param _parentToken Address of the token being cloned
    /// @param _snapshotBlock Block of the parent token that will
    ///  determine the initial distribution of the clone token
    /// @return The address of the new token contract
    function createCloneToken(
        address _parentToken,
        uint _snapshotBlock
    ) public returns (address) {
        new MinimeLike("", "");
    }
}
