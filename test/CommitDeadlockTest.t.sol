// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";

contract CommitDeadlockTest is Test {
    RockPaperScissors internal game;

    address internal playerA = address(0xA11CE);
    address internal playerB = address(0xB0B);

    uint256 internal constant BET = 0.1 ether;
    uint256 internal constant TIMEOUT = 10 minutes;
    uint256 internal constant TURNS = 3;

    function setUp() public {
        game = new RockPaperScissors();
        vm.deal(playerA, 10 ether);
        vm.deal(playerB, 10 ether);
    }

    function testCommitDeadlock() public {
        vm.prank(playerA);
        uint256 gameId = game.createGameWithEth{value: BET}(TURNS, TIMEOUT);

        vm.prank(playerB);
        game.joinGameWithEth{value: BET}(gameId);

        bytes32 saltA = keccak256("salt");
        bytes32 commitA = keccak256(abi.encodePacked(uint8(RockPaperScissors.Move.Rock), saltA));

        vm.prank(playerA);
        game.commitMove(gameId, commitA); // transitions to GameState.Committed

        // Creator cannot cancel anymore
        vm.prank(playerA);
        vm.expectRevert("Game must be in created state");
        game.cancelGame(gameId);

        // Join timeout no longer available because state already left Created
        vm.expectRevert("Game must be in created state");
        game.timeoutJoin(gameId);

        // Reveal timeout cannot trigger because revealDeadline is zero (opponent never committed)
        (bool canTimeout, address winner) = game.canTimeoutReveal(gameId);
        assertTrue(canTimeout, "Timeout incorrectly unavailable");
        assertEq(winner, address(0), "Timeout designates no winner yet");

        vm.prank(playerA);
        game.timeoutReveal(gameId);

        // Game ends in cancellation and both players are refunded immediately
        (,,,,,,,,,,,,,,, RockPaperScissors.GameState state) = game.games(gameId);
        assertEq(uint256(state), uint256(RockPaperScissors.GameState.Cancelled), "game unexpectedly halted");
    }
}
