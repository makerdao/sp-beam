# Direct Stability Parameters Change (DSPC) Module - Facilitator Guide

## Overview

The DSPC module enables authorized facilitators to update three types of rates in the Maker system:
- Stability fees for collateral types (ilks)
- Dai Savings Rate (DSR)
- Sky Savings Rate (SSR)

This guide explains how to effectively use the contract to update these rates while respecting the configured constraints.

## Key Constraints

### Time-Based Constraints

The contract enforces a global cooldown period (`tau`) between rate updates. This means:
- After any rate update, you must wait for `tau` seconds before executing another update
- This applies to ALL rates - even if you update DSR now, you cannot update SSR or any ilk until `tau` seconds have passed
- The cooldown is global, not per-rate

Example timeline:
```
Time 0:     Update DSR from 4% to 5%
Time 0-3600: Cooldown period (assuming tau = 3600 seconds)
Time 3600+:  Next update allowed (any rate can be updated)
```

### Rate Constraints

Each rate (ilk, DSR, SSR) has three configured constraints:
- `min`: Minimum allowed rate in basis points
- `max`: Maximum allowed rate in basis points
- `step`: Maximum allowed change in basis points per update

The step constraint allows rates to move gradually over multiple updates. After each update, the new rate becomes the reference point for the next allowed step change.

Example:
```
For a rate with:
min = 0 (0%)
max = 1000 (10%)
step = 100 (1%)

Current rate: 500 (5%)
Allowed range for next update: 400-600 (4%-6%)
```

## Executing Rate Updates

### Single Rate Update

While possible, single rate updates are executed the same way as batch updates, just with a single change.

Example structure:
```solidity
ParamChange[] updates = [
    ParamChange({
        id: "ETH-A",
        bps: 500  // 5.00%
    })
];
```

### Batch Updates

When updating multiple rates at once:
1. Updates MUST be ordered alphabetically by ID
2. Each update must respect its configured constraints
3. All updates in the batch are executed or none are (atomic)

Example of properly ordered batch update:
```solidity
ParamChange[] updates = [
    ParamChange({
        id: "DSR",
        bps: 400  // 4.00%
    }),
    ParamChange({
        id: "ETH-A",
        bps: 500  // 5.00%
    }),
    ParamChange({
        id: "SSR",
        bps: 300  // 3.00%
    })
];
```

## Common Errors and Solutions

### "DSPC/too-early"
- **Cause**: Attempting to update before the cooldown period (`tau`) has elapsed
- **Solution**: Wait until `tau` seconds have passed since the last update

### "DSPC/updates-out-of-order"
- **Cause**: Batch updates not ordered alphabetically
- **Solution**: Reorder your updates alphabetically by ID

### "DSPC/delta-above-step"
- **Cause**: Attempted rate change exceeds the maximum allowed step
- **Solution**: Break the change into multiple updates over time, each within the step limit

### "DSPC/below-min" or "DSPC/above-max"
- **Cause**: Proposed rate is outside the configured bounds
- **Solution**: Ensure your proposed rate is within the min-max range

## Best Practices

1. **Check Current Rates**: Before submitting updates, check current rates to ensure your changes are within step limits

2. **Verify Timing**: Confirm enough time has passed since the last update by checking the `toc` value

3. **Batch Efficiently**: When multiple rates need updates, batch them together to save gas and time, but remember:
   - Must be ordered alphabetically
   - All must respect their individual constraints
   - Must wait `tau` seconds since last update

4. **Emergency Situations**: If the contract is halted (`bad` = 1), no updates can be made until governance resolves the situation

## Rate Calculation Examples

### Example 1: Gradual Rate Increase
For a rate with `step = 100` (1%):
```
Current: 500 (5.00%)
Target:  800 (8.00%)

Required Updates:
1. 500 → 600 (wait tau)
2. 600 → 700 (wait tau)
3. 700 → 800
```

### Example 2: Multiple Rate Update
```
Current Rates:
DSR:   200 (2.00%)
ETH-A: 400 (4.00%)
SSR:   300 (3.00%)

Batch Update (must be ordered):
[
    {id: "DSR",   bps: 250},  // 2.50%
    {id: "ETH-A", bps: 450},  // 4.50%
    {id: "SSR",   bps: 350}   // 3.50%
]
``` 

# Testing

## Addresses on Sepolia

- DSPC: 0x4B5B12AC1bC588438Dcb08c28049e0956A589f0b
- ConvMock: 0x0C2302276fe7cF508bEBEcf45e5b1c33e26f85F1
- JUG: 0xc62B866a8faA6AEff8B73d55B6F73B64b74e4fAd
- Vat: 0xE938502439f4a4bdA4C7D6484c8B6b22C9Cd0042
- Safe: 0xe660384492b255C2b99E27e42E47Bc1CebfbAc47
