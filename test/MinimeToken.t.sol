// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MinimeLike} from "../src/MinimeLike.sol";
import {MinimeLikeFactory} from "../src/MinimeLikeFactory.sol";

contract MinimeLikeHarness is MinimeLike {
    constructor(
        string memory name,
        string memory symbol
    ) MinimeLike(name, symbol) {}

    function update(address from, address to, uint256 amount) public {
        _update(from, to, amount);
    }

    function getBalanceAt(
        address _addr,
        uint32 _block
    ) public view returns (uint256) {
        return _getBalanceAt(_addr, _block);
    }

    function getTotalSupplyAt(uint32 _block) public view returns (uint256) {
        return _getTotalSupplyAt(_block);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}

contract MinimeLikeTest is Test {
    MinimeLikeHarness public token;
    MinimeLikeFactory public factory;

    function setUp() public {
        factory = new MinimeLikeFactory();
        token = new MinimeLikeHarness("MinimeToken", "MMT");
        token.migrateToken(address(factory), address(0), 0);
    }

    function test_Initialization() public {
        assertEq(token.name(), "MinimeToken");
        assertEq(token.symbol(), "MMT");
        assertEq(token.parentToken(), address(0));
        assertEq(token.parentSnapShotBlock(), 0);
        assertEq(token.tokenFactory(), address(factory));
    }

    function test_BalanceOf() public {
        token.mint(address(this), 100);
        uint256 balance = token.balanceOf(address(this));
        assertEq(token.balanceOf(address(this)), 100);
    }

    function test_BalanceOfTwo() public {
        token.mint(address(this), 100);
        vm.roll(block.number + 5);
        token.mint(address(this), 100);
        uint256 balance = token.balanceOf(address(this));
        assertEq(token.balanceOf(address(this)), 200);
    }

    function test_TotalSupply() public {
        token.mint(address(this), 100);
        uint256 supply = token.totalSupply();
        assertEq(supply, 100);
    }

    function test_BalanceAtPastBlocks() public {
        token.mint(address(this), 100);
        vm.roll(block.number + 5);
        token.mint(address(this), 50);
        vm.roll(block.number + 5);
        token.mint(address(this), 25);

        uint256 balanceAtBlock0 = token.balanceOfAt(
            address(this),
            block.number - 10
        );
        uint256 balanceAtBlock5 = token.balanceOfAt(
            address(this),
            block.number - 5
        );
        uint256 currentBalance10 = token.balanceOf(address(this));

        assertEq(balanceAtBlock5, 150, "Balance at block 5 should be 150");
        assertEq(currentBalance10, 175, "Current balance should be 175");
    }

    function test_TotalSupplyAtPastBlocks() public {
        token.mint(address(this), 100);
        vm.roll(block.number + 5);
        token.mint(address(this), 50);
        vm.roll(block.number + 5);
        token.mint(address(this), 25);

        uint256 supplyAtBlock10 = token.totalSupplyAt(block.number - 10);
        uint256 supplyAtBlock5 = token.totalSupplyAt(block.number - 5);
        uint256 currentSupply = token.totalSupply();

        assertEq(
            supplyAtBlock10,
            100,
            "Total supply at block 10 should be 100"
        );
        assertEq(supplyAtBlock5, 150, "Total supply at block 5 should be 150");
        assertEq(currentSupply, 175, "Current total supply should be 175");
    }

    function test_TransfersBetweenAccounts() public {
        address user1 = address(0x1);
        address user2 = address(0x2);
        address user3 = address(0x3);

        token.mint(user1, 100);

        vm.prank(user1);
        token.transfer(user2, 50);
        assertEq(token.balanceOf(user1), 50);
        assertEq(token.balanceOf(user2), 50);

        vm.prank(user2);
        token.transfer(user3, 25);
        assertEq(token.balanceOf(user2), 25);
        assertEq(token.balanceOf(user3), 25);

        vm.prank(user3);
        token.transfer(user1, 25);
        assertEq(token.balanceOf(user3), 0);
        assertEq(token.balanceOf(user1), 75);
    }

    function test_TransferToZeroAddress() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(address(0), 50);
    }

    function test_TransferFromZeroBalance() public {
        address user1 = address(0x1);
        address user2 = address(0x2);

        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 50);
    }

    function test_SelfTransfer() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        vm.prank(user1);
        token.transfer(user1, 50);
        assertEq(
            token.balanceOf(user1),
            100,
            "Balance should remain unchanged after self-transfer"
        );
    }

    function test_BalanceAtFutureBlock() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        uint256 futureBlock = block.number + 1000;
        uint256 balanceAtFuture = token.balanceOfAt(user1, futureBlock);
        assertEq(
            balanceAtFuture,
            100,
            "Balance at a future block should reflect the last known balance"
        );
    }

    function test_BalanceAtPastBlock() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        uint256 pastBlock = block.number - 1;
        uint256 balanceAtPast = token.balanceOfAt(user1, pastBlock);
        assertEq(balanceAtPast, 0, "Balance at a past block should be 0");
    }

    function test_TotalSupplyAtFutureBlock() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        uint256 futureBlock = block.number + 1000;
        uint256 totalSupplyAtFuture = token.totalSupplyAt(futureBlock);
        assertEq(
            totalSupplyAtFuture,
            100,
            "Total supply at a future block should reflect the last known total supply"
        );
    }

    function test_TotalSupplyAtPastBlock() public {
        address user1 = address(0x1);
        token.mint(user1, 100);

        uint256 pastBlock = block.number - 1;
        uint256 totalSupplyAtPast = token.totalSupplyAt(pastBlock);
        assertEq(
            totalSupplyAtPast,
            0,
            "Total supply at a past block should be 0"
        );
    }

    function test_MintToZeroAddress() public {
        uint256 amount = 100;
        vm.expectRevert();
        token.mint(address(0), amount);
    }

    function test_BurnMoreThanBalance() public {
        address user1 = address(0x1);
        uint256 mintAmount = 100;
        uint256 burnAmount = 200;
        token.mint(user1, mintAmount);

        vm.expectRevert();
        token.burn(user1, burnAmount);
    }
}
