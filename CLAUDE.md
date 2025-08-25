# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project is a generic WGT (Web Application Package) installer for Samsung Tizen TVs using Docker. It provides a configurable solution that:
- Downloads WGT packages from any GitHub repository with releases
- Connects to Samsung TVs in developer mode via SDB (Samsung Debug Bridge)
- Handles certificate signing for newer TV models that require custom certificates
- Installs any WGT app directly to the TV using environment variables for configuration

## Architecture

### Core Components
- `Dockerfile`: Based on `vitalets/tizen-webos-sdk`, includes Tizen SDK and development tools with configurable environment variables
- `entrypoint.sh`: Generic installation script that handles TV connection, package download from any GitHub repo, optional signing, and installation
- `profile.xml`: Certificate profile template for custom certificate signing
- `docker-compose.yml`: Example configuration for easy deployment with different WGT packages

### Configuration System
The installer uses environment variables for all configuration:
- `GITHUB_REPO`: Source repository (default: jeppevinkel/jellyfin-tizen-builds)
- `WGT_FILE`: WGT package name without .wgt extension (default: Jellyfin)
- `RELEASE_TAG`: Release tag or "latest" (default: latest)
- `CERTIFICATE_PASSWORD`: Password for custom certificates (optional)

### Key Dependencies
- Samsung Debug Bridge (sdb) - for TV connection and app installation
- Tizen CLI tools - for package signing and installation
- jq - for JSON parsing of TV information
- wget/curl - for downloading WGT packages from GitHub releases

## Development Commands

### Building Docker Image
```bash
docker build -t tizen-installer .
```

### Testing Installation
```bash
# Install default Jellyfin
docker run --rm ghcr.io/georift/install-jellyfin-tizen 192.168.1.100

# Install specific WGT from different repo
docker run --rm \
  -e GITHUB_REPO=your-org/your-tizen-app \
  -e WGT_FILE=YourApp \
  -e RELEASE_TAG=v1.2.3 \
  ghcr.io/georift/install-jellyfin-tizen 192.168.1.100

# With custom certificate
docker run --rm \
  -v "$(pwd)/author.p12":/certificates/author.p12 \
  -v "$(pwd)/distributor.p12":/certificates/distributor.p12 \
  -e CERTIFICATE_PASSWORD='password' \
  ghcr.io/georift/install-jellyfin-tizen 192.168.1.100
```

### Docker Compose Development
```bash
# Use provided docker-compose.yml
docker-compose up tizen-installer

# Test custom app profile
docker-compose --profile custom up custom-app
```

### Platform-Specific Testing
For ARM-based systems (Apple Silicon Macs):
```bash
docker run --rm --platform linux/amd64 ghcr.io/georift/install-jellyfin-tizen 192.168.1.100
```

### Debugging
Check if container has access to TV:
```bash
# Inside container
sdb devices
```

## Script Arguments
The entrypoint.sh script accepts these arguments (with environment variable fallbacks):
1. `TV_IP` (required) - Samsung TV IP address
2. `WGT_FILE` (optional) - WGT package name, overrides GITHUB_REPO env var
3. `RELEASE_TAG` (optional) - Release tag, overrides RELEASE_TAG env var
4. `CERTIFICATE_PASSWORD` (optional) - Certificate password, overrides CERTIFICATE_PASSWORD env var

## Configuration Priority
Configuration values are resolved in this order (highest priority first):
1. Command line arguments
2. Environment variables
3. Dockerfile defaults

## GitHub Repository Requirements
For WGT packages to be installable, the target repository must:
- Have GitHub releases with tags
- Include `.wgt` files in the release assets
- Follow the naming pattern: `{WGT_FILE}.wgt`

## Certificate Handling
- Default: Uses development certificates from Tizen SDK
- Custom: Requires author.p12 and distributor.p12 files mounted at `/certificates/`
- Profile template (`profile.xml`) gets populated with certificate password and merged into Tizen profile

## Error Handling Patterns
The script includes specific error handling for:
- Missing TV IP argument
- Failed TV connection/discovery
- Invalid GitHub repositories or release tags
- Missing certificate files when password provided
- Package download failures from GitHub

## Testing Considerations
- Requires actual Samsung TV in developer mode for full testing
- SDB connection depends on network configuration
- Certificate signing requires valid Samsung developer certificates
- Different TV models may have different behaviors
- GitHub API rate limits may affect release discovery