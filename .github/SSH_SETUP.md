# GitHub Actions SSH Setup Guide

> **⚠️ URGENT: If you see "ssh-private-key argument is empty" error**
>
> The SSH_PRIVATE_KEY secret is not configured in your repository. Follow the Quick Setup below immediately.

## Quick Setup (5 minutes)

If you're seeing build failures, follow these steps right now:

### 1. Generate SSH Key (Local Machine)

```bash
ssh-keygen -t ed25519 -C "github-actions@inferx" -f ~/.ssh/id_ed25519_github_actions
# Press Enter twice (no passphrase)
```

### 2. Add Public Key to Your GitHub Account

```bash
# Copy public key
cat ~/.ssh/id_ed25519_github_actions.pub
```

Then:
- Go to: https://github.com/settings/keys
- Click "**New SSH key**"
- Title: `GitHub Actions - InferX`
- Paste the public key
- Click "**Add SSH key**"

### 3. Add Private Key to Repository Secrets

```bash
# Copy private key (entire content including headers)
cat ~/.ssh/id_ed25519_github_actions
```

Then:
- Go to: https://github.com/menriothink/InferX/settings/secrets/actions
- Click "**New repository secret**"
- Name: `SSH_PRIVATE_KEY` (exactly this name!)
- Paste the **entire private key** including:
  ```
  -----BEGIN OPENSSH PRIVATE KEY-----
  ... key content ...
  -----END OPENSSH PRIVATE KEY-----
  ```
- Click "**Add secret**"

### 4. Re-run the Failed Workflow

Go to Actions tab and click "Re-run all jobs"

---

## Why SSH Configuration is Needed

Your Xcode project uses SSH URLs for Swift Package Manager dependencies:
```
git@github.com:groue/Semaphore.git
git@github.com:apple/swift-argument-parser.git
git@github.com:ml-explore/mlx-swift-examples.git
... and others
```

GitHub Actions runners don't have SSH keys configured by default, so they can't access these repositories using SSH protocol.

## Solution: Configure SSH Key in GitHub Secrets

### Step 1: Generate SSH Key (if you don't have one)

On your local machine:

```bash
# Generate a new SSH key (use a different name to avoid overwriting existing keys)
ssh-keygen -t ed25519 -C "github-actions@inferx" -f ~/.ssh/id_ed25519_github_actions

# Don't set a passphrase (just press Enter)
```

This creates two files:
- `~/.ssh/id_ed25519_github_actions` (private key)
- `~/.ssh/id_ed25519_github_actions.pub` (public key)

### Step 2: Add Public Key to GitHub Account

1. Copy your public key:
   ```bash
   cat ~/.ssh/id_ed25519_github_actions.pub
   ```

2. Go to GitHub Settings:
   - Visit https://github.com/settings/keys
   - Click "New SSH key"
   - Title: `GitHub Actions - InferX`
   - Key type: `Authentication Key`
   - Paste the public key content
   - Click "Add SSH key"

### Step 3: Add Private Key to Repository Secrets

1. Copy your private key:
   ```bash
   cat ~/.ssh/id_ed25519_github_actions
   ```

2. Go to your repository settings:
   - Navigate to: https://github.com/menriothink/InferX/settings/secrets/actions
   - Click "New repository secret"
   - Name: `SSH_PRIVATE_KEY`
   - Value: Paste the entire private key content (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`)
   - Click "Add secret"

### Step 4: Verify Configuration

The workflows are already configured to use this SSH key:

```yaml
- name: Setup SSH for private repositories
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

This step automatically:
- Starts an SSH agent
- Loads your private key
- Configures Git to use SSH for GitHub
- Adds GitHub to known hosts

### Step 5: Test the Workflow

Push your code to GitHub:

```bash
git add .github/
git commit -m "Add SSH configuration for GitHub Actions"
git push origin master
```

The workflow will automatically run and should now successfully clone all SSH dependencies.

## Alternative: Use HTTPS Instead of SSH (Recommended for Public Repos)

If your dependencies are all public repositories, you can convert SSH URLs to HTTPS:

### Manual Conversion in Xcode:

1. Open Xcode
2. Go to File → Packages → Resolve Package Versions
3. For each package:
   - Right-click → Edit Package
   - Change URL from `git@github.com:owner/repo.git` to `https://github.com/owner/repo.git`

### Why HTTPS is Better for Public Repos:

- ✅ No SSH key configuration needed
- ✅ Works immediately on GitHub Actions
- ✅ Simpler setup
- ✅ No security secrets to manage

### When to Use SSH:

- ✅ Private repositories
- ✅ Organization internal packages
- ✅ When you need write access during build

## Troubleshooting

### Error: "Permission denied (publickey)"

**Cause:** Private key not configured correctly

**Solution:**
1. Verify the secret name is exactly `SSH_PRIVATE_KEY`
2. Ensure you copied the entire private key including headers
3. Check that the public key is added to your GitHub account

### Error: "Host key verification failed"

**Cause:** GitHub's SSH host key not in known_hosts

**Solution:** The `webfactory/ssh-agent` action handles this automatically. If you see this error, update the action:

```yaml
- name: Setup SSH for private repositories
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
```

### Build Still Fails

1. Check workflow logs in GitHub Actions
2. Verify all SSH URLs are accessible with your SSH key:
   ```bash
   # Test locally
   ssh -T git@github.com
   ```
3. Ensure your GitHub account has access to all dependency repositories

## Security Best Practices

### ✅ Do:
- Use a dedicated SSH key for GitHub Actions
- Store private key in GitHub Secrets (encrypted)
- Regularly rotate SSH keys (every 6-12 months)
- Use read-only deploy keys when possible

### ❌ Don't:
- Commit private keys to the repository
- Share the same SSH key across multiple projects
- Use SSH keys with write access unless necessary
- Set a passphrase on the key (Actions can't input it)

## Multiple Keys for Different Repositories

If you need different keys for different repositories:

```yaml
- name: Setup SSH for multiple repos
  uses: webfactory/ssh-agent@v0.9.0
  with:
    ssh-private-key: |
      ${{ secrets.SSH_PRIVATE_KEY_REPO1 }}
      ${{ secrets.SSH_PRIVATE_KEY_REPO2 }}
```

## Resources

- [webfactory/ssh-agent Action](https://github.com/webfactory/ssh-agent)
- [GitHub SSH Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Swift Package Manager SSH Guide](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)
