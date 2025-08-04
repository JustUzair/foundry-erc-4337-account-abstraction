SHELL := /bin/bash

# Makefile

.PHONY: install build deploy dd

install:
	@echo "Installing dependencies..."
	forge install

build:
	@echo "Building project..."
	forge build


deploy-sourcify:
	forge script script/DeployMinimal.s.sol --rpc-url buildbear --verifier sourcify --verify --verifier-url https://rpc.buildbear.io/verify/sourcify/server/sandbox-id --broadcast

deploy-etherscan:
	forge script script/DeployMinimal.s.sol --rpc-url buildbear --etherscan-api-key "verifyContract" --verifier-url "https://rpc.buildbear.io/verify/etherscan/sandbox-id" --broadcast --verify

# /*
# Etherscan - after contract deployment
# forge verify-contract --flatten --watch --constructor-args $(cast abi-encode "constructor(address,address)" "0xD5f930f156541e33F7d8b83da6ad84B4B1775aAc" "0x0000000071727De22E5E9d8BAf0edAc6f37da032") 0x0b781184693288d0Db306ebF41C5Aee82d56D752 MinimalAccount --etherscan-api-key "verifyContract" --verifier-url "https://rpc.buildbear.io/verify/etherscan/sandbox-id" 
# */

# /*
# forge verify-contract --flatten --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xD5f930f156541e33F7d8b83da6ad84B4B1775aAc 0x0000000071727De22E5E9d8BAf0edAc6f37da032) 0x0b781184693288d0Db306ebF41C5Aee82d56D752 MinimalAccount --verifier sourcify --verifier-url  https://rpc.buildbear.io/verify/sourcify/server/sandbox-id
# */
