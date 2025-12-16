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

This repository implements a **privacy-preserving giftcard system** using zero-knowledge proofs (ZK-SNARKs). The protocol allows users to:

- Deposit funds into privacy-preserving giftcard commitments
- Make partial withdrawals without revealing the total balance
- Prevent double-spending through cryptographic nullifiers
- Generate ephemeral recipient addresses for each withdrawal
- Prove membership in a Merkle tree without revealing position

All while maintaining complete privacy and cryptographic security through Groth16 proofs.

## GiftCardMerkle Circuit

The core of this system is the `GiftCardMerkle` circuit (circuits/giftcard_merkle.circom:1), a depth-32 Merkle tree-based privacy protocol that enables private giftcard withdrawals with spending constraints.

### Circuit Architecture

**Private Inputs:**

- `secret`: User's secret value (never revealed)
- `salt`: Randomization factor for commitment hiding
- `amountDeposited`: Total giftcard balance
- `amountRequested`: Current withdrawal amount
- `spentBefore`: Previously spent amount
- `ephemeralPrivKey`: BabyJubJub private key for one-time recipient address
- `pathElements[32]` / `pathIndices[32]`: Merkle proof of inclusion

**Public Outputs:**

- `root`: Merkle tree root (validates membership)
- `nullifierCurrent`: Unique nullifier `Poseidon(secret, amountRequested)` to prevent double-spending
- `amount`: Withdrawal amount (public for verification)
- `leafCommitment`: Giftcard commitment `Poseidon(secret, salt, amountDeposited)`
- `spentBefore_pub` / `spentAfter_pub` / `amountDeposited_pub`: Spending tracking
- `ephPubKeyX` / `ephPubKeyY`: BabyJubJub public key for ephemeral recipient

### Protocol Flow

1. **Deposit Phase**: User creates commitment `leafCommitment = Poseidon(secret, salt, amountDeposited)` and inserts into Merkle tree
2. **Withdrawal Phase**: User generates ZK proof with:
   - Merkle path proving commitment exists in tree
   - Spending constraint verification: `spentBefore + amountRequested <= amountDeposited`
   - Nullifier generation to prevent re-use
   - Ephemeral public key derivation for withdrawal address
3. **Verification**: Smart contract verifies proof and checks nullifier hasn't been used

### Cryptographic Components

- **Poseidon Hash**: ZK-friendly hash function for commitments, nullifiers, and Merkle tree (circuits/giftcard_merkle.circom:94,119,151)
- **BabyJubJub**: Elliptic curve for ephemeral key generation (circuits/giftcard_merkle.circom:76)
- **Merkle Tree**: Depth-32 tree with Poseidon hashing for commitment set anonymity (circuits/giftcard_merkle.circom:125)
- **Spending Constraint**: Enforced via `LessThan(128)` comparator ensuring `spentAfter <= amountDeposited` (circuits/giftcard_merkle.circom:111)

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
│   ├── giftcard_merkle.circom   # Main privacy giftcard circuit (depth-32 Merkle tree)
│   ├── poseidon.circom         # Poseidon hash function (ZK-friendly)
│   └── test.circom             # Test circuits
├── circuits/build/             # Compiled circuit artifacts (.r1cs, .wasm, .sym)
├── circuits/ptau/              # Phase 1 powers-of-tau (verified ceremony artifact)
├── ceremony/
│   ├── contrib/                # User entropy contributions (PR submissions)
│   ├── output/                 # Official verified ceremony chain (proving keys)
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

# Review audit logs
ls -la ceremony_*.log

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
GitHub Actions generates timestamped audit artifacts containing:

- Cryptographic operation documentation (millisecond precision)
- File validation results with rejection diagnostics
- Manifest generation and verification status
- Chain consistency proofs

Example log entry:

```
2025-12-09 15:47:48 SECURITY_OK: PTAU integrity verified: e970efa7...
2025-12-09 15:47:48 VALIDATION_SUCCESS: Contribution #1 cryptographically verified
2025-12-09 15:47:48 INTEGRATION_SUCCESS: Contribution #1 integrated into ceremony chain
```

## Security Properties

### Circuit Security

**Privacy Guarantees:**

- User's `secret` and `salt` never revealed on-chain
- Merkle tree hides which commitment is being spent (anonymity set of 2^32)
- Ephemeral keys prevent address linkability between withdrawals
- Nullifiers prevent double-spending without revealing secret

**Soundness Guarantees:**

- Spending constraint enforced: `spentBefore + amountRequested <= amountDeposited` (circuits/giftcard_merkle.circom:106)
- Merkle proof ensures commitment exists in tree (circuits/giftcard_merkle.circom:125)
- Nullifier uniquely binds to withdrawal amount and secret
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

- **Privacy-preserving giftcards**: Users can withdraw funds without revealing total balance
- **Partial withdrawals**: Spend giftcards incrementally while maintaining privacy
- **Anonymous payments**: Merkle tree provides anonymity set, nullifiers prevent double-spending
- **Ephemeral recipients**: Each withdrawal generates new public key for enhanced privacy
- **On-chain verification**: Smart contracts can verify withdrawals without learning sensitive data

## Technical Details

**Circuit Statistics:**

- Constraints: ~2,500 (estimated for depth-32 Merkle tree)
- Public inputs: 9 (root, nullifier, amount, commitment, spending tracking, ephemeral pubkey)
- Private inputs: 6 + 64 (secret, salt, amounts, ephemeralPrivKey, Merkle path)
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
