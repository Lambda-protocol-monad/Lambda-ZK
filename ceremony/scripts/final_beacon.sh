#!/usr/bin/env bash
set -euo pipefail

CIRCUIT_NAME="giftcard_merkle"
ROOT_DIR="$(cd "$(dirname "$0")/../../" && pwd)"
OUT="$ROOT_DIR/ceremony/output"
R1CS="$ROOT_DIR/circuits/build/${CIRCUIT_NAME}.r1cs"
PTAU="$ROOT_DIR/circuits/ptau/powersOfTau28_hez_final_18.ptau"

# -----------------------------
# Input: precommitted drand round
# -----------------------------
DRAND_ROUND="${1:-}"
if [ -z "$DRAND_ROUND" ] || ! [[ "$DRAND_ROUND" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <drand_round>" >&2
  exit 1
fi

FINAL_ZKEY="$OUT/${CIRCUIT_NAME}_final.zkey"
FINAL_VKEY="$OUT/${CIRCUIT_NAME}_verification_key.json"

# -----------------------------
# Idempotency
# -----------------------------
if [ -f "$FINAL_ZKEY" ]; then
  echo "✅ Final zkey already exists at: $FINAL_ZKEY"
  exit 0
fi

# -----------------------------
# Preconditions
# -----------------------------
mkdir -p "$OUT"

[ -f "$R1CS" ] || { echo "Missing R1CS"; exit 1; }
[ -f "$PTAU" ] || { echo "Missing PTAU"; exit 1; }

LAST_ZKEY="$(ls "$OUT"/${CIRCUIT_NAME}_*.zkey 2>/dev/null | grep -v "_final.zkey" | sort | tail -n 1 || true)"
[ -n "$LAST_ZKEY" ] || { echo "No intermediate zkey found"; exit 1; }

echo "Using last chain zkey: $LAST_ZKEY"

# -----------------------------
# Fetch drand randomness (STREAM SAFE)
# -----------------------------
DRAND_URL="https://api.drand.sh/public/${DRAND_ROUND}"
echo "Fetching public randomness from drand round ${DRAND_ROUND}..."

set +e
RANDOMNESS="$(
  curl -sS -L \
    --retry 5 --retry-all-errors --retry-delay 2 \
    --connect-timeout 10 --max-time 20 \
    "$DRAND_URL" \
  | jq -r '.randomness // empty'
)"
CURL_RC=$?
set -e

if [ $CURL_RC -ne 0 ] || [ -z "$RANDOMNESS" ]; then
  echo "ℹ️ Drand round not available yet or transient error."
  echo "No-op; retry later."
  exit 0
fi

echo "drand randomness (hex): $RANDOMNESS"

# -----------------------------
# Derive beacon
# -----------------------------
BEACON_HASH="$(echo -n "$RANDOMNESS" | sha256sum | cut -d' ' -f1)"
echo "Derived beacon hash: $BEACON_HASH"

# -----------------------------
# Apply beacon
# -----------------------------
echo "Running snarkjs zkey beacon..."
snarkjs zkey beacon "$LAST_ZKEY" "$FINAL_ZKEY" "$BEACON_HASH" 10

sha256sum "$FINAL_ZKEY" > "$FINAL_ZKEY.sha256"

echo "Verifying final zkey..."
snarkjs zkey verify "$R1CS" "$PTAU" "$FINAL_ZKEY"

echo "Exporting verification key..."
snarkjs zkey export verificationkey "$FINAL_ZKEY" "$FINAL_VKEY"
sha256sum "$FINAL_VKEY" > "$FINAL_VKEY.sha256"

echo "✅ Final beacon completed successfully."
