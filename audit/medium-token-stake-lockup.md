# Token Stake Locked and Inflationary Payouts Break Token Game Economics

## Summary

Token-based games never return the staked tokens that were transferred into the contract. Instead, the contract continually mints fresh tokens to pay winners or refunds, permanently locking the stakes and inflating supply.

## Finding Description

- Each player staking the Winner Token transfers one token into the game contract (`src/RockPaperScissors.sol:124` and `src/RockPaperScissors.sol:170`). Those tokens accumulate in the contract’s balance.
- When the match concludes—win, tie, or cancellation—the code mints new tokens to the players instead of transferring the originally staked tokens back. See the payout logic in `_finishGame` (`src/RockPaperScissors.sol:495`), `_handleTie` (`src/RockPaperScissors.sol:534`), and `_cancelGame` (`src/RockPaperScissors.sol:565`).
- Because the staked tokens are never moved out of the contract again, every game permanently removes two tokens from circulation while minting replacements. This both inflates total supply and traps the original tokens in the contract.

The intended “winner-takes-all” mechanic for token games is therefore broken: the winner does not receive the loser’s stake, and the contract’s token balance grows unbounded. Over time this undermines the token economy and deviates from both user expectations and the advertised “token-only games” fee model.

## (Optional) Impact Explanation

Continuous inflation and stake lockup makes the Winner Token supply meaningless and prevents the stake mechanism from working as a zero-sum competition. It also allows the contract owner to later repurpose the trapped tokens if any transfer path is added, creating an unexpected treasury.

## Recommendation

Return the actual staked tokens that the contract already holds. Replace every `mint` used as a refund/payout with a transfer from the contract’s balance, for example:

```solidity
// Example for the ETH game payout branch
if (game.bet == 0) {
    // Transfer the two staked tokens held by the contract
    winningToken.transfer(_winner, 2);
}
```

Apply the same pattern in tie and cancellation handlers so that stakes are redistributed rather than minted anew.
