pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/babyjub.circom";

/**
 * GiftCardMerkle(depth)
 *
 * Private inputs:
 *  - secret
 *  - salt
 *  - amountDeposited
 *  - amountRequested
 *  - spentBefore
 *  - ephemeralPrivKey   (BabyJubJub private key)
 *  - pathElements[i]
 *  - pathIndices[i]
 *
 * Public outputs (9):
 *  - root
 *  - nullifierCurrent         = Poseidon(secret, amountRequested)
 *  - amount                   = amountRequested
 *  - leafCommitment           = Poseidon(secret, salt, amountDeposited)
 *  - spentBefore_pub
 *  - spentAfter_pub           = spentBefore + amountRequested
 *  - amountDeposited_pub
 *  - ephPubKeyX               = BabyJub public key X from ephemeralPrivKey
 *  - ephPubKeyY               = BabyJub public key Y from ephemeralPrivKey
 */

template GiftCardMerkle(depth) {

    // ----------- Private inputs -----------

    signal input secret;
    signal input salt;
    signal input amountDeposited;
    signal input amountRequested;
    signal input spentBefore;

    // BabyJubJub private key for the ephemeral recipient wallet
    signal input ephemeralPrivKey;

    // Merkle path inputs for the commitment
    signal input pathElements[depth];
    signal input pathIndices[depth];

    // ----------- Public outputs -----------

    // Merkle root of the tree
    signal output root;

    // Nullifier for this claim: Poseidon(secret, amountRequested)
    signal output nullifierCurrent;

    // Public requested amount
    signal output amount;

    // Commitment leaf = Poseidon(secret, salt, amountDeposited)
    signal output leafCommitment;

    // Public view of spentBefore/spentAfter and deposited amount
    signal output spentBefore_pub;
    signal output spentAfter_pub;
    signal output amountDeposited_pub;

    // Ephemeral BabyJub public key (to be used by Solidity withdrawer)
    signal output ephPubKeyX;
    signal output ephPubKeyY;

    // -----------------------------------------------
    // BabyJubJub public key derivation
    // -----------------------------------------------
    // Derive BabyJub public key (Ax, Ay) from ephemeralPrivKey using BabyPbk()
    component eph = BabyPbk();
    eph.in <== ephemeralPrivKey;

    // Expose public key coordinates as public outputs
    ephPubKeyX <== eph.Ax;
    ephPubKeyY <== eph.Ay;

    // ----------- Mirror scalar values to public outputs -----------

    // Expose requested amount as a public signal
    amount <== amountRequested;

    // Expose previous spent amount and total deposited as public
    spentBefore_pub <== spentBefore;
    amountDeposited_pub <== amountDeposited;

    // ----------- Nullifier: Poseidon(secret, amountRequested) -----------

    component nullHash = Poseidon(2);
    nullHash.inputs[0] <== secret;
    nullHash.inputs[1] <== amountRequested;
    nullifierCurrent <== nullHash.out;

    // ----------- Spend tracking -----------

    // Compute new spent amount: spentAfter = spentBefore + amountRequested
    signal spentAfter;
    spentAfter <== spentBefore + amountRequested;
    spentAfter_pub <== spentAfter;

    // Enforce: spentAfter <= amountDeposited
    // We do this by checking spentAfter < amountDeposited + 1
    signal amountDepositedPlusOne;
    amountDepositedPlusOne <== amountDeposited + 1;

    component less = LessThan(128);
    less.in[0] <== spentAfter;
    less.in[1] <== amountDepositedPlusOne;
    less.out === 1;

    // ----------- Leaf commitment -----------
    // leafCommitment = Poseidon(secret, salt, amountDeposited)

    component leafHash = Poseidon(3);
    leafHash.inputs[0] <== secret;
    leafHash.inputs[1] <== salt;
    leafHash.inputs[2] <== amountDeposited;
    leafCommitment <== leafHash.out;

    // ----------- Merkle path reconstruction -----------

    var i;

    // Ensure pathIndices are valid booleans (0 or 1)
    for (i = 0; i < depth; i++) {
        pathIndices[i] * (pathIndices[i] - 1) === 0;
    }

    // hash[0] = leafCommitment; hash[i+1] = Poseidon(left[i], right[i])
    signal hash[depth + 1];
    hash[0] <== leafCommitment;

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
