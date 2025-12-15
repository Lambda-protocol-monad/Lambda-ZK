# 🤝 How to Contribute

## 🎯 Add Your Entropy (3 Steps)

### 1. Setup

```bash
npm install -g snarkjs
git clone https://github.com/YOUR_USERNAME/test-zk-.git
cd test-zk-/ceremony/scripts
```

### 2. Generate Contribution

```bash
./contribute.sh
```

Creates: `ceremony/contrib/giftcard_merkle_tmp_XXXXXXXX.zkey`

### 3. Submit Pull Request

```bash
git checkout -b my-contribution
git add ceremony/contrib/giftcard_merkle_tmp_*.zkey
git commit -m "Add entropy"
git push origin my-contribution
```

Then create PR on GitHub.

---

## ✅ That's It!

The system automatically:
- Verifies your contribution cryptographically
- Merges if valid (3-5 minutes)
- Adds to ceremony chain
- Cleans up temporary files

---

## ❓ Common Questions

**Q: What if someone submits at the same time?**
A: Both work fine. System processes them in order.

**Q: Can I contribute multiple times?**
A: Yes! Max 5 per 24 hours.

**Q: My PR failed?**
A: Check the error. Usually:
- File in wrong location (use `ceremony/contrib/`)
- Account < 7 days old
- File corrupted (< 100KB)

---

## 🛡️ Security

Every contribution is checked for:
- Valid cryptography
- Latest ceremony state
- No malicious modifications

**Rate limits:**
- 5 contributions / 24 hours
- Account > 7 days old

---

## 💻 Code Contributions

To improve the ceremony code:

1. Fork & clone
2. Make changes
3. Test: `./verify_chain.sh`
4. Submit PR with description

**Guidelines:** Security first, test thoroughly, keep it simple.

---

## 🙏 Thanks!

You're helping secure Lambda-ZK! 🚀
