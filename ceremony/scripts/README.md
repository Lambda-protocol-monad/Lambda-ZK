# 🔧 Lambda-ZK Ceremony Scripts

**Trusted Setup Automation & Verification Tools**

This directory contains the core Bash scripts that automate Lambda-ZK's trusted setup ceremony. These scripts handle contribution generation, cryptographic validation, deterministic aggregation, and comprehensive verification, ensuring the ceremony maintains mathematical security guarantees while being accessible to non-cryptographers.

## 📋 Table of Contents

- [Script Overview](#script-overview)
- [Execution Flow & Decision Points](#execution-flow--decision-points)
- [Script Details](#script-details)
- [Security Features](#security-features)
- [Testing & Validation](#testing--validation)
- [Error Codes & Handling](#error-codes--handling)
- [Maintenance](#maintenance)

## 📦 Script Overview

| Script                                     | Purpose                             | Size       | Security Features                           |
| ------------------------------------------ | ----------------------------------- | ---------- | ------------------------------------------- |
| [**`contribute.sh`**](./contribute.sh)     | Generate user entropy contributions | ~200 lines | PTAU validation, input sanitization         |
| [**`run_ceremony.sh`**](./run_ceremony.sh) | Aggregate & validate contributions  | ~400 lines | Multi-layer validation, manifest generation |
| [**`verify_chain.sh`**](./verify_chain.sh) | Independent chain verification      | ~150 lines | Complete cryptographic audit                |
| [**`final_beacon.sh`**](./final_beacon.sh) | Finalize with randomness beacon     | ~80 lines  | Toxic waste destruction                     |

## 🔄 Execution Flow & Decision Points

### **Ceremony Script Decision Tree**

```
🏁 Ceremony Start
    ↓
1️⃣  User runs ./contribute.sh
    - PTAU file exists & valid SHA-256?
    - ✅ YES: Continue
    - ❌ NO: Download & verify → Continue
    - 🚫 FAIL: Exit with PTAU_ERROR

2️⃣  Generate contribution entropy
    - User provide identity? (Y/n)
    - ✅ YES: Include in metadata
    - ❌ NO: Anonymous contribution

3️⃣  Auto-detect latest .zkey
    - ceremony/output/ exists?
    - ✅ YES: Find latest giftcard_merkle_XXXX.zkey
    - ❌ NO: Start with base contribution (0001)

4️⃣  Create contribution file
    - snarkjs zkey contribute succeeds?
    - ✅ YES: Generate ceremony/contrib/giftcard_merkle_YYYY.zkey
    - ❌ NO: Log error & exit with CONTRIBUTION_ERROR

5️⃣  PR Submission (manual)
    ↓

6️⃣  GitHub Actions run ./run_ceremony.sh
    - Main branch push with .zkey files?
    - ✅ YES: Begin aggregation

7️⃣  Pre-flight validation
    - PTAU integrity (SHA-256 checksum)?
    - 🚫 FAIL: Exit with PTAU_ERROR
    - ✅ PASS: Continue

8️⃣  Contribution validation loop
    - For each unprocessed .zkey:
        - Load current zkey chain state
        - File age < 5 min timeout?
            - ✅ YES: Wait & retry
            - ❌ NO: Continue (may indicate corruption)
        - snarkjs zkey verify succeeds?
            - ✅ YES: Accept contribution
            - ❌ NO: Reject & log REJECTED_CONTRIBUTION

9️⃣  Aggregation processing
    - Deterministic file ordering (alphabetical)
    - snarkjs zkey beacon (final) or zkey contribute?
        - User triggered finalize-ceremony.yml?
            - ✅ YES: Use zkey beacon (toxic waste removal)
            - ❌ NO: Use zkey contribute (aggregation)
    - snarkjs command succeeds?
        - ✅ YES: Update ceremony/output/ chain
        - ❌ NO: Exit with AGGREGATION_ERROR

10️⃣  Post-processing
     - Generate checksum manifest
     - Archive current artifacts
     - Clean up temporary files

11️⃣  Verification (./verify_chain.sh)
     - Independent verification requested?
         - ✅ YES: Run verify_chain.sh
         - All checks pass?
             - ✅ YES: Ceremony integrity confirmed
             - ❌ NO: Log VERIFICATION_ERROR

🏆 Ceremony Complete - Production keys ready
```

### **Critical Decision Points**

#### **Security Branch Points**

- **PTAU Integrity**: Guardian against Phase 1 compromise
- **Individual Contribution Validation**: Prevents malicious entropy injection
- **Timing Validation**: GitHub Actions race condition handling
- **Exit Code Logic**: Prevents infinite CI loops

#### **User Choice Points**

- **Identity Disclosure**: Pseudonymous vs anonymous participation
- **Final Beacon Trigger**: Manual finalization decision

#### **Error Recovery Points**

- **Manifest Regeneration**: Self-healing checksum recovery
- **Chain Validation**: Independent verification independence

## 📄 Script Details

### **🔐 `contribute.sh` - Entropy Contribution Generator**

**Purpose**: Generate cryptographically secure entropy contributions for the trusted setup ceremony.

#### **Key Features**

- **PTAU auto-download**: Downloads and verifies universal parameters on first run
- **Latest zkey detection**: Automatically finds the most recent ceremony state
- **Interactive identity**: Optional pseudonym for contribution attribution
- **SECURITY**: Comprehensive input validation and path sanitization

#### **Execution Flow**

```bash
./contribute.sh

# Internal flow:
validate_environment()    # Check Node.js, snarkjs availability
ensure_ptau()            # Download/verify powers-of-tau file
detect_latest_zkey()     # Auto-find ceremony/output/giftcard_merkle_*.zkey
get_user_identity()      # Optional pseudonym prompt
generate_entropy()       # Create random contribution via snarkjs
validate_contribution()  # Post-generation integrity check
output_contribution()    # ceremony/contrib/giftcard_merkle_YYYY.zkey
log_contribution()       # Audit trail entry
```

#### **Generated Files**

- `ceremony/contrib/giftcard_merkle_YYYY.zkey` - User entropy contribution
- `ceremony/logs/contribution_YYYY-MM-DD_HH-MM-SS.log` - Audit record

#### **Error Codes**

- `PTAU_ERROR`: Power-of-tau file integrity compromised
- `ENVIRONMENT_ERROR`: Required tools missing/incompatible
- `CONTRIBUTION_ERROR`: Entropy generation failed

### **🔄 `run_ceremony.sh` - Contribution Aggregation Engine**

**Purpose**: Orchestrate the multi-party computation, validate all contributions, and maintain the ceremony chain with complete audit trails.

#### **Core Responsibilities**

1. **Pre-flight validation**: PTAU integrity and environment checks
2. **Contribution sequencing**: Deterministic ordering prevents manipulation
3. **Cryptographic verification**: Per-contribution `snarkjs zkey verify`
4. **Chain aggregation**: Maintain verified contribution sequence
5. **Manifest generation**: SHA-256 checksum integrity tracking
6. **Audit logging**: Timestamped operational transparency

#### **Security Architecture**

```bash
# Multi-layer validation sequence
validate_ptau_integrity()     # SHA-256 checksum verification
initialize_ceremony_state()   # Load current chain tip
sequence_contributions()      # Alphabetical file ordering
verify_contribution_batch()   # snarkjs zkey verify loop
aggregate_valid_contributions() # Chain update
generate_manifest()           # Cryptographic checksums
archive_artifacts()           # 90-day retention
```

#### **Key Security Features**

- **Deterministic processing**: Alphabetical filename sorting prevents timing attacks
- **Individual validation**: Each contribution verified independently
- **Exit code logic**: Intelligent failure handling prevents CI loops
- **Timeout handling**: 5-minute verification windows with retry logic
- **Input sanitization**: Path traversal protection and bounds checking

#### **Generated Artifacts**

- `ceremony/output/giftcard_merkle_YYYY.zkey` - Updated chain state
- `ceremony/output/checksum_manifest.txt` - Integrity checksums
- `ceremony/logs/ceremony_YYYY-MM-DD_HH-MM-SS.log` - Operation audit

#### **Error Codes**

- `PTAU_ERROR`: Universal parameters integrity compromised
- `VALIDATION_ERROR`: Contribution cryptographic verification failed
- `AGGREGATION_ERROR`: Chain update operation failed
- `MANIFEST_ERROR`: Checksum generation/storage failed
- `LOOP_DETECTED`: CI loop prevention trigger

### **🔍 `verify_chain.sh` - Independent Verification Auditor**

**Purpose**: Provide third-party verification of ceremony integrity without trusting the aggregation scripts.

#### **Verification Scope**

```bash
./verify_chain.sh

# Comprehensive validation sequence:
audit_ptau_integrity()       # SHA-256 validation against known good
audit_r1cs_consistency()     # Circuit constraint verification
audit_contribution_chain()   # Each contribution cryptographic validation
audit_manifest_integrity()   # Checksum manifest self-verification
audit_temporal_ordering()    # Contribution chronological validation
audit_finalization_state()   # Beacon application verification
```

#### **Trust Model**

- **Zero-trust design**: Verifies all artifacts independently
- **Cryptographic verification**: Uses `snarkjs` verification primitives
- **Manifest self-consistency**: Checksums verify themselves
- **Complete independence**: No dependency on ceremony scripts

#### **Verification Passes**

1. **File Integrity**: All artifacts exist and readable
2. **Cryptographic Verification**: All zkeys verified against R1CS + PTAU
3. **Chain Consistency**: Each contribution properly incorporated
4. **Manifest Accuracy**: SHA-256 hashes match computed values
5. **Temporal Ordering**: Contributions in chronological sequence
6. **Finalization Correctness**: Beacon application verified (when complete)

#### **Output Format**

```bash
# Verification results
✅ PTAU integrity verified: a1b2c3d4...
✅ R1CS circuit validated: 2048 constraints
✅ Contribution #1 verified: giftcard_merkle_0001.zkey
✅ Contribution #2 verified: giftcard_merkle_0002.zkey
✅ Chain consistency: All contributions integrated
✅ Manifest integrity: Checksums self-consistent
✅ Aggregate verification: PASSED

🎉 Ceremony integrity verified - zero-knowledge proofs are secure!
```

#### **Error Codes**

- `PTAU_CORRUPTED`: Universal parameters compromised
- `R1CS_INVALID`: Circuit constraint system invalid
- `CHAIN_BROKEN`: Contribution verification failed
- `MANIFEST_TAMPERED`: Checksum integrity compromised

### **🎯 `final_beacon.sh` - Toxic Waste Destruction Finalizer**

**Purpose**: Complete the trusted setup ceremony by applying a public randomness beacon that destroys the "toxic waste" making the proving key safe for production use.

#### **Beacon Process (Direct Script Implementation)**

**Actual execution steps from the real script:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Step 1: Find latest non-final zkey in ceremony/output/
LAST_ZKEY=$(ls "$OUT"/${CIRCUIT_NAME}_*.zkey 2>/dev/null | grep -v "_final.zkey" | sort | tail -n 1)

# Step 2: Fetch public randomness from drand round 23976283
DRAND_ROUND=23976283
DRAND_URL="https://api.drand.sh/public/${DRAND_ROUND}"
RESPONSE=$(curl -s "$DRAND_URL")

# Handle future round case
if echo "$RESPONSE" | grep -q "Requested future beacon"; then
    echo "ERROR: drand round ${DRAND_ROUND} is still in the future."
    echo "Wait until the round is available, then run final_beacon.sh again."
    exit 1
fi

# Extract randomness field from JSON using python3
RANDOMNESS=$(echo "$RESPONSE" | python3 - << 'PY'
import sys, json
data = json.load(sys.stdin)
print(data["randomness"])
PY
)

# Step 3: Derive beacon hash from randomness via SHA-256
BEACON_HASH=$(echo -n "$RANDOMNESS" | sha256sum | cut -d' ' -f1)
echo "Derived beacon hash (sha256 of drand randomness): $BEACON_HASH"

# Step 4: Apply beacon transformation using snarkjs
snarkjs zkey beacon "$LAST_ZKEY" "$FINAL_ZKEY" "$BEACON_HASH" 10

# Step 5: Generate SHA-256 checksum of final zkey
sha256sum "$FINAL_ZKEY" > "$FINAL_ZKEY.sha256"

# Step 6: Verify final zkey against R1CS and PTAU
snarkjs zkey verify "$R1CS" "$PTAU" "$FINAL_ZKEY"
```

#### **Drand Integration Details**

- **Beacon Round**: Pre-committed round 23976283 (chosen in advance)
- **Security**: Public randomness prevents coordinator manipulation
- **Verification**: Rounds must be available (not in future)
- **Extraction**: JSON parsing via Python for robustness

#### **Cryptographic Operation**

- **Source**: Decentralized Drand randomness network
- **Hash Function**: SHA-256 transforms randomness into beacon entropy
- **Application**: `snarkjs zkey beacon` with 10-bit contribution strength
- **Verification**: Post-beacon cryptographic validation against circuit

#### **Generated Artifacts**

- `giftcard_merkle_final.zkey` - Production-safe proving key (toxic waste destroyed)
- `giftcard_merkle_final.zkey.sha256` - SHA-256 integrity checksum file

#### **Finalization Security Guarantees**

- **Toxic waste destruction**: Beacon entropy removes secret proving parameters
- **Zero-knowledge preservation**: Mathematical security properties maintained
- **Post-compromise security**: Proving key can be made public after beacon application
- **Universal verifiability**: Anyone can verify beacon application was correct

## 🛡️ Security Features

### **Input Validation & Sanitization**

- **Path traversal prevention**: `..` character detection and neutralization
- **Control character filtering**: Non-printable character removal
- **Length limits**: Reasonable bounds (4096 character maximum)
- **Numeric validation**: Type and range checking for all numeric inputs

### **Cryptographic Integrity Verification**

- **SHA-256 checksums**: PTAU and all artifact integrity
- **SnarkJS verification**: Cryptographic proof validation per contribution
- **Manifest integrity**: Self-verifying checksum manifests
- **Chain consistency**: Audit trail verification across all contributions

### **Operational Security**

- **Timeout handling**: Prevents resource exhaustion attacks
- **Concurrent safety**: File locking prevents race conditions
- **Audit logging**: Timestamped operation recording
- **Fail-safe exits**: Secure termination on validation failures

### **Adversarial Resilience**

- **Deterministic ordering**: Manipulation-resistant contribution sequencing
- **Individual verification**: Each contribution validated independently
- **Tamper detection**: SHA-256 checksums enable forgery detection
- **Zero-trust validation**: All inputs verified multiple times

### **CI/CD Testing Matrix**

- **Environment variants**: Node.js versions, OS combinations
- **Network conditions**: PTAU download failure simulation
- **File corruption**: Checksum validation bypass attempts
- **Race conditions**: Concurrent contribution simulations
- **Invalid inputs**: Path traversal, buffer overflow attempts

### **Security Testing Scenarios**

- **PTAU injection**: Attempt to substitute compromised Phase 1 parameters
- **Contribution spoofing**: Invalid zkey format submission attempts
- **Timing manipulation**: File ordering attack simulations
- **Resource exhaustion**: Large input processing limits

## 🚨 Error Codes & Handling

### **Standard Exit Codes**

- `0`: SUCCESS - Operation completed normally
- `1`: GENERAL_ERROR - Unspecified failure
- `2`: PTAU_ERROR - Powers-of-tau integrity failure
- `3`: VALIDATION_ERROR - Cryptographic verification failure
- `4`: AGGREGATION_ERROR - Chain update operation failure
- `5`: ENVIRONMENT_ERROR - System requirements not met
- `6`: INPUT_ERROR - Invalid user input provided
- `7`: TIMEOUT_ERROR - Operation exceeded time limits
- `8`: LOOP_DETECTED - CI/CD loop prevention triggered

### **Error Recovery Procedures**

- **PTAU failures**: Automatic redownload from trusted source
- **Validation failures**: Detailed logging for contributor correction
- **Network issues**: Exponential backoff retry logic
- **File corruption**: Manifest-based artifact recovery

### **Version Compatibility**

- **SnarkJS compatibility**: Regular testing against latest versions
- **Node.js support**: Tested across LTS versions
- **OS compatibility**: Linux, macOS, WSL validation
- **Git version requirements**: Minimum version enforcement

### **Performance Optimization**

- **Memory usage**: Monitor and optimize resource consumption
- **Execution time**: Profile and optimize slow operations
- **Disk I/O**: Efficient file handling for large artifacts
- **Network efficiency**: Cached downloads for repeated operations

---

**These scripts transform complex cryptographic trusted setup ceremonies into accessible, automated processes while maintaining the mathematical security guarantees critical for zero-knowledge proof systems.** 🔐💻

## 📄 Related Documentation

- [`../README.md`](../README.md) - Project overview and participation guide
- [`../ceremony/README.md`](../ceremony/README.md) - Ceremony process documentation
- [`../circuits/README.md`](../circuits/README.md) - Circuit technical specifications
- [`verify_chain.sh`](verify_chain.sh) - Independent verification tool
