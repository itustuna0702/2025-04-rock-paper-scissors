# Instant Reveal Timeout Lets Malicious Player Cancel and Refund Immediately

## Summary

As soon as the first player commits, the game switches to `GameState.Committed` but the reveal deadline remains at its default zero. Because `timeoutReveal` only checks `block.timestamp > game.revealDeadline`, any player can call it immediately to cancel the match and reclaim stakes, making it impossible to force the opponent to reveal.

## Finding Description

- `commitMove` sets the game state to `Committed` after the first commitment but only assigns `revealDeadline` when both commitments are present (`src/RockPaperScissors.sol:197-219`).
- In this state, `timeoutReveal` is callable by either player. The function only verifies that the caller is one of the players and that `block.timestamp > game.revealDeadline` (`src/RockPaperScissors.sol:262-279`).
- Because `revealDeadline` is still zero, the inequality holds immediately. A malicious player (including the one who already committed) can invoke `timeoutReveal` right away, triggering `_cancelGame` and refunding both stakes without playing any turns (`src/RockPaperScissors.sol:262-309`).
- This defeats the purpose of the commit phase: an honest player cannot compel the opponent to proceed, and the attacker can grief by cancelling lobbies on demand.

## (Optional) Proof of Concept

Paste the following test into `test/CommitDeadlockTest.t.sol` and run `forge test --mt testInstantTimeout -vvvv`:

```solidity
function testInstantTimeout() public {
    vm.prank(playerA);
    uint256 gameId = game.createGameWithEth{value: BET}(TURNS, TIMEOUT);

    vm.prank(playerB);
    game.joinGameWithEth{value: BET}(gameId);

    bytes32 saltA = keccak256("salt");
    bytes32 commitA = keccak256(abi.encodePacked(uint8(RockPaperScissors.Move.Rock), saltA));

    vm.prank(playerA);
    game.commitMove(gameId, commitA);

    // No one else has committed, yet timeoutReveal succeeds immediately
    vm.prank(playerA);
    game.timeoutReveal(gameId);

    (,,,,,,,,,,,,,,, RockPaperScissors.GameState state) = game.games(gameId);
    assertEq(uint256(state), uint256(RockPaperScissors.GameState.Cancelled));
}
```

The assertion passes, showing that a player can cancel and refund everything moments after committing their move.

## Recommendation

Delay the ability to call `timeoutReveal` until both commitments are recorded. Set `revealDeadline` when the second commitment arrives and add a guard such as:

```solidity
require(game.commitA != bytes32(0) && game.commitB != bytes32(0), "Both players must commit first");
```

Alternatively, keep the game in `GameState.Created` until both commitments are submitted, preventing `timeoutReveal` from being callable prematurely.

