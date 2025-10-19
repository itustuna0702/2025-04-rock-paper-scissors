## Issue 1

The enum value `GameState.Revealed` is never assigned anywhere in the lifecycle (`src/RockPaperScissors.sol:21`). Keeping an unused state makes it harder to reason about valid transitions and invites future bugs when contributors assume the state is reachable.

## Issue 2

When a match ends in a tie the protocol still charges the full 10% fee before refunding players (`src/RockPaperScissors.sol:516`). If the product requirement is to reimburse both players on a draw, the current logic contradicts that expectation and will surprise users. Consider clarifying the economics or skipping the fee in tie scenarios.

## Issue 3

`setAdmin` does not emit an event when ownership is transferred (`src/RockPaperScissors.sol:362`), making it harder for off-chain indexers and security monitors to notice administrative handovers.

## Issue 4

The game moves into `GameState.Committed` immediately after the very first commitment even though the opponent has not yet committed (`src/RockPaperScissors.sol:197-201`). This state naming can confuse integrators and contributes to the commitment deadlock scenario; consider deferring the state switch until both commitments are recorded.

## Issue 5

`timeoutReveal` relies on `game.revealDeadline`, but that deadline stays at its zero-value until both commitments arrive (`src/RockPaperScissors.sol:217-219`). Because the function only checks that `block.timestamp > game.revealDeadline`, a player can trigger the timeout path immediately after the first commit, effectively turning the function into an unconditional cancel button and rendering the timeout interval misleading.

## Issue 6

`cancelGame` keeps working even after a second player joins because the state remains `GameState.Created` until the first commitment (`src/RockPaperScissors.sol:154-165` and `src/RockPaperScissors.sol:320-326`). This lets the creator abort the lobby after an opponent has locked funds, which may contradict user expectations that the match becomes binding once another player joins.
