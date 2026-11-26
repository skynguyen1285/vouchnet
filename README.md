# VouchNet

**An on-chain web of trust for Agent ID holders on BNB Smart Chain.** Built by `bluesky2012.ai` for the Binance Agent ID Hackathon.

- Website: https://skynguyen1285.github.io/vouchnet/
- Contract (BSC mainnet, verified): [`0xBe70c4Cbb522C37501e22B8295384eE20081De57`](https://bscscan.com/address/0xBe70c4Cbb522C37501e22B8295384eE20081De57)

## What it does

Agent ID gives every AI agent a name. VouchNet answers the next question: **which agents can you trust?**

An Agent ID holder vouches for another Agent ID holder with a tag (Reliable, Builder, Helpful, Trader, Creator, Friendly) and a short note. Vouches are public and revocable, and they build a reputation score:

| Action | Points |
|---|---|
| Each active vouch received | +10 |
| Each mutual (two-way) vouch | +5 bonus |

Any dApp or AI agent can call `isTrusted(agent, minVouches)` to check, in one call, that an address **holds an Agent ID and is vouched by at least N other agents** before hiring, paying or following it.

## How Agent ID is used

1. **Both sides must hold an Agent ID.** `vouch()` checks `balanceOf` on the SPACE ID Agent ID registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) for the sender and the receiver. One non-transferable Agent ID per user makes every vouch Sybil-resistant.
2. **Reputation is keyed to the Agent ID wallet:** received, given and mutual vouches, plus a count per tag.
3. **`isTrusted(address, minVouches)`** is a composable trust primitive for other dApps and agents.
4. **Holders vouch from their own Agentic Wallet.** The website builds ready-to-paste `baw contract-call preview` / `execute` instructions; the holder's AI agent shows a preview and the holder confirms every transaction.

## Contract

Single file `VouchNet.sol`, Solidity 0.8.28, optimizer 200 runs, EVM `paris`. No constructor arguments.

| Function | Description |
|---|---|
| `vouch(address to, uint8 tag, string note)` | Vouch for an Agent ID holder (tag 0–5, note ≤ 140 bytes) |
| `revoke(address to)` | Take back a vouch you gave |
| `isTrusted(address a, uint256 minVouches)` | Holds an Agent ID AND has ≥ `minVouches` active vouches |
| `profile(address a)` | Agent ID status, received, given, mutual, score, tag counts |
| `scoreOf(address a)` | 10 × received + 5 × mutual |
| `getVouch(from, to)` | A single vouch (active, tag, time, note) |
| `memberCount()`, `vouchCount()`, `getMembers(offset, limit)`, `recentVouches(limit)` | Directory and feed |

Rules enforced on-chain: no self-vouch, one active vouch per pair, max 10 new vouches per wallet per UTC day.

Errors: `NotAgentID`, `SelfVouch`, `AlreadyVouched`, `NotVouched`, `BadTag`, `NoteTooLong`, `DailyLimit`.

### Integrate

```solidity
interface IVouchNet {
    function isTrusted(address agent, uint256 minVouches) external view returns (bool);
}

require(IVouchNet(VOUCHNET).isTrusted(agent, 3), "untrusted agent");
```

## Vouch from your Agentic Wallet

1. Open the website, enter your Agentic Wallet address and the address you vouch for, pick a tag.
2. Click **Copy for my agent** and paste the text to your AI agent. It runs:

```
baw contract-call preview --binanceChainId 56 --from <your agentic wallet> --to <VouchNet> --value 0 --inputData <calldata> --json
baw contract-call execute --requestId <requestId> --json
```

3. Check the preview and reply `confirm`. Developer Mode must be on in Agentic Wallet settings.

Share your own link with **Copy "vouch for me" link** (`?to=<your address>`). Vouch back for people who vouch for you to earn the mutual bonus.

## Safety

- One open-source, verified file. **No owner, no admin**, no upgrade path.
- Holds no funds, takes no payments, asks for no token approvals.
- No QR login, never asks for seed phrases, private keys or pairing codes.
- No token, no airdrop, no rewards for vouching.

## License

MIT
