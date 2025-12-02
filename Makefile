# Makefile for DigitalTwinSharesV1
-include .env

.PHONY: help test test-gas build

help:
	@echo "DigitalTwinSharesV1 - Forge Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install          - Install dependencies"
	@echo "  make build           - Build contracts"
	@echo "  make test            - Run tests"
	@echo ""
	@echo "Interactions:"
	@echo "  make buy-first       - Buy first share (subject only)"
	@echo "  make check-price     - Check prices for shares"
	@echo "  make check-balance   - Check share balance"


install:
	forge install

build:
	forge build

test:
	forge test -vvv

test-gas:
	forge test --gas-report


deploy-bsc:
	@forge script script/DigitalTwinSharesV1.s.sol:DeployDigitalTwinSharesV1Script \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--with-gas-price 20000000000 \
		--priority-gas-price 2000000000 \
		-vvvv


check-buy-price:
	@echo "Enter subject address:"
	@read subject; \
	echo "Enter amount of shares:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "getBuyPrice(bytes16,uint256)" $$subject $$amount \
		--rpc-url $(BSC_RPC_URL) \
		-vvvv

check-sell-price:
	@echo "Enter subject address:"
	@read subject; \
	echo "Enter amount of shares:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "getSellPrice(bytes16,uint256)" $$subject $$amount \
		--rpc-url $(BSC_RPC_URL) \
		-vvvv

check-balance:
	@echo "Enter subject address:"
	@read subject; \
	echo "Enter holder address:"; \
	read holder; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "getBalance(bytes16,address)" $$subject $$holder \
		--rpc-url $(BSC_RPC_URL) \
		-v

buy-shares:
	@echo "Enter subject address:"
	@read subject; \
	echo "Enter amount of shares:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "buyShares(bytes16,uint256)" $$subject $$amount \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		-vvvv

sell-shares:
	@echo "Enter subject id:"
	@read subject; \
	echo "Enter amount of shares:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "sellShares(bytes16,uint256)" $$subject $$amount \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

create-digital-twin:
	@echo "Enter subject address:"
	@read subject; \
	echo "Enter url:"; \
	read url; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "createDigitalTwin(bytes16,string)" $$subject $$url \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		-vvvv

set-min-shares-to-create:
	@echo "Enter min shares to create:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "setMinSharesToCreate(uint256)" $$amount \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

set-token-uri:
	@echo "Enter subject address:"; \
	read subject; \
	echo "Enter token uri:"; \
	read url; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "setTokenUri(bytes16,string)" $$subject $$url \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		-vvvv

grant-claim-ownership-role:
	@echo "Enter new owner address:"; \
	read newOwner; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "grantClaimOwnershipRole(address)" $$newOwner \
		--private-key $(PRIVATE_KEY) \
		--rpc-url $(BSC_RPC_URL) \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		--broadcast \
		-vvvv

revoke-claim-ownership-role:
	@echo "Enter new owner address:"; \
	read newOwner; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "revokeClaimOwnershipRole(address)" $$newOwner \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		--broadcast \
		-vvvv

claim-ownership-admin:
	@echo "Enter digital twin id:"; \
	read digitalTwinId; \
	echo "Enter new owner address:"; \
	read newOwner; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "claimOwnershipAdmin(bytes16,address)" $$digitalTwinId $$newOwner \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--with-gas-price 10000000000 \
		--priority-gas-price 10000000000 \
		--broadcast \
		-vvvv

set-protocol-fee-percent:
	@echo "Enter protocol fee percent:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "setProtocolFeePercent(uint256)" $$amount \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

set-subject-fee-percent:
	@echo "Enter subject fee percent:"; \
	read amount; \
	forge script script/DigitalTwinSharesV1.s.sol:InteractDigitalTwinSharesV1 \
		--sig "setSubjectFeePercent(uint256)" $$amount \
		--rpc-url $(BSC_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		-vvvv

clean:
	forge clean

format:
	forge fmt