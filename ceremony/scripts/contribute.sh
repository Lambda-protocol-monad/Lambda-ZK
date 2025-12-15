#!/usr/bin/env bash
set -euo pipefail

cat << 'EOF'
 _        _    __  __ ____  ____    _        ______  __
| |      / \  |  \/  | __ )|  _ \  / \      |__  / |/ /
| |     / _ \ | |\/| |  _ \| | | |/ _ \ _____ / /| ' / 
| |___ / ___ \| |  | | |_) | |_| / ___ \_____/ /_| . \ 
|_____/_/   \_\_|  |_|____/|____/_/   \_\   /____|_|\_\
                                                       
EOF

echo "$(date '+%Y-%m-%d %H:%M:%S') ⓘ Lambda-ZK Ceremony Contributor initialized"
echo

CIRCUIT_NAME="giftcard_merkle"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/ceremony/output"
CONTRIB_DIR="$ROOT_DIR/ceremony/contrib"

mkdir -p "$CONTRIB_DIR"

# Verify snarkjs installation
if ! command -v snarkjs >/dev/null 2>&1; then
  echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[31m✗ ERROR:\e[0m snarkjs not found. Install with: \e[96mnpm install -g snarkjs\e[0m"
  echo
  exit 1
fi

echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[94mⓘ INFO:\e[0m Circuit: \e[96m$CIRCUIT_NAME\e[0m"
echo -e "\e[38;5;8m            \e[0m \e[94m      Output directory:\e[0m \e[33m$OUTPUT_DIR\e[0m"
echo -e "\e[38;5;8m            \e[0m \e[94m      Contribution directory:\e[0m \e[33m$CONTRIB_DIR\e[0m"
echo

# Find latest zkey in ceremony/output
shopt -s nullglob
zkeys=( "$OUTPUT_DIR"/${CIRCUIT_NAME}_*.zkey )
shopt -u nullglob

if [ ${#zkeys[@]} -eq 0 ]; then
  echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[31m✗ ERROR:\e[0m No zkeys found in $OUTPUT_DIR"
  echo -e "\e[38;5;8m            \e[0m \e[31m  Coordinator must generate and commit ${CIRCUIT_NAME}_0000.zkey first.\e[0m"
  echo
  exit 1
fi

# Sort and take last one (highest index)
IFS=$'\n' sorted=($(printf '%s\n' "${zkeys[@]}" | sort))
LAST_ZKEY="${sorted[-1]}"

# Generate a temporary unique index using timestamp
# The GitHub Actions workflow will renumber this to the correct sequential index
# This prevents race conditions when multiple contributors are working simultaneously
TEMP_INDEX=$(date +%s%N | tail -c 8)  # Last 8 digits of nanosecond timestamp
OUTPUT_ZKEY="$CONTRIB_DIR/${CIRCUIT_NAME}_tmp_${TEMP_INDEX}.zkey"

echo "Ceremony configuration:"
echo ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[94mⓘ INFO:\e[0m Latest chain zkey: \e[33m$LAST_ZKEY\e[0m"
echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[94mⓘ INFO:\e[0m Your contribution (temporary name): \e[33m$OUTPUT_ZKEY\e[0m"
echo -e "\e[38;5;8m            \e[0m \e[94m      (The workflow will assign the final index automatically)\e[0m"
echo

read -rp "Enter your identity (leave empty for Anonymous): " NAME
NAME=${NAME:-Anonymous}

echo
echo "Generating contribution..."
echo ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[94mⓘ INFO:\e[0m Executing contribution as \"\e[96m$NAME\e[0m\"..."
snarkjs zkey contribute "$LAST_ZKEY" "$OUTPUT_ZKEY" \
  --name="$NAME" \
  --entropy="$(openssl rand -hex 32)"

echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[32m✓ SUCCESS:\e[0m Contribution executed successfully"
sha256sum "$OUTPUT_ZKEY"

echo
echo ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
echo -e "\e[38;5;8m$(date '+%Y-%m-%d %H:%M:%S')\e[0m \e[94mⓘ INFO:\e[0m Submit the file \e[33m$OUTPUT_ZKEY\e[0m via Pull Request or direct commit."
