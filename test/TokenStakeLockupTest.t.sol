// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";
import "../src/WinningToken.sol";

contract TokenStakeLockupTest is Test {
    RockPaperScissors internal game;
    WinningToken internal token;

    address internal playerA = address(0xA11CE);
    address internal playerB = address(0xB0B);

    uint256 internal constant TIMEOUT = 10 minutes;
    uint256 internal constant TURNS = 1;

    function setUp() public {
        game = new RockPaperScissors();
        token = WinningToken(game.winningToken());

        vm.deal(playerA, 10 ether);
        vm.deal(playerB, 10 ether);

        // Mint tokens to players via the game contract owner
        vm.prank(address(game));
        token.mint(playerA, 5);

        vm.prank(address(game));
        token.mint(playerB, 5);
    }

    function testTokenStakeNeverReturned() public {
        uint256 playerABalanceBefore = token.balanceOf(playerA);
        uint256 playerBBalanceBefore = token.balanceOf(playerB);
        uint256 contractBalanceBefore = token.balanceOf(address(game));

        vm.startPrank(playerA);
        token.approve(address(game), 1);
        uint256 gameId = game.createGameWithToken(TURNS, TIMEOUT);
        vm.stopPrank();

        vm.startPrank(playerB);
        token.approve(address(game), 1);
        game.joinGameWithToken(gameId);
        vm.stopPrank();

        // Both players stake 1 token each -> contract holds 2 now
        assertEq(token.balanceOf(address(game)), contractBalanceBefore + 2);

        // Complete the turn with playerA winning
        bytes32 saltA = keccak256("saltA");
        bytes32 commitA = keccak256(abi.encodePacked(uint8(RockPaperScissors.Move.Rock), saltA));

        bytes32 saltB = keccak256("saltB");
        bytes32 commitB = keccak256(abi.encodePacked(uint8(RockPaperScissors.Move.Scissors), saltB));

        vm.prank(playerA);
        game.commitMove(gameId, commitA);

        vm.prank(playerB);
        game.commitMove(gameId, commitB);

        vm.prank(playerA);
        game.revealMove(gameId, uint8(RockPaperScissors.Move.Rock), saltA);

        vm.prank(playerB);
        game.revealMove(gameId, uint8(RockPaperScissors.Move.Scissors), saltB);

        // Winner should have collected both stakes, but current implementation mints instead
        assertEq(token.balanceOf(playerA), playerABalanceBefore + 1, "winner only receives minted token");
        assertEq(token.balanceOf(address(game)), contractBalanceBefore + 2, "staked tokens remain locked");
        assertEq(token.balanceOf(playerB), playerBBalanceBefore - 1, "loser loses stake without redistribution");
    }
}
