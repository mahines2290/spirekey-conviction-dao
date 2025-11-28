#!/bin/bash
# Deploy to Kadena testnet chain 1
kadence deploy pact/spirekey-dao-voting-v1.pact \
  --network testnet04 \
  --chain 1 \
  --sender your-wallet-account.k:1 \
  --gas-limit 2500 \
  --gas-price 0.00000001
echo "Deployed! Check tx hash above."