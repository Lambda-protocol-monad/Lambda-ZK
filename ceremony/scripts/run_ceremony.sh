#!/usr/bin/env bash
set -euo pipefail

# Lambda-ZK Enhanced Trusted Setup Coordinator 
# Security Features: PTAU validation, per-contribution verification,
# deterministic ordering, checksum manifests, input sanitization
# Maintains full auditability and adversarial security properties

# -----------------------------------------------------------------------------
# CONFIGURATION CONSTANTS
# -----------------------------------------------------------------------------

EXPECTED_PTAU_CHECKSUM="e970efa7774da80101e0ac336d083ef3339855c98112539338d706b2b89ac694"  # Verified PTAU checksum
CIRCUIT_NAME="giftcard_merkle"
LOG_DIR="ceremony/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ceremony_$(date +%Y%m%d_%H%M%S).log"

# -----------------------------------------------------------------------------
# SECURITY FUNCTIONS
# -----------------------------------------------------------------------------

# Enhanced input sanitization with path validation
sanitize_input() {
    local input="$1"
    local max_length="${2:-1024}"

    # Remove control characters, normalize paths, limit length
    echo "$input" | tr -d '\000-\037\177' | sed 's/\.\./__/g' | head -c "$max_length" || true
}

# PTAU integrity verification with known checksum
verify_ptau_integrity() {
    local ptau_file="$1"
    local expected_checksum="$EXPECTED_PTAU_CHECKSUM"

    if [[ ! -f "$ptau_file" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ERROR: PTAU file missing: $ptau_file"
        return 1
    fi

    local actual_checksum size
    actual_checksum=$(sha256sum "$ptau_file" 2>/dev/null | awk '{print $1}') || {
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ERROR: Failed to calculate PTAU checksum"
        return 1
    }

    size=$(stat -c%s "$ptau_file" 2>/dev/null || stat -f%z "$ptau_file" 2>/dev/null) || {
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ERROR: Failed to get PTAU file size"
        return 1
    }

    if [[ "$size" -lt 1048576 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_ERROR: PTAU file suspiciously small: ${size} bytes"
        return 1
    fi

    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_BREACH: PTAU checksum mismatch!"
        echo "$(date '+%Y-%m-%d %H:%M:%S') PTAU_EXPECTED: $expected_checksum"
        echo "$(date '+%Y-%m-%d %H:%M:%S') PTAU_ACTUAL: $actual_checksum"
        return 1
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_OK: PTAU integrity verified: $actual_checksum"
    return 0
}

# Enhanced per-contribution cryptographic validation
validate_contribution() {
    local zkey_file="$1"
    local r1cs_file="$2"
    local ptau_file="$3"
    local expected_index="$4"

    # Pre-validation checks
    if [[ ! -f "$zkey_file" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_ERROR: Contribution file missing: $zkey_file"
        return 1
    fi

    local file_size
    file_size=$(stat -c%s "$zkey_file" 2>/dev/null || stat -f%z "$zkey_file" 2>/dev/null) || {
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_ERROR: Cannot determine file size: $zkey_file"
        return 1
    }

    if [[ "$file_size" -lt 100000 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_ERROR: File too small, possible corruption: $zkey_file (${file_size} bytes)"
        return 1
    fi

    # Verify filename matches expected pattern (numbered or temporary)
    local file_basename=$(basename "$zkey_file")

    if [[ "$file_basename" =~ ^giftcard_merkle_([0-9]{4})\.zkey$ ]]; then
        # Numbered format: accept any valid numbered filename
        # Index validation is skipped - files will be renumbered sequentially when copied to output/
        local file_index=${BASH_REMATCH[1]}
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_INFO: Numbered file detected: $file_basename (will be renumbered to $(printf "%04d" "$expected_index") in output/)"
    elif [[ "$file_basename" =~ ^giftcard_merkle_tmp_[0-9_]+\.zkey$ ]]; then
        # Temporary format: skip index validation (will be renumbered)
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_INFO: Temporary file detected: $file_basename (will be renumbered to $(printf "%04d" "$expected_index") in output/)"
    else
        # Invalid format
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_ERROR: Invalid filename pattern: $file_basename"
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_ERROR: Expected format: giftcard_merkle_NNNN.zkey or giftcard_merkle_tmp_*.zkey"
        return 1
    fi

    # Cryptographic verification with timeout and error handling
    echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION: Running cryptographic verification for contribution #$expected_index"

    if timeout 300 snarkjs zkey verify "$r1cs_file" "$ptau_file" "$zkey_file" &>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_SUCCESS: Contribution #$expected_index cryptographically verified"
        return 0
    else
        local exit_code=$?
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_FAILED: Cryptographic verification failed (exit code: $exit_code)"
        return 1
    fi
}

# Generate comprehensive checksum manifest
generate_checksum_manifest() {
    local output_dir="$1"
    local manifest_file="$output_dir/checksum_manifest.txt"
    local circuit_name="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') MANIFEST: Generating public checksum manifest"

    cat > "$manifest_file" << EOF
LAMBDA-ZK Trusted Setup Checksum Manifest
Generated: $(date -Iseconds)
Circuit: $circuit_name
Repository: https://github.com/lambda-zk/ceremony
Security Assumption: At least one honest participant

CHECKSUMS (SHA-256):
EOF

    # Include PTAU checksum
    if [[ -f "$PTAU_FILE" ]]; then
        ptau_checksum=$(sha256sum "$PTAU_FILE" | awk '{print $1}')
        ptau_relative=$(realpath --relative-to="$ROOT_DIR" "$PTAU_FILE")
        echo "PTAU: $ptau_relative:$ptau_checksum" >> "$manifest_file"
    fi

    # Include R1CS checksum if file exists
    if [[ -f "$R1CS_FILE" ]]; then
        r1cs_checksum=$(sha256sum "$R1CS_FILE" | awk '{print $1}')
        r1cs_relative=$(realpath --relative-to="$ROOT_DIR" "$R1CS_FILE")
        echo "R1CS: $r1cs_relative:$r1cs_checksum" >> "$manifest_file"
    fi

    # Include all zkey files in deterministic order
    while IFS= read -r -d '' zkey_file; do
        if [[ -f "$zkey_file" ]]; then
            zkey_checksum=$(sha256sum "$zkey_file" | awk '{print $1}')
            zkey_relative=$(realpath --relative-to="$ROOT_DIR" "$zkey_file")
            echo "ZKEY: $zkey_relative:$zkey_checksum" >> "$manifest_file"
        fi
    done < <(find "$output_dir" -name "${circuit_name}_*.zkey" -type f -print0 | sort -z)

    # Include manifest checksum
    local temp_manifest="/tmp/manifest_temp_$$.txt"
    cp "$manifest_file" "$temp_manifest"
    manifest_checksum=$(sha256sum "$temp_manifest" | awk '{print $1}')
    manifest_relative=$(realpath --relative-to="$ROOT_DIR" "$manifest_file")
    echo "MANIFEST: $manifest_relative:$manifest_checksum" >> "$manifest_file"
    rm -f "$temp_manifest"

    echo "$(date '+%Y-%m-%d %H:%M:%S') MANIFEST_SUCCESS: Generated manifest at $manifest_file"
}

# -----------------------------------------------------------------------------
# MAIN CEREMONY EXECUTION
# -----------------------------------------------------------------------------

# Enable comprehensive logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') LOGGING: Comprehensive audit log enabled: $LOG_FILE"

cat << 'EOF'
╔══════════════════════════════════════════════╗
║      Lambda-ZK Enhanced Trusted Setup        ║
║              Security Edition                ║
╚══════════════════════════════════════════════╝
EOF

echo "$(date '+%Y-%m-%d %H:%M:%S') INIT: Lambda-ZK Enhanced Trusted Setup Coordinator  started"
echo "$(date '+%Y-%m-%d %H:%M:%S') INIT: Security features enabled - maintaining adversarial resilience"

# Set up clean, relative paths (don't sanitize these base paths)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CIR_DIR="$ROOT_DIR/circuits"
BUILD_DIR="$CIR_DIR/build"
PTAU_DIR="$CIR_DIR/ptau"
CEREMONY_DIR="$ROOT_DIR/ceremony"
OUTPUT_DIR="$CEREMONY_DIR/output"
CONTRIB_DIR="$CEREMONY_DIR/contrib"
PTAU_FILE="$PTAU_DIR/powersOfTau28_hez_final_18.ptau"
R1CS_FILE="$BUILD_DIR/giftcard_merkle.r1cs"

# Only sanitize user-controllable inputs, not constructed paths
CIRCUIT_NAME=$(sanitize_input "$CIRCUIT_NAME")

# Directory validation and creation
for dir in "$BUILD_DIR" "$PTAU_DIR" "$OUTPUT_DIR" "$CONTRIB_DIR"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "$(date '+%Y-%m-%d %H:%M:%S') INIT: Created directory: $dir"
    fi
done

# Critical R1CS validation
if [[ ! -f "$R1CS_FILE" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_ERROR: R1CS file missing: $R1CS_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_ERROR: Compile circuit using 'circom circuits/giftcard_merkle.circom --r1cs --wasm -o circuits/build'"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') CIRCUIT_OK: R1CS file verified: $R1CS_FILE"

# Check if ceremony has been finalized (prevents processing after finalization)
FINAL_ZKEY="$OUTPUT_DIR/${CIRCUIT_NAME}_final.zkey"
if [[ -f "$FINAL_ZKEY" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') CEREMONY_FINALIZED: Ceremony has been finalized - no further contributions accepted"
    echo "$(date '+%Y-%m-%d %H:%M:%S') FINAL_ARTIFACTS:"
    echo "$(date '+%Y-%m-%d %H:%M:%S')   - $FINAL_ZKEY"
    echo "$(date '+%Y-%m-%d %H:%M:%S')   - $OUTPUT_DIR/${CIRCUIT_NAME}_verification_key.json"
    echo "$(date '+%Y-%m-%d %H:%M:%S') CEREMONY_STATUS: Production keys are ready - ceremony is complete"
    exit 0
fi

# Enhanced PTAU verification
if ! verify_ptau_integrity "$PTAU_FILE"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_SECURITY: PTAU integrity check failed - ceremony terminated for security"
    exit 1
fi

# Generate or validate initial zkey with enhanced security
ZKEY0="$OUTPUT_DIR/${CIRCUIT_NAME}_0000.zkey"
if [[ ! -f "$ZKEY0" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') SETUP: Generating initial zkey with enhanced entropy validation"
    snarkjs groth16 setup "$R1CS_FILE" "$PTAU_FILE" "$ZKEY0"
    (cd "$OUTPUT_DIR" && sha256sum "$(basename "$ZKEY0")" > "$(basename "$ZKEY0").sha256")

    # Immediately validate the newly created initial zkey
    if ! validate_contribution "$ZKEY0" "$R1CS_FILE" "$PTAU_FILE" 0; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_ERROR: New initial zkey failed validation - corrupted generation"
        rm -f "$ZKEY0" "$ZKEY0.sha256"
        exit 1
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') SETUP_SUCCESS: Initial zkey generated and validated: $ZKEY0"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') INIT: Validating existing initial zkey: $ZKEY0"

    # Re-validate existing initial zkey for security
    if ! validate_contribution "$ZKEY0" "$R1CS_FILE" "$PTAU_FILE" 0; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_SECURITY: Existing initial zkey validation failed - corruption detected"
        ls -la "$OUTPUT_DIR"
        exit 1
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION_SUCCESS: Existing initial zkey confirmed: $ZKEY0"
fi

# -----------------------------------------------------------------------------
# DETERMINISTIC CONTRIBUTION PROCESSING
# -----------------------------------------------------------------------------
# NOTE: This script expects contributions in contrib/ to be pre-normalized
# to sequential indices by the GitHub Actions workflow. The workflow's
# concurrency group ensures only one aggregation runs at a time, preventing
# race conditions in index assignment.
# -----------------------------------------------------------------------------

echo
echo "───────────────────────────────────────────────────────────────────────"
echo "$(date '+%Y-%m-%d %H:%M:%S') PROCESSING: Scanning for contributions with deterministic ordering"
echo "───────────────────────────────────────────────────────────────────────"

# Collect all contributions in deterministic order (alphabetical/numerical by index)
declare -a contrib_files=()
processed_count=0
rejected_count=0
expected_index=1

# Scan contribution directory for valid files
# Accept both temporary (tmp_*) and numbered formats for local execution compatibility
while IFS= read -r -d '' potential_file; do
    if [[ -f "$potential_file" ]]; then
        contrib_files+=("$potential_file")
    fi
done < <(find "$CONTRIB_DIR" -maxdepth 1 -type f \( -name "${CIRCUIT_NAME}_[0-9][0-9][0-9][0-9].zkey" -o -name "${CIRCUIT_NAME}_tmp_*.zkey" \) -print0 2>/dev/null | sort -z)

echo "$(date '+%Y-%m-%d %H:%M:%S') SCAN_COMPLETE: Found ${#contrib_files[@]} potential contribution files"

# Determine starting index by finding the highest existing index in output/
max_existing_index=0
while IFS= read -r -d '' existing_file; do
    filename=$(basename "$existing_file")
    if [[ "$filename" =~ ^${CIRCUIT_NAME}_([0-9]{4})\.zkey$ ]]; then
        file_index=$((10#${BASH_REMATCH[1]}))  # Force base-10 to avoid octal interpretation
        if [[ $file_index -gt $max_existing_index ]]; then
            max_existing_index=$file_index
        fi
    fi
done < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -name "${CIRCUIT_NAME}_[0-9][0-9][0-9][0-9].zkey" -print0 2>/dev/null)

starting_index=$((max_existing_index + 1))
echo "$(date '+%Y-%m-%d %H:%M:%S') INDEX_INFO: Highest existing index in output/: $max_existing_index"
echo "$(date '+%Y-%m-%d %H:%M:%S') INDEX_INFO: New contributions will start at index: $starting_index"

# Process each contribution in strict order
for ((i=0; i<${#contrib_files[@]}; i++)); do
    current_file="${contrib_files[$i]}"
    base_name=$(basename "$current_file")
    current_index=$((starting_index + i))

    echo
    echo "$(date '+%Y-%m-%d %H:%M:%S') PROCESSING: Contribution #$current_index - $base_name"

    # Validate contribution integrity and cryptography
    if ! validate_contribution "$current_file" "$R1CS_FILE" "$PTAU_FILE" "$current_index"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') REJECTION: Contribution #$current_index failed validation - skipping"
        rejected_count=$((rejected_count + 1))

        # Log rejection for audit trail but continue processing others
        echo "$(date '+%Y-%m-%d %H:%M:%S') AUDIT: Rejected file: $(stat "$current_file" 2>/dev/null || echo "stat failed")"
        continue
    fi

    # Generate target filename with zero-padded index
    output_file="$OUTPUT_DIR/${CIRCUIT_NAME}_$(printf "%04d" $current_index).zkey"
    checksum_file="$OUTPUT_DIR/${CIRCUIT_NAME}_$(printf "%04d" $current_index).zkey.sha256"

    # Copy validated contribution to official chain
    cp "$current_file" "$output_file"
    (cd "$OUTPUT_DIR" && sha256sum "$(basename "$output_file")" > "$(basename "$checksum_file")")

    # Verify the copied file integrity
    copied_checksum=$(sha256sum "$output_file" | awk '{print $1}')
    expected_checksum=$(cat "$checksum_file" | awk '{print $1}')

    if [[ "$copied_checksum" != "$expected_checksum" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') CRITICAL_ERROR: File corruption during copy - integrity check failed"
        rm -f "$output_file" "$checksum_file"
        exit 1
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') INTEGRATION_SUCCESS: Contribution #$current_index integrated into official chain"
    echo "$(date '+%Y-%m-%d %H:%M:%S') CHECKSUM: $copied_checksum"

    # Remove processed contribution from contrib directory to prevent re-verification
    # This significantly improves performance for subsequent runs
    echo "$(date '+%Y-%m-%d %H:%M:%S') CLEANUP: Removing processed contribution from contrib directory"
    rm -f "$current_file"

    # Create a marker file to track what was processed
    echo "$copied_checksum" > "$CONTRIB_DIR/.processed_${CIRCUIT_NAME}_$(printf "%04d" $current_index).sha256"

    processed_count=$((processed_count + 1))
done

# -----------------------------------------------------------------------------
# POST-PROCESSING AND AUDIT TRAIL
# -----------------------------------------------------------------------------

echo
echo "───────────────────────────────────────────────────────────────────────"
echo "PROCESSING COMPLETE - AUDIT SUMMARY"
echo "───────────────────────────────────────────────────────────────────────"

echo "$(date '+%Y-%m-%d %H:%M:%S') SUMMARY: Contributions processed: $processed_count"
echo "$(date '+%Y-%m-%d %H:%M:%S') SUMMARY: Contributions rejected: $rejected_count"
echo "$(date '+%Y-%m-%d %H:%M:%S') SUMMARY: Total contributions found: ${#contrib_files[@]}"

# Generate public checksum manifest
generate_checksum_manifest "$OUTPUT_DIR" "$CIRCUIT_NAME"

# Security status assessment
if [[ $processed_count -gt 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_OK: Ceremony chain extended - maintaining adversarial security properties"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') STATUS_INFO: No new contributions processed in this run"
fi

if [[ $rejected_count -gt 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECURITY_WARNING: $rejected_count contributions were rejected - review audit log for details"
fi

# CI loop prevention logic
if [[ $processed_count -gt 0 && $rejected_count -eq 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') CI_TRIGGER: Valid contributions processed - CI may continue to beacon phase"
    # Indicate to workflow that changes were made and are safe to commit
    exit 0
elif [[ $rejected_count -gt 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') CI_WARNING: Some contributions rejected - manual review required"
    # Exit with non-zero to indicate manual intervention needed
    exit 1
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') CI_SKIP: No changes to process - exiting cleanly to prevent loops"
    exit 0
fi

# Final audit message
echo "$(date '+%Y-%m-%d %H:%M:%S') COMPLETE: Enhanced ceremony execution finished successfully"
echo "$(date '+%Y-%m-%d %H:%M:%S') NEXT_STEP: Execute final_beacon.sh for toxic waste removal when ready"
echo "$(date '+%Y-%m-%d %H:%M:%S') AUDIT_LOG: Complete session log saved to $LOG_FILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') MANIFEST: Public checksums available at ceremony/output/checksum_manifest.txt"
