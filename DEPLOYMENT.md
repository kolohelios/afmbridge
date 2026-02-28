# AFMBridge Deployment Guide

Complete guide for deploying AFMBridge, including obtaining certificates, configuring secrets, and
creating releases.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Apple Developer Setup](#apple-developer-setup)
- [GitHub Repository Setup](#github-repository-setup)
- [Local Development Setup](#local-development-setup)
- [Creating Releases](#creating-releases)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **macOS 26.0+** (Tahoe or later) - Required for FoundationModels framework
- **Apple Silicon** (M-series chips) - Required for on-device AI
- **Xcode 16.2+** - Includes Swift 6.2.3 and macOS 26 SDK
- **Apple Developer Account** - Required for code signing and notarization

### Development Tools

- **Homebrew** - Package manager for macOS
- **Nix** - Optional, for reproducible development environment
- **Jujutsu (jj)** - Version control (project uses jj instead of git)

## Apple Developer Setup

### 1. Join Apple Developer Program

1. Go to [Apple Developer Program](https://developer.apple.com/programs/)
2. Enroll ($99/year for individuals)
3. Wait for enrollment confirmation (can take 24-48 hours)

### 2. Create Developer ID Application Certificate

This certificate is used to sign binaries for distribution outside the Mac App Store.

#### Steps:

1. **Open Keychain Access** on your Mac
2. **Request Certificate from Certificate Authority**:
   - Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
   - Enter your email address (must match Apple Developer account)
   - Select "Saved to disk"
   - Click Continue and save the `.certSigningRequest` file

3. **Create Certificate in Apple Developer Portal**:
   - Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list)
   - Click the "+" button to create a new certificate
   - Select "Developer ID Application" under "Software"
   - Upload your `.certSigningRequest` file
   - Download the certificate (`.cer` file)

4. **Install Certificate**:
   - Double-click the downloaded `.cer` file to add it to your Keychain
   - Verify it appears in Keychain Access under "My Certificates"
   - Should show as "Developer ID Application: Your Name (Team ID)"

5. **Export Certificate for GitHub Actions**:
   - In Keychain Access, find your Developer ID Application certificate
   - Right-click → Export "Developer ID Application: Your Name"
   - Choose `.p12` format
   - **Set a strong password** (you'll need this for GitHub secrets)
   - Save the `.p12` file

6. **Convert to Base64**:

   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

   This copies the base64-encoded certificate to your clipboard.

### 3. Create App-Specific Password

Apple requires an app-specific password for notarization (cannot use your main Apple ID password).

#### Steps:

1. Go to [Apple ID Account](https://appleid.apple.com/account/manage)
2. Sign in with your Apple ID
3. Under "Security" → "App-Specific Passwords" → click "Generate"
4. Enter a label (e.g., "AFMBridge Notarization")
5. **Save the generated password** - you cannot view it again!

### 4. Get Your Team ID

1. Go to [Apple Developer Membership](https://developer.apple.com/account/#!/membership)
2. Find your "Team ID" (10-character alphanumeric code)
3. Save this for GitHub secrets

## GitHub Repository Setup

### Required Secrets

The release workflow requires several secrets to be configured in your GitHub repository.

#### Navigate to Repository Secrets:

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"

#### Add These Secrets:

| Secret Name                   | Value                                      | How to Get                       |
|-------------------------------|--------------------------------------------|----------------------------------|
| `APPLE_CERTIFICATE_BASE64`    | Base64-encoded `.p12` certificate          | See [Step 2.6](#2-create-developer-id-application-certificate) |
| `APPLE_CERTIFICATE_PASSWORD`  | Password for `.p12` certificate            | Password you set in Step 2.5     |
| `KEYCHAIN_PASSWORD`           | Any strong password                        | Create a random password         |
| `APPLE_ID`                    | Your Apple ID email                        | Your developer account email     |
| `APPLE_TEAM_ID`               | Your Team ID                               | See [Step 4](#4-get-your-team-id) |
| `APPLE_ID_PASSWORD`           | App-specific password                      | See [Step 3](#3-create-app-specific-password) |

#### Example Values (for reference):

```bash
APPLE_CERTIFICATE_BASE64=MIIKzAIBAzCCCpQGCSqGSIb3DQEHAaCCCoUEggqBMII...
APPLE_CERTIFICATE_PASSWORD=YourSecureP12Password
KEYCHAIN_PASSWORD=AnyRandomPasswordForCI
APPLE_ID=your.email@example.com
APPLE_TEAM_ID=ABC123XYZ9
APPLE_ID_PASSWORD=abcd-efgh-ijkl-mnop
```

### Verify Secrets

After adding all secrets, verify they appear in:

Settings → Secrets and variables → Actions → Repository secrets

You should see 6 secrets listed (values are hidden).

## Local Development Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/afmbridge.git
cd afmbridge
```

### 2. Install Development Tools

#### With Homebrew:

```bash
# Swift formatting and linting
brew install swift-format swiftlint

# Task runner
brew install just

# Version control
brew install jj

# Optional: direnv for auto-loading environment
brew install direnv
```

#### With Nix (Alternative):

```bash
# Install Nix with flakes support
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install

# Enter development shell
nix develop

# This provides: just, markdownlint, Python SDKs
# Still need Homebrew for: swift-format, swiftlint
```

### 3. Build and Test

```bash
# Run all quality checks
just validate

# Build the project
just build

# Run tests
just test

# Start the server
just run
```

### 4. Environment Variables

For local development, create a `.env` file (not committed to git):

```bash
# Server configuration
HOST=127.0.0.1
PORT=8080
LOG_LEVEL=debug

# Optional: API key authentication
API_KEY=sk-your-development-key-here
```

Load with:

```bash
# If using direnv
direnv allow

# Or manually
source .env
just run
```

## Creating Releases

### Release Workflow

The project uses automated releases triggered by Git tags.

#### 1. Prepare Release

```bash
# Ensure all changes are committed
jj status

# Ensure all tests pass
just validate

# Update version in relevant files if needed
# (README.md, Package.swift, etc.)
```

#### 2. Create Release Tag

```bash
# Fetch latest from remote
jj git fetch

# Create annotated tag on main branch
git tag -a v1.0.0 -m "Release v1.0.0

## Features
- Full OpenAI Chat Completions API compatibility
- Full Anthropic Messages API compatibility
- Streaming support for both APIs
- Tool calling support for both APIs

## Changes
- Brief summary of changes since last version

See CHANGELOG.md for complete details."

# Push tag to trigger release
git push origin v1.0.0
```

#### 3. Monitor Release

```bash
# Watch the release workflow
gh run list --workflow=release.yml --limit 1

# View logs if needed
gh run watch <run-id>
```

#### 4. Release Workflow Steps

The automated workflow performs:

1. **Build Binary** (macOS 26 runner)
   - Builds with `swift build -c release`
   - Uses system Swift toolchain

2. **Import Signing Certificate**
   - Creates temporary keychain
   - Imports Developer ID certificate from secrets
   - Unlocks keychain for code signing

3. **Sign Binary**
   - Signs with Developer ID Application certificate
   - Applies hardened runtime options
   - Uses entitlements from `entitlements.plist`

4. **Verify Signature**
   - Runs `codesign --verify` to validate signature

5. **Notarize Binary**
   - Creates zip archive for notarization
   - Submits to Apple's notarization service
   - Waits for Apple to scan and approve
   - Typically takes 1-5 minutes

6. **Package Binary**
   - Creates `.tar.gz` archive
   - Generates SHA256 checksums

7. **Create GitHub Release**
   - Uploads binary and checksums
   - Creates release notes
   - Marks as published

### Release Artifacts

Each release includes:

- `afmbridge-macos-v{version}.tar.gz` - Signed and notarized binary
- `checksums.txt` - SHA256 checksums for verification

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major** (`v2.0.0`): Breaking API changes
- **Minor** (`v1.1.0`): New features, backwards compatible
- **Patch** (`v1.0.1`): Bug fixes, backwards compatible
- **Beta** (`v1.0.0-beta.1`): Pre-release testing

## Troubleshooting

### Code Signing Issues

#### "No Developer ID Application identity found"

**Cause:** Certificate not properly installed or exported.

**Solution:**

1. Open Keychain Access
2. Verify certificate appears under "My Certificates"
3. Re-export as `.p12` with password
4. Re-encode to base64 and update `APPLE_CERTIFICATE_BASE64` secret

#### "cannot read entitlement data"

**Cause:** `entitlements.plist` file missing from repository.

**Solution:**

1. Verify file exists: `ls -la entitlements.plist`
2. If missing, restore from git history
3. Ensure file is committed to repository

### Notarization Issues

#### "Authentication credentials invalid"

**Cause:** Wrong Apple ID credentials or app-specific password.

**Solution:**

1. Verify `APPLE_ID` matches your developer account email
2. Generate new app-specific password at appleid.apple.com
3. Update `APPLE_ID_PASSWORD` secret with new password

#### "Team ID does not match"

**Cause:** Wrong Team ID in secrets.

**Solution:**

1. Get correct Team ID from developer.apple.com/account
2. Update `APPLE_TEAM_ID` secret

#### "Notarization failed with status: Invalid"

**Cause:** Binary doesn't meet notarization requirements.

**Solution:**

1. Check notarization log: `xcrun notarytool log <submission-id>`
2. Common issues:
   - Missing entitlements
   - Unsigned dependencies
   - Incorrect bundle structure

### Build Issues

#### "Swift compiler not found"

**Cause:** Missing Xcode or wrong Swift version.

**Solution:**

```bash
# Install Xcode from App Store
# Or install Command Line Tools
xcode-select --install

# Verify Swift version
swift --version
# Should be Swift 6.2.3 or later
```

#### "FoundationModels module not found"

**Cause:** Running on macOS < 26.0

**Solution:**

- Upgrade to macOS 26.0 (Tahoe) or later
- FoundationModels is only available on macOS 26.0+

### Runtime Issues

#### "Binary cannot be opened because the developer cannot be verified"

**Cause:** Binary not properly notarized.

**Solution:**

- Verify release includes notarization step in workflow logs
- Check notarization completed successfully
- Try downloading fresh copy from GitHub Releases

#### "dyld: Library not loaded"

**Cause:** Missing system dependencies.

**Solution:**

- Ensure running on macOS 26.0+
- Ensure Xcode/Command Line Tools installed
- Check Swift runtime libraries are present

## Production Deployment

### Running as a Service

For production, run AFMBridge as a system service using launchd:

1. **Create Launch Agent** (`~/Library/LaunchAgents/com.afmbridge.plist`):

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>com.afmbridge</string>
       <key>ProgramArguments</key>
       <array>
           <string>/usr/local/bin/AFMBridge</string>
           <string>serve</string>
       </array>
       <key>EnvironmentVariables</key>
       <dict>
           <key>HOST</key>
           <string>127.0.0.1</string>
           <key>PORT</key>
           <string>8080</string>
           <key>API_KEY</key>
           <string>your-production-api-key</string>
       </dict>
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>
       <key>StandardOutPath</key>
       <string>/var/log/afmbridge.log</string>
       <key>StandardErrorPath</key>
       <string>/var/log/afmbridge.err</string>
   </dict>
   </plist>
   ```

2. **Load Service**:

   ```bash
   launchctl load ~/Library/LaunchAgents/com.afmbridge.plist
   ```

3. **Verify Running**:

   ```bash
   launchctl list | grep afmbridge
   curl http://localhost:8080/health
   ```

### Security Considerations

1. **API Key**: Always set `API_KEY` in production
2. **Network**: Bind to `127.0.0.1` for local-only access
3. **Reverse Proxy**: Use nginx/Caddy for external access with HTTPS
4. **Firewall**: Configure macOS firewall to restrict access
5. **Logs**: Rotate logs regularly to prevent disk filling

### Monitoring

Monitor server health:

```bash
# Check service status
launchctl list | grep afmbridge

# View logs
tail -f /var/log/afmbridge.log

# Test health endpoint
curl http://localhost:8080/health

# Test API endpoint
curl -H "Authorization: Bearer sk-your-key" \
     -H "Content-Type: application/json" \
     -d '{"model":"gpt-4","messages":[{"role":"user","content":"Hello"}]}' \
     http://localhost:8080/v1/chat/completions
```

## Additional Resources

- [Apple Code Signing Guide](https://developer.apple.com/documentation/security/code-signing-services)
- [Apple Notarization Overview](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [FoundationModels Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Project README](README.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Implementation Plan](PLAN.md)

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/kolohelios/afmbridge/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kolohelios/afmbridge/discussions)
- **Documentation**: Check README.md and API.md

---

**Note:** This guide assumes you are deploying on your own Mac. For multi-user deployments or
server environments, additional security hardening and access controls are recommended.
