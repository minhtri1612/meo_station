# 🔴 SECURITY FIX - RSA Key Exposed

## ✅ What I Just Fixed:
1. Removed `terraform-infra/k8s-key.pem` from Git tracking
2. Added `*.pem` and `*.key` to `.gitignore`

## ⚠️ CRITICAL: Key Was Already Exposed

**The key is still in Git history!** You MUST:

### Step 1: Regenerate the Key (MANDATORY)

Since the key was exposed on GitHub, **regenerate it immediately**:

```bash
cd terraform-infra

# Delete the old key (if you want)
rm -f k8s-key.pem

# Terraform will regenerate it on next apply
# OR manually:
ssh-keygen -t rsa -b 4096 -f k8s-key.pem -N ""
```

### Step 2: Commit the Removal

```bash
git add .gitignore
git commit -m "SECURITY: Remove exposed private key from repository"
git push
```

### Step 3: Rotate Keys on AWS

If the key was used for AWS access:
1. Go to AWS EC2 → Key Pairs
2. Delete the old key pair
3. Create a new one
4. Update Terraform with new key name

### Step 4: Clean Git History (Optional but Recommended)

The key is still in Git history. To completely remove it:

**Option A: Using git filter-branch (built-in)**
```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch terraform-infra/k8s-key.pem" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (WARNING: rewrites history)
git push origin --force --all
```

**Option B: Using BFG Repo-Cleaner (easier)**
```bash
# Download BFG
wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar

# Remove file from history
java -jar bfg-1.14.0.jar --delete-files k8s-key.pem

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push origin --force --all
```

**⚠️ WARNING:** Force pushing rewrites history. If others use the repo, coordinate with them first!

### Step 5: Verify

```bash
# Check it's no longer tracked
git ls-files | grep k8s-key.pem

# Should return nothing!
```

## Prevention for Future:

1. **Never commit private keys**
2. **Use environment variables or secrets management**
3. **Pre-commit hooks** to prevent committing keys
4. **GitGuardian or similar tools** to scan before push


