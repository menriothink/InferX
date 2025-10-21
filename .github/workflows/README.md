# InferX GitHub Actions Configuration

This directory contains GitHub Actions workflows for continuous integration and deployment.

## Workflows

### 1. Build and Test (`build.yml`)

**Triggers:**
- Push to `main`, `master`, or `dev` branches
- Pull requests to `main` or `master`

**Actions:**
- Checks out code
- Sets up Xcode 16.2
- Builds the project
- Runs unit tests
- Archives build logs

**Status Badge:**
```markdown
[![Build Status](https://github.com/menriothink/InferX/workflows/Build%20and%20Test/badge.svg)](https://github.com/menriothink/InferX/actions)
```

### 2. Release Build (`release.yml`)

**Triggers:**
- Push tags matching `v*.*.*` (e.g., v1.0.0)

**Actions:**
- Builds release version
- Creates DMG installer
- Generates release notes
- Creates GitHub Release
- Uploads artifacts

**Usage:**
```bash
# Create and push a tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### 3. Code Quality (`code-quality.yml`)

**Triggers:**
- Push to `main`, `master`, or `dev` branches
- Pull requests to `main` or `master`

**Actions:**
- Runs SwiftLint for code style checking
- Performs static analysis with Xcode analyzer

## Setup Instructions

### 1. Configure SSH Access for Private Dependencies

**Important:** This project uses SSH URLs for Swift Package dependencies. You must configure SSH access before the workflows can run successfully.

See [**SSH_SETUP.md**](../SSH_SETUP.md) for complete instructions.

**Quick Setup:**

1. Generate SSH key:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions@inferx" -f ~/.ssh/id_ed25519_github_actions
   ```

2. Add public key to GitHub account:
   - https://github.com/settings/keys

3. Add private key to repository secrets:
   - Go to: https://github.com/menriothink/InferX/settings/secrets/actions
   - Create secret named `SSH_PRIVATE_KEY`
   - Paste the entire private key content

### 2. Enable GitHub Actions

1. Go to your repository settings
2. Navigate to "Actions" → "General"
3. Enable "Allow all actions and reusable workflows"

### 2. Add Status Badges to README

Add these badges to your README.md:

```markdown
[![Build Status](https://github.com/menriothink/InferX/workflows/Build%20and%20Test/badge.svg)](https://github.com/menriothink/InferX/actions)
[![Release](https://img.shields.io/github/v/release/menriothink/InferX)](https://github.com/menriothink/InferX/releases)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
```

### 3. Configure Branch Protection (Optional)

Protect your main branch:
1. Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Check "Require status checks to pass before merging"
4. Select "Build and Test" workflow

### 4. Code Signing (Optional)

For signed releases, add secrets:
1. Settings → Secrets and variables → Actions
2. Add these secrets:
   - `CERTIFICATE_P12` (Base64 encoded)
   - `CERTIFICATE_PASSWORD`
   - `KEYCHAIN_PASSWORD`
   - `APPLE_ID`
   - `APPLE_PASSWORD`

## Local Testing

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act

# Run build workflow
act push

# Run specific job
act -j build
```

## Troubleshooting

### Xcode Version Issues

If Xcode 16.2 is not available on GitHub runners:

```yaml
- name: Select Xcode version
  run: sudo xcode-select -s /Applications/Xcode_16.0.app/Contents/Developer
```

Available versions: https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md

### Code Signing Errors

For unsigned builds, ensure these flags are set:

```yaml
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO
```

### Build Performance

To speed up builds:
1. Use build caching
2. Reduce test scope for PRs
3. Use matrix builds for multiple configurations

## Workflow Permissions

Required permissions for workflows:

```yaml
permissions:
  contents: write  # For creating releases
  checks: write    # For publishing test results
  pull-requests: write  # For PR comments
```

## Further Reading

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Xcode on GitHub Actions](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md)
- [Publishing Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
