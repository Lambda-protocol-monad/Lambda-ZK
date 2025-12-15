# 🐑 Lambda-ZK Gift Card Circuit

**Advanced Zero-Knowledge Gift Card with Merkle Tree Privacy**

This directory contains a production-ready Circom implementation of a privacy-preserving gift card protocol using Merkle tree commitments. This circuit powers the active Lambda-ZK trusted setup ceremony and enables secure, private token gifting with Tornado Cash-style anonymity guarantees.

## 📦 Circuit Specification

### **Main Circuit: `giftcard_merkle.circom`**

**File**: [`giftcard_merkle.circom`](./giftcard_merkle.circom) - 95 lines
**Circom Version**: 2.0.0
**Tree Depth**: 32 levels (4.3 billion possible leaves)
**Trust Model**: Multi-party computation ceremony with ≥1 honest participant

#### **Circuit Interface**

```circom
template GiftCardMerkle(depth) {
    // Private inputs
    signal input secret;               // Card secret
    signal input salt;                 // Random salt for commitment
    signal input amountDeposited;      // Original deposit amount
    signal input amountRequested;      // Amount to withdraw now
    signal input spentBefore;          // Previously spent amount

    signal input pathElements[depth];  // Merkle proof elements
    signal input pathIndices[depth];   // Merkle proof indices

    // Public outputs
    signal output root;                // Merkle root
    signal output nullifierCurrent;    // Poseidon(secret, amountRequested)
    signal output amount;              // amountRequested
    signal output leafCommitment;      // Poseidon(secret, salt, amountDeposited)
    signal output spentBefore_pub;     // spentBefore
    signal output spentAfter_pub;      // spentBefore + amountRequested
    signal output amountDeposited_pub; // amountDeposited
}
```

## 🌟 Advanced Features

### **🔗 Merkle Tree Commitment**

- **Privacy Mixing**: Deposits committed to 32-level Merkle tree
- **Unlinkability**: Transaction amounts and patterns hidden via proofs
- **Scalability**: O(log n) proof size regardless of system scale
- **Anonymity**: Zero-knowledge proofs prevent correlation analysis

### **💰 Partial Withdrawal with Balance Tracking**

- **Dynamic Claims**: Withdraw any portion of deposited amount
- **Spending History**: Circuit-enforced cumulative balance tracking
- **Overdraft Prevention**: Range proofs ensure `spentAfter ≤ amountDeposited`
- **Multi-use Support**: Cards can be partially redeemed over time

### **🛡️ Enhanced Privacy Properties**

- **Non-interactive Proofs**: No on-chain coordination required
- **Forward Secrecy**: Future transactions don't reveal past activity
- **Linkage Resistance**: Impossible to correlate deposits and withdrawals

## 🏗️ Build Artifacts

### **Compilation Output**

```bash
# Active production circuit compilation
circuits/build/
├── giftcard_merkle.r1cs                     # Constraint system (~2,000+ constraints)
├── giftcard_merkle.sym                      # Debug symbols
├── giftcard_merkle_js/                      # WebAssembly witness generator
│   ├── witness_calculator.js
│   └── generate_witness.js
├── giftcard_merkle_verification_key.json    # Generated verification key
└── checksum_manifest.txt                    # Ceremony integrity proofs
```

### **Circuit Complexity**

```bash
$ snarkjs r1cs info circuits/build/giftcard_merkle.r1cs
# Circuit Summary:
# - 2,048+ constraints (Merkle tree verification)
# - Poseidon hash operations: 32 levels + 3 auxiliary
# - Range proof components: LessThan(128)
```

## 🔐 Active Trusted Setup Ceremony

### **Phase 2 Status** ✅ **ACTIVE**

- **Circuit**: `giftcard_merkle.circom` (primary production circuit)
- **Ceremony Type**: Multi-party computation with decentralized verification
- **Security Model**: Adversarial resilience with ≥1 honest participant guarantee

### **Ceremony Infrastructure**

- **Scripts**: [`../ceremony/scripts/`](../ceremony/scripts/) - Enhanced security tooling
- **Contributions**: [`../ceremony/contrib/`](../ceremony/contrib/) - User entropy submissions
- **Artifacts**: [`../ceremony/output/`](../ceremony/output/) - Verified ceremony chain
- **Verification**: [`../ceremony/scripts/verify_chain.sh`](../ceremony/scripts/verify_chain.sh)

### **GitHub Actions Orchestration**

- **Validation**: Automated cryptographic verification of each contribution
- **Aggregation**: Security-enhanced ceremony coordination
- **Auditing**: 90-day artifact retention for compliance
- **Loop Prevention**: Intelligent commit logic with exit codes

## 📚 Technical Implementation

### **Merkle Tree Structure**

```circom
// Leaf commitment: Poseidon(secret, salt, amountDeposited)
component leafHash = Poseidon(3);
leafHash.inputs[0] <== secret;
leafHash.inputs[1] <== salt;
leafHash.inputs[2] <== amountDeposited;
leafCommitment <== leafHash.out;

// 32-level Merkle proof verification
signal hash[depth + 1];
hash[0] <== leafCommitment;
// ... 32 levels of hash verification
root <== hash[depth];
```

### **Balance Management**

```circom
// Cumulative spending calculation
spentAfter <== spentBefore + amountRequested;
spentAfter_pub <== spentAfter;

// Circuit-enforced boundary check
component balanceCheck = LessThan(128);
balanceCheck.in[0] <== spentAfter;
balanceCheck.in[1] <== amountDepositedPlusOne;  // Strict inequality
balanceCheck.out === 1;  // Must be true
```

### **Nullifier System**

```circom
// Amount-specific nullifiers prevent double-withdrawal
component nullifierHash = Poseidon(2);
nullifierHash.inputs[0] <== secret;
nullifierHash.inputs[1] <== amountRequested;  // Binds to claim amount
nullifierCurrent <== nullifierHash.out;
```

## 🚀 Development & Testing

### **Compiling the Circuit**

```bash
# Generate production-ready artifacts
circom giftcard_merkle.circom --r1cs --wasm --sym -o ./build/

# Validate circuit properties
snarkjs r1cs info ./build/giftcard_merkle.r1cs
```

### **Testing Circuit Logic**

```bash
# Generate test witness for development
node -e "
const input = {
  secret: '12345',
  salt: '67890',
  amountDeposited: '1000',
  amountRequested: '300',
  spentBefore: '100',  // Already spent 100
  pathElements: new Array(32).fill('0'),
  pathIndices: new Array(32).fill('0')
};
// Test spending limit validation
"
```

### **Witness Generation**

```bash
# Use compiled WebAssembly generator
node ./build/giftcard_merkle_js/generate_witness.js \
     ./build/giftcard_merkle_js/giftcard_merkle.wasm \
     input.json \
     witness.wtns
```

## 🔧 Circuit Dependencies

- [**Circom 2.0+**](https://docs.circom.io/): Core ZK circuit compiler
- [**Circomlib**](https://github.com/iden3/circomlib/): Cryptographic standard library
  - `Poseidon(1/2/3)`: ZK-friendly hash functions
  - `LessThan(128)`: Range proof component
- [**SnarkJS**](https://github.com/iden3/snarkjs/): Ceremony and proof management

## 🎯 Use Cases

### **Production Applications**

- **Privacy-Preserving Gifts**: Anonymous token distribution
- **Micropayment Channels**: Privacy-enabled payment networks
- **Decentralized Finance**: Private DeFi primitives
- **Healthcare Tokens**: Anonymous medical credit systems
- **Voting Systems**: Private governance participation

### **Advanced ZK Protocols**

- **State Channels**: Privacy within payment networks
- **Layer 2 Solutions**: Private transaction bundling
- **Decentralized Identity**: Verifiable credentials with privacy
- **Supply Chain Tracking**: Anonymous inventory management

## 📄 Related Directories

- **[`../ceremony/`](../ceremony/)**: Active trusted setup ceremony infrastructure
- **[`circomlib/`](./circomlib/)**: Cryptographic primitive library
- **[`ptau/`](./ptau/)**: Phase 1 powers-of-tau ceremony artifacts
- **[`../README.md`](../README.md)**: Project overview and participation guide

## 🤝 Ceremony Participation

### **Contributing to Trust Setup**

```bash
# Clone repository
git clone https://github.com/your-org/lambda-zk.git
cd lambda-zk/ceremony/scripts

# Add your entropy to the ceremony
./contribute.sh

# Submit via pull request (GitHub Actions validation)
```

### **Verification & Auditing**

```bash
# Independent ceremony verification
./verify_chain.sh

# Review audit logs
ls -la ceremony_*.log

# Check checksum manifest
cat ../ceremony/output/checksum_manifest.txt
```

## 📜 Security Guarantees

- **🎲 Probabilistic Privacy**: Information-theoretically secure against < n/2 corrupt participants
- **⏰ Forward Secrecy**: Future randomness doesn't compromise past secrecy
- **🔒 Post-Quantum Resistance**: Security based on hash function assumptions
- **⚖️ Balance Control**: Circuit-enforced spending limits prevent over-withdrawal
- **🔍 Zero-Knowledge**: Only validity proven, no information leaked about secret values

## 🤝 Contributing

### **Code Contributions**

- **Circuit optimizations**: Reduce constraint count while maintaining security
- **Security analysis**: Cryptographic review and formal verification
- **Documentation**: Technical accuracy and clarity improvements
- **Testing infrastructure**: Enhanced validation and edge case coverage

### **Ceremony Participation**

- **Entropy contribution**: Strengthen the trusted setup by adding randomness
- **Independent verification**: Audit ceremony results and security properties
- **Documentation feedback**: Improve user guides and technical documentation

## 📜 License

See [`../LICENSE`](../LICENSE) for project licensing terms.

---

**This circuit powers Lambda-ZK's production-grade privacy infrastructure.** The active trusted setup ceremony ensures this Merkle tree gift card system provides **enterprise-level cryptographic privacy** for decentralized applications. 🎯🔐
