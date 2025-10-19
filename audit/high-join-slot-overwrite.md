# Joining Players Can Be Replaced, Stranding Earlier Deposits

## Summary

The contract lets any address join a game even after another player has already joined. The new joiner overwrites `playerB` while the previous participant’s stake stays locked in the contract, causing an unrecoverable loss for the displaced player.

## Finding Description

Both `joinGameWithEth` and `joinGameWithToken` only check that the game is in the `Created` state before accepting a joiner (`src/RockPaperScissors.sol:154-184`). They never verify that the `playerB` slot is still empty. As a result:

1. Player B legitimately joins a lobby and deposits their stake.
2. Before the game moves into the commit phase, an attacker (Player C) calls the same join function with the required stake.
3. `playerB` is overwritten with Player C’s address, but Player B’s funds (ETH or token) remain held by the contract forever. Player B also fails the `msg.sender == game.playerB` check in all subsequent game functions, so they cannot recover or interact with the match.

Because state remains `GameState.Created`, the attacker can repeat the process to grief any number of victims. Every displaced player permanently loses their stake while the attacker pays nothing beyond temporarily locking their own deposit (which they can recover by canceling before committing).

## (Optional) Proof of Concept

Paste the following into `test/RockPaperScissorsTest.t.sol` and run `forge test --mt testJoinOverwrite -vvvv` after installing the needed dependencies:

```solidity
function testJoinOverwrite() public {
    address playerC = makeAddr("playerC");

    vm.prank(playerA);
    uint256 id = game.createGameWithEth{value: BET_AMOUNT}(TOTAL_TURNS, TIMEOUT);

    vm.prank(playerB);
    game.joinGameWithEth{value: BET_AMOUNT}(id);

    // Attacker joins after the honest player
    vm.prank(playerC);
    game.joinGameWithEth{value: BET_AMOUNT}(id);

    (, address storedPlayerB,,,,,,,,,,,,,,) = game.games(id);
    assertEq(storedPlayerB, playerC, "playerB slot overwritten");

    // Original playerB can no longer participate
    vm.prank(playerB);
    vm.expectRevert("Not a player in this game");
    game.commitMove(id, bytes32("any"));
}
```

This test shows that the original participant is replaced and cannot continue, while their ETH stays trapped in the contract balance.

## Recommendation

Reject additional join attempts once a second player is registered:

```solidity
require(game.playerB == address(0), "Game already has two players");
```

Add this guard to both `joinGameWithEth` and `joinGameWithToken`. Optionally emit a dedicated event when a join attempt is rejected to aid off-chain monitoring.
