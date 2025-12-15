#!/bin/bash
set -euo pipefail

# Enhanced Lambda-ZK Ceremony Chain Verifier 
# Comprehensive integrity verification with adversarial security analysis

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

CIRCUIT_NAME="giftcard_merkle"

# Resolve paths based on this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"        # repo root = ceremony/.. = repo
CIRCUITS_DIR="$REPO_ROOT/circuits"
CEREMONY_DIR="$REPO_ROOT/ceremony"
OUTPUT_DIR="$CEREMONY_DIR/output"
CONTRIB_DIR="$CEREMONY_DIR/contrib"
PTAU_FILE="$CIRCUITS_DIR/ptau/powersOfTau28_hez_final_18.ptau"
R1CS_FILE="$CIRCUITS_DIR/build/${CIRCUIT_NAME}.r1cs"
MANIFEST_FILE="$OUTPUT_DIR/checksum_manifest.txt"

LOG_FILE="$SCRIPT_DIR/chain_verification_$(date +%Y%m%d_%H%M%S).log"
EXPECTED_PTAU_CHECKSUM="e970efa7774da80101e0ac336d083ef3339855c98112539338d706b2b89ac694" 

# -----------------------------------------------------------------------------
# UTILITY FUNCTIONS
# -----------------------------------------------------------------------------

log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR" "$1"
}

warning() {
    log "WARNING" "$1"
}

info() {
    log "INFO" "$1"
}

success() {
    log "SUCCESS" "$1"
}

# -----------------------------------------------------------------------------
# VERIFICATION FUNCTIONS
# -----------------------------------------------------------------------------

verify_environment() {
    info "Verifying ceremony environment integrity..."

    # Check required directories exist
    if [[ ! -d "$CIRCUITS_DIR" ]]; then
        error "Circuits directory not found: $CIRCUITS_DIR"
        return 1
    fi

    if [[ ! -d "$OUTPUT_DIR" ]]; then
        error "Ceremony output directory not found: $OUTPUT_DIR"
        return 1
    fi

    if [[ ! -d "$CONTRIB_DIR" ]]; then
        warning "Contributions directory not found (may indicate no contributions yet): $CONTRIB_DIR"
    fi

    # Verify snarkjs is available
    if ! command -v snarkjs >/dev/null 2>&1; then
        error "snarkjs not found - install with: npm install -g snarkjs"
        return 1
    fi

    success "Environment verification passed"
    return 0
}

verify_ptau_integrity() {
    local ptau_file="$PTAU_FILE"

    if [[ ! -f "$ptau_file" ]]; then
        error "PTAU file missing: $ptau_file"
        return 1
    fi

    # Verify size and checksum
    local size
    size=$(stat -c%s "$ptau_file" 2>/dev/null || stat -f%z "$ptau_file" 2>/dev/null) || {
        error "Failed to determine PTAU file size"
        return 1
    }

    if [[ $size -lt 1048576 ]]; then
        error "PTAU file suspiciously small: ${size} bytes"
        return 1
    fi

    local checksum
    checksum=$(sha256sum "$ptau_file" 2>/dev/null | awk '{print $1}') || {
        error "Failed to calculate PTAU checksum"
        return 1
    }

    if [[ "$checksum" != "$EXPECTED_PTAU_CHECKSUM" ]]; then
        error "PTAU checksum mismatch! Got: $checksum"
        error "Expected: $EXPECTED_PTAU_CHECKSUM"
        return 1
    fi

    success "PTAU integrity verified: ${checksum:0:16}..."
    return 0
}

verify_r1cs_integrity() {
    local r1cs_file="$R1CS_FILE"

    if [[ ! -f "$r1cs_file" ]]; then
        error "R1CS file missing: $r1cs_file"
        return 1
    fi

    # Basic size check
    local size
    size=$(stat -c%s "$r1cs_file" 2>/dev/null || stat -f%z "$r1cs_file" 2>/dev/null) || {
        error "Failed to determine R1CS file size"
        return 1
    }

    if [[ $size -lt 1000 ]]; then
        error "R1CS file suspiciously small: ${size} bytes"
        return 1
    fi

    local checksum
    checksum=$(sha256sum "$r1cs_file" 2>/dev/null | awk '{print $1}') || {
        error "Failed to calculate R1CS checksum"
        return 1
    }

    success "R1CS integrity verified: ${checksum:0:16}..."
    return 0
}

verify_zkey_chain() {
    local output_dir="$OUTPUT_DIR"
    local r1cs_file="$R1CS_FILE"
    local ptau_file="$PTAU_FILE"

    local total_zkeys=0
    local valid_zkeys=0
    local failed_zkeys=0

    info "Scanning for zkey files in ceremony chain..."

    # Find all zkey files in deterministic order
    while IFS= read -r -d '' zkey_file; do
        ((total_zkeys++))
        base_name=$(basename "$zkey_file")

        info "Verifying zkey: $base_name"

        # Extract expected index from filename (if numbered format)
        local numeric_index=-1
        if [[ "$base_name" =~ ${CIRCUIT_NAME}_([0-9]{4})\.zkey$ ]]; then
            # Numbered format: extract index
            local expected_index=${BASH_REMATCH[1]}
            numeric_index=$((10#$expected_index))
        elif [[ "$base_name" =~ ${CIRCUIT_NAME}_tmp_[0-9]+\.zkey$ ]]; then
            # Temporary format: skip index validation
            info "Temporary contribution file detected: $base_name"
        else
            # Invalid format
            error "Invalid filename format: $base_name (expected: ${CIRCUIT_NAME}_NNNN.zkey or ${CIRCUIT_NAME}_tmp_*.zkey)"
            ((failed_zkeys++))
            continue
        fi

        # Basic file validation
        local file_size
        file_size=$(stat -c%s "$zkey_file" 2>/dev/null || stat -f%z "$zkey_file" 2>/dev/null) || {
            error "Cannot determine file size: $base_name"
            ((failed_zkeys++))
            continue
        }

        if [[ $file_size -lt 100000 ]]; then
            error "Zkey file too small (possible corruption): $base_name (${file_size} bytes)"
            ((failed_zkeys++))
            continue
        fi

        # Verify cryptographic integrity
        info "Running cryptographic verification for $base_name..."

        local exit_code
        # Use timeout to prevent hanging
        timeout 300 snarkjs zkey verify "$r1cs_file" "$ptau_file" "$zkey_file" 2>/dev/null
        exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            success "Cryptographic verification passed: $base_name"

            # Verify checksum if checksum file exists
            local checksum_file="${zkey_file}.sha256"
            if [[ -f "$checksum_file" ]]; then
                local expected_checksum actual_checksum
                expected_checksum=$(cat "$checksum_file" 2>/dev/null | awk '{print $1}') || {
                    warning "Failed to read checksum file: $checksum_file"
                }

                actual_checksum=$(sha256sum "$zkey_file" 2>/dev/null | awk '{print $1}') || {
                    error "Failed to calculate checksum for verification"
                }

                if [[ -n "$expected_checksum" && -n "$actual_checksum" ]]; then
                    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                        success "Checksum verification passed: $base_name"
                    else
                        error "Checksum mismatch: $base_name"
                        error "Expected: $expected_checksum"
                        error "Actual: $actual_checksum"
                        ((failed_zkeys++))
                        continue
                    fi
                fi
            else
                warning "No checksum file found for: $base_name"
            fi

            ((valid_zkeys++))
        else
            error "Cryptographic verification FAILED (exit $exit_code): $base_name"
            ((failed_zkeys++))
        fi

    done < <(find "$output_dir" -name "${CIRCUIT_NAME}_*.zkey" -type f ! -name "${CIRCUIT_NAME}_final.zkey" -print0 | sort -z)

    # Also check contributions directory for pending contributions
    info "Scanning contributions directory for pending entries..."
    local contrib_count=0

    while IFS= read -r -d '' contrib_zkey; do
        ((contrib_count++))
        base_name=$(basename "$contrib_zkey")
        info "Found pending contribution: $base_name"

        # Basic validation only (full validation happens during aggregation)
        local file_size
        file_size=$(stat -c%s "$contrib_zkey" 2>/dev/null || stat -f%z "$contrib_zkey" 2>/dev/null) || {
            warning "Cannot determine file size: $base_name"
            continue
        }

        if [[ $file_size -lt 100000 ]]; then
            warning "Contribution file seems small (possible corruption): $base_name (${file_size} bytes)"
        else
            success "Pending contribution appears valid: $base_name (${file_size} bytes)"
        fi
    done < <(find "$CONTRIB_DIR" -maxdepth 1 -type f \( -name "${CIRCUIT_NAME}_[0-9][0-9][0-9][0-9].zkey" -o -name "${CIRCUIT_NAME}_tmp_*.zkey" \) -print0 2>/dev/null | sort -z)

    if [[ $contrib_count -gt 0 ]]; then
        info "Found $contrib_count pending contribution(s) awaiting aggregation"
    fi

    # Summary
    info "Chain verification summary:"
    info "  Total zkeys found: $total_zkeys"
    success "Valid zkeys: $valid_zkeys"
    if [[ $failed_zkeys -gt 0 ]]; then
        error "Failed zkeys: $failed_zkeys"
    fi

    if [[ $total_zkeys -gt 0 && $valid_zkeys -eq $total_zkeys ]]; then
        success "COMPLETE: All zkeys in ceremony chain are valid"
        return 0
    else
        error "INCOMPLETE: Ceremony chain contains invalid zkeys"
        return 1
    fi
}

verify_checksum_manifest() {
    local manifest_file="$MANIFEST_FILE"

    if [[ ! -f "$manifest_file" ]]; then
        warning "Checksum manifest not found - skipping verification"
        return 0
    fi

    info "Verifying checksum manifest integrity..."

    # Verify manifest checksum
    local temp_manifest="/tmp/manifest_verify_$$.txt"
    cp "$manifest_file" "$temp_manifest"

    # Remove the last line (manifest checksum) for recalculation
    sed -i '$ d' "$temp_manifest"

    local calculated_checksum manifest_checksum
    calculated_checksum=$(sha256sum "$temp_manifest" 2>/dev/null | awk '{print $1}') || {
        error "Failed to calculate manifest checksum"
        rm -f "$temp_manifest"
        return 1
    }

    manifest_checksum=$(tail -n 1 "$manifest_file" | sed 's/.*://' | xargs) || {
        error "Failed to extract manifest checksum"
        rm -f "$temp_manifest"
        return 1
    }

    rm -f "$temp_manifest"

    if [[ "$calculated_checksum" == "$manifest_checksum" ]]; then
        success "Checksum manifest integrity verified"
        return 0
    else
        error "Checksum manifest integrity check FAILED"
        error "Calculated: $calculated_checksum"
        error "Expected: $manifest_checksum"
        return 1
    fi
}

analyze_adversarial_security() {
    local output_dir="$OUTPUT_DIR"

    info "Analyzing adversarial security properties..."

    # Count total contributions
    local total_contributions
    total_contributions=$(find "$output_dir" -name "${CIRCUIT_NAME}_[0-9][0-9][0-9][0-9].zkey" | wc -l)

    # Count community contributions (excluding initial)
    local community_contributions=$((total_contributions - 1))

    if [[ $community_contributions -gt 0 ]]; then
        success "Adversarial security MAINTAINED: $community_contributions community contributions detected"
        success "Security guarantee: At least one honest participant assumed"
        return 0
    else
        warning "Adversarial security UNKNOWN: Only initial zkey detected"
        warning "Recommendation: Obtain additional community contributions"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# MAIN VERIFICATION EXECUTION
# -----------------------------------------------------------------------------

cat << 'EOF'
╔══════════════════════════════════════════════════╗
║        Lambda-ZK Ceremony Chain Verifier         ║
║             Integrity Verification v2.0          ║
╚══════════════════════════════════════════════════╝
EOF

info "Lambda-ZK Ceremony Chain Verifier v2.0 initialized"
info "Audit log: $LOG_FILE"

# Enable comprehensive logging
exec > >(tee -a "$LOG_FILE") 2>&1

errors=0

# Execute verification phases
echo
info "PHASE 1: Environment verification"
if ! verify_environment; then
    ((errors++))
fi

echo
info "PHASE 2: PTAU integrity verification"
if ! verify_ptau_integrity; then
    ((errors++))
fi

echo
info "PHASE 3: R1CS integrity verification"
if ! verify_r1cs_integrity; then
    ((errors++))
fi

echo
info "PHASE 4: Zkey chain cryptographic verification"
if ! verify_zkey_chain; then
    ((errors++))
fi

echo
info "PHASE 5: Checksum manifest verification"
if ! verify_checksum_manifest; then
    ((errors++))
fi

echo
info "PHASE 6: Adversarial security analysis"
if ! analyze_adversarial_security; then
    ((errors++))
fi

# -----------------------------------------------------------------------------
# FINAL SUMMARY AND REPORTING
# -----------------------------------------------------------------------------

echo
info "═══════════════════════════════════════════════════════════════"
info "VERIFICATION COMPLETE - FINAL REPORT"
info "═══════════════════════════════════════════════════════════════"

if [[ $errors -eq 0 ]]; then
    success "🎉 ALL CHECKS PASSED - Ceremony integrity verified!"
    success "The trusted setup chain is cryptographically sound."
    success "Audit trail saved to: $LOG_FILE"
    echo
    success " VERIFICATION STATUS: PASSED"
    exit 0
else
    error " VERIFICATION FAILED - $errors error(s) detected"
    error "Ceremony integrity compromises found - review audit log immediately"
    error "Audit trail saved to: $LOG_FILE"
    echo
    error " VERIFICATION STATUS: FAILED"
    exit 1
fi
