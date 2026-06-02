#!/usr/bin/env bash
# gen-secrets.sh — mint random secrets for personas / infrastructure.
# Prints to stdout only; never writes a file. Copy values into the right .env by hand.
#
#   ./scripts/gen-secrets.sh                 # a full set for one persona + infra
#   ./scripts/gen-secrets.sh token           # one 32-byte hex token
#   ./scripts/gen-secrets.sh 48              # one N-byte hex secret
set -euo pipefail

gen() { openssl rand -hex "${1:-32}"; }

case "${1:-all}" in
  all)
    echo "# --- per-persona (into ~/voip-<name>/.env) ---"
    echo "API_TOKEN=$(gen 32)"
    echo "MATRIX_CRYPTO_STORE_PASSWORD=$(gen 24)"
    echo "# --- infrastructure (into compose ./.env and turnserver.conf) ---"
    echo "POSTGRES_PASSWORD=$(gen 24)"
    echo "TURN_STATIC_AUTH_SECRET=$(gen 32)   # use the SAME value in Dendrite client_api.turn"
    ;;
  token) gen 32 ;;
  [0-9]*) gen "$1" ;;
  *) echo "usage: $0 [all|token|<bytes>]" >&2; exit 2 ;;
esac
