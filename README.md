# Privacy-Preserving Giftcard System

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](./LICENSE)
[![Ceremony CI](https://github.com/Lambda-protocol-monad/Lambda-ZK/actions/workflows/verify-ceremony.yml/badge.svg)](https://github.com/Lambda-protocol-monad/Lambda-ZK/actions/workflows/aggregate-ceremony.yml)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](./CONTRIBUTING.md)
[![snarkjs](https://img.shields.io/badge/snarkjs-0.7.4-purple.svg)](https://github.com/iden3/snarkjs)
[![Circom](https://img.shields.io/badge/circom-2.1.9-orange.svg)](https://github.com/iden3/circom)
[![Groth16](https://img.shields.io/badge/proving%20system-Groth16-blueviolet.svg)](https://eprint.iacr.org/2016/260.pdf)
[![Zero Knowledge](https://img.shields.io/badge/ZK-SNARK-ff69b4.svg)](https://z.cash/technology/zksnarks/)

Zero-Knowledge Giftcard Protocol with Merkle Privacy and Partial Withdrawals

## Table of Contents

- [Overview](#overview)
- [GiftCardMerkle Circuit](#giftcardmerkle-circuit)
- [Trusted Setup Ceremony](#trusted-setup-ceremony)
- [Repository Structure](#repository-structure)
- [How to Contribute to the Ceremony](#how-to-contribute-to-the-ceremony)
- [Security Properties](#security-properties)
- [Use Cases](#use-cases)
- [Technical Details](#technical-details)
- [License](#license)

## Overview

This repository implements a **privacy-preserving giftcard system** using zero-knowledge proofs (ZK-SNARKs) with **UTXO-style commitment chaining**. The protocol allows users to:

- Deposit funds into privacy-preserving commitments stored in a Merkle tree
- Make partial withdrawals with unlinkable change outputs (similar to Bitcoin UTXOs)
- Prevent double-spending through unique cryptographic nullifiers
- Generate ephemeral recipient addresses for each withdrawal
- Prove membership in a Merkle tree without revealing which commitment is being spent

All while maintaining complete privacy and cryptographic security through Groth16 proofs.

## GiftCardMerkle Circuit

The core of this system is the `GiftCardMerkle` circuit (circuits/giftcard_merkle.circom:1), a depth-32 Merkle tree-based privacy protocol implementing **UTXO-style commitment chaining** with unlinkable partial withdrawals.

### Circuit Architecture

**Private Inputs:**

- `oldSecret`: Secret for the commitment being spent
- `oldSalt`: Salt for the old commitment
- `oldAmount`: Total amount in the old commitment
- `withdrawAmount`: Amount to withdraw in this transaction
- `newSecret`: Secret for the new change commitment
- `newSalt`: Salt for the new change commitment
- `ephemeralPrivKey`: BabyJubJub private key for one-time recipient address
- `pathElements[32]` / `pathIndices[32]`: Merkle proof for old commitment

**Public Outputs:**

- `root`: Merkle tree root (validates membership)
- `nullifier`: Unique nullifier `Poseidon(oldSecret, oldSalt)` to prevent commitment reuse
- `withdrawAmount_pub`: Amount being withdrawn (public for verification)
- `newCommitment`: New commitment with change `Poseidon(newSecret, newSalt, changeAmount)` (or 0 if full withdrawal)
- `ephPubKeyX` / `ephPubKeyY`: BabyJubJub public key for ephemeral recipient

### Protocol Flow (UTXO Model)

1. **Deposit Phase**: User creates initial commitment `Poseidon(secret, salt, amount)` and inserts into Merkle tree
2. **Withdrawal Phase**: User generates ZK proof that:
   - Proves old commitment exists in Merkle tree via inclusion proof
   - Consumes old commitment by revealing unique nullifier `Poseidon(oldSecret, oldSalt)`
   - Enforces spending constraint: `withdrawAmount <= oldAmount` (circuits/giftcard_merkle.circom:93)
   - Creates new commitment with change: `changeAmount = oldAmount - withdrawAmount`
   - Generates ephemeral public key for withdrawal recipient
3. **Change Handling**:
   - If `changeAmount > 0`: Creates new commitment with different secret/salt (unlinkable)
   - If `changeAmount = 0`: Full withdrawal, `newCommitment = 0`
4. **Verification**: Smart contract verifies proof, checks nullifier is unused, adds new commitment to tree

### Cryptographic Components

- **Poseidon Hash**: ZK-friendly hash function for commitments, nullifiers, and Merkle tree (circuits/giftcard_merkle.circom:69,81,102,140)
- **BabyJubJub**: Elliptic curve for ephemeral key generation (circuits/giftcard_merkle.circom:57)
- **Merkle Tree**: Depth-32 tree with Poseidon hashing for commitment set anonymity (circuits/giftcard_merkle.circom:117-162)
- **Spending Constraint**: Enforced via `LessThan(128)` comparator ensuring `withdrawAmount <= oldAmount` (circuits/giftcard_merkle.circom:93)

## Trusted Setup Ceremony

This repository hosts an ongoing **Phase 2 trusted setup ceremony** to generate secure Groth16 proving keys for the giftcard circuit.

### Ceremony Properties

- **Open & Decentralized**: Anyone can contribute entropy to strengthen security
- **Transparent**: All contributions via public GitHub Pull Requests
- **Fully Auditable**: Comprehensive timestamped audit logs with 90-day retention
- **Tamper-Evident**: SHA-256 cryptographic manifests with self-verification
- **Automated**: GitHub Actions manages the entire trusted setup process
- **Security Guarantee**: Requires only 1 honest participant to ensure secure final keys

### Ceremony Security Features

**Cryptographic Validation:**

- PTAU integrity verification against known checksums
- Per-contribution validation via `snarkjs zkey verify` (5-minute timeout)
- SHA-256 checksum manifests for all artifacts
- Filename pattern and index consistency checking

**Audit & Transparency:**

- Timestamped execution logs with millisecond precision
- GitHub Actions artifact preservation (90-day retention)
- Deterministic processing order with comprehensive logging
- Public checksum manifests at `ceremony/output/checksum_manifest.txt`

**Input Safety:**

- Path traversal attack prevention
- Control character removal and length limits (4096 chars max)
- File size validation to detect corruption

## Repository Structure

```
├── circuits/                    # ZK circuit implementations
│   ├── giftcard_merkle.circom   # Main UTXO-style privacy circuit (depth-32 Merkle tree)
│   ├── poseidon.circom         # Poseidon hash function (ZK-friendly)
│   └── test.circom             # Test circuits
├── circuits/build/             # Compiled circuit artifacts (.r1cs, .wasm, .sym)
├── circuits/ptau/              # Phase 1 powers-of-tau (verified ceremony artifact)
├── ceremony/
│   ├── contrib/                # User entropy contributions (PR submissions)
│   ├── output/                 # Official verified ceremony chain (proving keys)
│   ├── logs/                   # Timestamped audit logs (90-day retention)
│   └── scripts/
│       ├── contribute.sh       # Generate and submit entropy contribution
│       ├── run_ceremony.sh     # CI aggregation script with validation
│       ├── final_beacon.sh     # Apply random beacon for finalization
│       └── verify_chain.sh     # Independent ceremony verification tool
├── CLAUDE.md                   # Architecture documentation and guidance
├── CONTRIBUTING.md             # Contribution guidelines
└── README.md                   # This file
```

## How to Contribute to the Ceremony

Anyone can strengthen the ceremony by contributing random entropy. Only one honest participant is needed to ensure the final proving key is secure.

### Prerequisites

- **Node.js**: v16.0.0 or higher
- **snarkjs**: `npm install -g snarkjs`

### Contribution Steps

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-org/lambda-zk.git
   cd lambda-zk/ceremony/scripts
   ```

2. **Generate your contribution**

   ```bash
   ./contribute.sh
   ```

   This script:

   - Validates the current ceremony state and PTAU integrity
   - Detects the latest verified zkey in `ceremony/output/`
   - Generates your contribution with fresh entropy
   - Creates file: `ceremony/contrib/giftcard_merkle_XXXX.zkey`
   - Displays SHA-256 checksum for verification

3. **Submit via Pull Request**
   ```bash
   git checkout -b contrib-yourname
   git add ceremony/contrib/giftcard_merkle_XXXX.zkey
   git commit -m "Add entropy contribution"
   git push origin contrib-yourname
   ```

### Automated Verification

**PR Validation:**
GitHub Actions automatically validates your contribution:

- PTAU integrity verification
- Circuit compatibility check via `snarkjs zkey verify`
- Genuine entropy contribution verification
- File integrity and safety checks

**Chain Aggregation:**
Upon PR merge, the CI automatically:

- Integrates contribution into `ceremony/output/`
- Generates updated SHA-256 checksum manifests
- Maintains complete chain history
- Uploads audit logs (90-day retention)

## Finalization Phase

After sufficient contributions, the ceremony is finalized using a public randomness beacon to eliminate any remaining toxic waste.

**Final Artifacts:**

- `ceremony/output/giftcard_merkle_final.zkey` - Production proving key
- `ceremony/output/giftcard_merkle_verification_key.json` - Verification key for smart contracts

**Run finalization:**

```bash
cd ceremony/scripts
./final_beacon.sh
```

This process is typically automated through GitHub Actions for transparency.

## Auditing & Verification

Anyone can independently verify the entire ceremony:

```bash
cd ceremony/scripts

# Verify complete ceremony chain
./verify_chain.sh

# Review audit logs (check both locations)
ls -la ../logs/*.log ceremony_*.log 2>/dev/null

# Check checksum manifest
cat ../output/checksum_manifest.txt
```

**Verification Coverage:**

- PTAU integrity (checksum + size validation)
- R1CS circuit file integrity
- All zkey files via `snarkjs zkey verify`
- Per-contribution filename, index, and size validation
- SHA-256 checksum verification
- Audit trail consistency and temporal ordering

**Audit Logs:**
GitHub Actions generates timestamped audit artifacts stored in `ceremony/logs/` and `ceremony/scripts/` containing:

- Cryptographic operation documentation (millisecond precision)
- File validation results with rejection diagnostics
- Manifest generation and verification status
- Chain consistency proofs
- 90-day artifact retention in GitHub Actions

Example log entry:

```
2025-12-09 15:47:48 SECURITY_OK: PTAU integrity verified: e970efa7...
2025-12-09 15:47:48 VALIDATION_SUCCESS: Contribution #1 cryptographically verified
2025-12-09 15:47:48 INTEGRATION_SUCCESS: Contribution #1 integrated into ceremony chain
```

## Security Properties

### Circuit Security

**Privacy Guarantees:**

- User's secrets (`oldSecret`, `newSecret`) and salts never revealed on-chain
- Merkle tree hides which commitment is being spent (anonymity set of 2^32)
- Change commitments use fresh `newSecret` and `newSalt`, making them unlinkable to old commitments
- Ephemeral keys prevent address linkability between withdrawals
- Nullifiers prevent commitment reuse without revealing secrets

**Soundness Guarantees:**

- Spending constraint enforced: `withdrawAmount <= oldAmount` (circuits/giftcard_merkle.circom:93)
- Merkle proof ensures old commitment exists in tree (circuits/giftcard_merkle.circom:117-162)
- Nullifier `Poseidon(oldSecret, oldSalt)` uniquely identifies each UTXO, preventing double-spends
- Change amount automatically calculated: `changeAmount = oldAmount - withdrawAmount`
- BabyJubJub key derivation is cryptographically secure

### Ceremony Security

**Cryptographic Guarantees:**

- Independent entropy from each participant
- Automated validation via `snarkjs zkey verify` (300s timeout)
- Privacy-preserving: coordinators never access private entropy
- Universal trust: ≥1 honest participant ensures secure final keys
- Tamper detection via SHA-256 checksums and self-verifying manifests

**Security Architecture:**

- Multi-layered validation (cryptographic, logical, integrity checks)
- Zero-trust approach assuming potentially malicious participants
- Deterministic processing order prevents manipulation
- Full auditability through immutable Git history and timestamped logs
- Input sanitization prevents injection and path traversal attacks

## Contributing

We welcome contributions from everyone! See [CONTRIBUTING.md](./CONTRIBUTING.md) for:

- Ceremony participation requirements
- Code contribution procedures
- Development environment setup
- Pull request templates and review process
- Security audit and testing procedures

## Use Cases

The GiftCardMerkle circuit enables:

- **Privacy-preserving giftcards**: Users can withdraw funds without revealing original balance or linking withdrawals
- **UTXO-style partial withdrawals**: Spend giftcards incrementally with unlinkable change outputs
- **Anonymous payments**: Merkle tree provides anonymity set of 2^32, nullifiers prevent double-spending
- **Unlinkable change**: Each withdrawal creates a fresh commitment with new secrets, preventing transaction graph analysis
- **Ephemeral recipients**: Each withdrawal generates new public key for enhanced privacy
- **On-chain verification**: Smart contracts can verify withdrawals without learning sensitive data

## Technical Details

**Circuit Statistics:**

- Constraints: ~2,500 (estimated for depth-32 Merkle tree with UTXO chaining)
- Public outputs: 6 (root, nullifier, withdrawAmount_pub, newCommitment, ephPubKeyX, ephPubKeyY)
- Private inputs: 7 + 64 (oldSecret, oldSalt, oldAmount, withdrawAmount, newSecret, newSalt, ephemeralPrivKey, plus pathElements[32] and pathIndices[32])
- Proving system: Groth16 (succinct proofs, fast verification)

**Dependencies:**

- Circom 2.x
- circomlib (Poseidon, BabyJubJub, Comparators)
- snarkjs 0.7.x
- Phase 1 PTAU: Powers of Tau 28 (supports circuits up to 2^18 constraints)

## License

GPL-3.0 License - see [LICENSE](./LICENSE) file for details.

## Acknowledgments

Built on foundations from the ZK cryptography community, Circom/snarkjs by iden3, and trusted setup best practices from Aztec, Tornado Cash, and other production ZK systems. Special thanks to all ceremony participants for contributing entropy to secure this system.
