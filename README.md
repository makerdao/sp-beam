# Stability Parameter Bounded External Access Module (SP-BEAM)

A module for the Sky Protocol that enables direct changes to stability parameters (duty, dsr, ssr) through a simple, secure interface with proper constraints and timelocks.

## Overview

The SP-BEAM module provides a streamlined way to modify stability parameters in the Maker Protocol, including:
- Stability fees (duty) for different collateral types via the Jug contract
- Dai Savings Rate (DSR) via the Pot contract
- Sky Savings Rate (SSR) via the sUSDS contract

## Features

- Batch updates for multiple rate changes
- Two-level access control:
  - Admins can configure the module
  - Facilitators can propose and execute rate changes
- Rate change constraints:
  - Min/max caps per rate
  - Max update delta
- Event emission for all actions
- Simple, auditable implementation

## Installation

```bash
forge install
```

## Testing

```bash
forge test
```

## Usage

1. Deploy the contract with the required addresses:
```solidity
SPBEAM beam = new SPBEAM(
    jugAddress,  // For stability fees
    potAddress,  // For DSR
    susdsAddress, // For SSR
    convAddress  // For rate conversions
);
```

2. Configure the module parameters:
```solidity
// Set timelock duration
beam.file("tau", 1 days);

// Configure constraints for a collateral type
beam.file("ETH-A", "max", 1000);  // Max rate: 10%
beam.file("ETH-A", "min", 1);     // Min rate: 0.01%
beam.file("ETH-A", "step", 100);  // Max change: 1%

// Configure constraints for DSR
beam.file("DSR", "max", 800);  // Max rate: 8%
beam.file("DSR", "min", 1);    // Min rate: 0.01%
beam.file("DSR", "step", 100); // Max change: 1%
```

3. Add facilitators who can propose and execute rate changes:
```solidity
beam.kiss(facilitatorAddress);
```

4. Execute a batch of rate changes:
```solidity
SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](2);
updates[0] = SPBEAM.ParamChange("DSR", 75);     // Set DSR to 0.75%
updates[1] = SPBEAM.ParamChange("ETH-A", 150);  // Set ETH-A rate to 1.5%
beam.set(updates);
```

## Security

The module implements a robust security model:
- Two-level access control (admins and facilitators)
- Rate constraints to prevent extreme changes
- Disabling without GSM delay via SPBEAMMom contract
- Circuit breaker (halt) functionality
- All actions emit events for transparency
- Batch updates must be ordered alphabetically by ID to prevent duplicates

## License

AGPL-3.0-or-later
