pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/babyjub.circom";

/**
 * GiftCardMerkleChaining(depth)
 *
 * UTXO-style commitment chaining with unlinkable partial withdrawals
 *
 * Private inputs:
 *  - oldSecret         // Secret for old commitment
 *  - oldSalt           // Salt for old commitment
 *  - oldAmount         // Total amount in old commitment
 *  - withdrawAmount    // Amount to withdraw now
 *  - newSecret         // Secret for new commitment (change)
 *  - newSalt           // Salt for new commitment
 *  - ephemeralPrivKey  // BabyJub private key for signature
 *  - pathElements[depth]  // Merkle path for old commitment
 *  - pathIndices[depth]   // Merkle path indices
 *
 * Public outputs (6):
 *  - root              // Merkle root
 *  - nullifier         // Prevents reuse of old commitment
 *  - withdrawAmount_pub // Amount being withdrawn
 *  - newCommitment     // New commitment with change (0 if full withdraw)
 *  - ephPubKeyX        // Ephemeral public key X
 *  - ephPubKeyY        // Ephemeral public key Y
 */

template GiftCardMerkle(depth) {

    // ----------- Private inputs -----------

    signal input oldSecret;
    signal input oldSalt;
    signal input oldAmount;
    signal input withdrawAmount;
    signal input newSecret;
    signal input newSalt;
    signal input ephemeralPrivKey;
    signal input pathElements[depth];
    signal input pathIndices[depth];

    // ----------- Public outputs -----------

    signal output root;
    signal output nullifier;
    signal output withdrawAmount_pub;
    signal output newCommitment;
    signal output ephPubKeyX;
    signal output ephPubKeyY;

    // ----------- BabyJubJub ephemeral key -----------

    component eph = BabyPbk();
    eph.in <== ephemeralPrivKey;
    ephPubKeyX <== eph.Ax;
    ephPubKeyY <== eph.Ay;

    // ----------- Output withdraw amount -----------

    withdrawAmount_pub <== withdrawAmount;

    // ----------- Old commitment reconstruction -----------
    // oldCommitment = Poseidon(oldSecret, oldSalt, oldAmount)

    component oldCommitHash = Poseidon(3);
    oldCommitHash.inputs[0] <== oldSecret;
    oldCommitHash.inputs[1] <== oldSalt;
    oldCommitHash.inputs[2] <== oldAmount;
    signal oldCommitment;
    oldCommitment <== oldCommitHash.out;

    // ----------- Nullifier: Prevents old commitment reuse -----------
    // nullifier = Poseidon(oldSecret, oldSalt)
    // NOTE: Different from current circuit (was Poseidon(secret, amountRequested))
    // This ensures each UTXO has unique nullifier

    component nullHash = Poseidon(2);
    nullHash.inputs[0] <== oldSecret;
    nullHash.inputs[1] <== oldSalt;
    nullifier <== nullHash.out;

    // ----------- Change amount calculation -----------

    signal changeAmount;
    changeAmount <== oldAmount - withdrawAmount;

    // Enforce: withdrawAmount <= oldAmount
    // (i.e., changeAmount >= 0)
    component lessEq = LessThan(128);
    lessEq.in[0] <== withdrawAmount;
    lessEq.in[1] <== oldAmount + 1;
    lessEq.out === 1;

    // ----------- New commitment (change) -----------
    // If changeAmount = 0 (full withdraw), newCommitment should be 0
    // If changeAmount > 0, newCommitment = Poseidon(newSecret, newSalt, changeAmount)

    component newCommitHash = Poseidon(3);
    newCommitHash.inputs[0] <== newSecret;
    newCommitHash.inputs[1] <== newSalt;
    newCommitHash.inputs[2] <== changeAmount;

    // Use selector to output 0 if changeAmount = 0, otherwise hash
    component isZero = IsZero();
    isZero.in <== changeAmount;

    // If changeAmount = 0: newCommitment = 0
    // If changeAmount > 0: newCommitment = newCommitHash.out
    newCommitment <== (1 - isZero.out) * newCommitHash.out;

    // ----------- Merkle proof for old commitment -----------

    // Validate path indices are binary (0 or 1)
    var i;
    for (i = 0; i < depth; i++) {
        pathIndices[i] * (pathIndices[i] - 1) === 0;
    }

    // Reconstruct Merkle root from old commitment
    signal hash[depth + 1];
    hash[0] <== oldCommitment;

    signal left[depth];
    signal right[depth];
    signal oneMinus[depth];

    // Helper signals to keep constraints quadratic
    signal t_left1[depth];
    signal t_left2[depth];
    signal t_right1[depth];
    signal t_right2[depth];

    component merkleHashers[depth];

    for (i = 0; i < depth; i++) {
        merkleHashers[i] = Poseidon(2);

        // oneMinus = 1 - pathIndices[i]
        oneMinus[i] <== 1 - pathIndices[i];

        // left = (1 - idx)*hash + idx*pathElement
        t_left1[i] <== oneMinus[i] * hash[i];
        t_left2[i] <== pathIndices[i] * pathElements[i];
        left[i]    <== t_left1[i] + t_left2[i];

        // right = (1 - idx)*pathElement + idx*hash
        t_right1[i] <== oneMinus[i] * pathElements[i];
        t_right2[i] <== pathIndices[i] * hash[i];
        right[i]    <== t_right1[i] + t_right2[i];

        merkleHashers[i].inputs[0] <== left[i];
        merkleHashers[i].inputs[1] <== right[i];

        hash[i + 1] <== merkleHashers[i].out;
    }

    // Final Merkle root
    root <== hash[depth];
}

// Main component: depth-32 Merkle tree
component main = GiftCardMerkle(32);
