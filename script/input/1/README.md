# Network 1 (Ethereum Mainnet) Deployment Configuration

This directory contains the configuration files for deploying SPBEAM on Ethereum Mainnet.

## Files

### spbeam-deploy.json
Configuration for deploying SPBEAM and SPBEAMMom contracts:
- `conv`: Address of the converter contract that handles rate conversions between basis points and ray format

## Usage

1. Copy `template-spbeam-deploy.json` into a new file (i.e.: `spbeam-deploy.json`)
2. Edit the new file with the correct `conv` address
3. Run the deployment script:
```bash
FOUNDRY_SCRIPT_CONFIG=spbeam-deploy forge script script/SPBEAMDeploy.s.sol:SPBEAMDeployScript \
    --rpc-url $ETH_RPC_URL \
    --broadcast

The deployment script will:
1. Load system addresses from chainlog (jug, pot, susds)
2. Deploy SPBEAM and SPBEAMMom contracts
4. Export addresses to `/script/output/1/spbeam-deploy.json`
