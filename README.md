## Installation and Build
```shell
git submodule update --init --recursive
forge build
```

## Deployment

###  1. Adding configuration

create `.env` similar to `.env.example`

### 2. Run deployment script

#### Deploy on Goerli testnet

```shell

# load .env file
source .env

# run
forge script script/deploy-distributor.s.sol:DeployDistributor --rpc-url goerli --broadcast --verify -vvvv
```

#### Deploy locally

If you want to deploy to other networks, you will need to add a config similar to `goerli` in `foundry.toml`