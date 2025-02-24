#!/usr/bin/env bash

source .env

echo "Deploying UmaCtfAdapter..."

echo "Deploy args:
ADMIN: $ADMIN
ConditionalTokensFramework: $CTF
OptimisticOracleV2: $OO
AddressWhitelist: $WL
"

OUTPUT="$(forge script Deploy \
    --private-key $PK \
    --rpc-url $RPC_URL \
    --json \
    --broadcast \
    -s "deploy(address,address,address,address)" $ADMIN $CTF $OO $WL)"

ORACLE=$(echo "$OUTPUT" | grep "{" | jq -r .returns.oracle.value)
echo "Oracle deployed: $ORACLE"

echo "Complete!"
