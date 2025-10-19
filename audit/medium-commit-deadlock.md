# Missing Commit-Phase Timeout Lets Opponent Lock All Stakes

## Summary

Once a player submits the first commitment for a turn, the game enters the `Committed` state even if the opponent never commits. There is no mechanism to recover or time out from this situation, allowing a malicious opponent to lock both players’ stakes indefinitely.

## Finding Description

`commitMove` transitions the match into `GameState.Committed` as soon as the first commitment of the very first turn is made (`src/RockPaperScissors.sol:191-204`). If the other player withholds their commitment:

1. No reveal deadline is ever set because `game.commitB` remains zero, so `timeoutReveal` cannot be triggered (`src/RockPaperScissors.sol:217-219`).
2. `cancelGame` is now inaccessible to the creator because it requires the game to still be in the `Created` state (`src/RockPaperScissors.sol:320-325`).
3. `timeoutJoin` is also unavailable because `playerB` is already set (`src/RockPaperScissors.sol:332-339`).

As a result, both participants’ stakes remain trapped in the contract forever. An attacker only needs to entice the creator to commit first (for example by promising quick moves) and then simply stop interacting. The protocol’s fairness and availability guarantees are broken because honest players have no on-chain escape hatch.

## (Optional) Proof of Concept

Augment `test/RockPaperScissorsTest.t.sol` with the snippet below and run `forge test --mt testCommitDeadlock -vvvv`:

```solidity
function testCommitDeadlock() public {
    gameId = createAndJoinGame();

    bytes32 saltA = keccak256("salt");
    bytes32 commitA = keccak256(abi.encodePacked(uint8(RockPaperScissors.Move.Rock), saltA));

    vm.prank(playerA);
    game.commitMove(gameId, commitA); // game now in GameState.Committed

    // Creator can no longer cancel the match
    vm.prank(playerA);
    vm.expectRevert("Game must be in created state");
    game.cancelGame(gameId);

    // Reveal timeout is unreachable because playerB never committed
    (bool canTimeout,) = game.canTimeoutReveal(gameId);
    assertFalse(canTimeout, "No timeout path exists without the second commit");
}
```

Running this test demonstrates that the game becomes stuck after the first commitment when the opponent abandons the match.

## Recommendation

Introduce a deadline for the second commitment. For example, store a `commitDeadline` when the first commitment arrives and allow either player (or the creator) to cancel/refund once that deadline passes without the opponent committing. Alternatively, keep the game in `GameState.Created` until both commitments are received so that the creator can still cancel if the opponent never commits.
