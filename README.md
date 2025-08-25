# Generic Tizen WGT Installer

This project makes it easy to install any WGT (Web Application Package) file to Samsung Tizen TVs by automating the environment configuration with Docker.

Samsung TVs have been running Tizen OS since 2015. This tool can install any WGT package from GitHub releases, making it useful for installing various Tizen applications including Jellyfin, custom apps, or development builds.

Install any WGT package to your TV with a simple Docker command or docker-compose configuration once your computer and TV are configured as described below.

## Configure Computer (PC, Laptop, etc...)
- Follow [Docker Installation Instructions](https://www.docker.com/get-started/)
- Enable any necessary [Virtualization](https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-11-pcs-c5578302-6e43-4b4b-a449-8ced115f58e1) features.
- Ensure you are on the same network as the TV you are trying to install the app to.

## Configure Samsung TV

#### Place TV in Developer Mode

> [!NOTE]
> If the TV is set to use a Right-to-left language (Arabic, Hebrew, etc). You need to enter the IP address on the TV backwards. [Read more.](https://github.com/gardner/install-wgt-tizen/issues/30)
- On the TV, open the "Smart Hub".
- Select the "Apps" panel.
- Press the "123" button (or if your remote doesn't have this button, long press the Home button) before typing "12345" with the on-screen keyboard.
- Toggle the `Developer` button to `On`.
- Enter the `Host PC IP` address of the device you're running this container on.
    > Troubleshooting Tip: If the on-screen keyboard will not pop up or if it does pop up but nothing is being entered while typing then please use either an external Bluetooth keyboard or follow these instructions to utilize the virtual keyboard from the Samsung SmartThings app (available on iOS or Android). Download the SmartThings app from your app store. Sign into your Samsung account on your TV and SmartThings app. Open the SmartThings app. Grant the requested permissions. On the bottom toolbar select `Devices`, select the `+` icon, select `Samsung Devices Add`, select `TV` then wait and select your TV (it may hang during pairing but still work if you navigate back to `Devices`). Select your TV widget (the widget may briefly display 'downloading') and the virtual remote should appear shortly. Swipe up to maximize the virtual remote—you should see a bottom section appear. Swipe on the bottom section of the virtual device until you find the numeric keypad. Enter the Host PC IP address with the virtual numeric keyboard. Enter the IP address and then select `Okay`. Now run the docker command described below. (This issue has been documented on the UN43TU7000G/UN55AU8000B and likely exists on other models as well.)

#### Uninstall Existing Jellyfin Installations, If Required

Follow the [Samsung uninstall instructions](https://www.samsung.com/in/support/tv-audio-video/how-to-uninstall-an-app-on-samsung-smart-tv/)

#### Find IP Address

- Exact instructions will vary with the model of TV. In general you can find the TV's IP address in Settings under Networking or About. Plenty of guides are availble with a quick search, however for brevity a short guide with pictures can be found [here](https://www.techsolutions.support.com/how-to/how-to-check-connection-on-samsung-smart-tv-10925).

- Make a note of the IP address as it will be needed later. 

## Install WGT Package

### Quick Installation

Install any WGT package by specifying the TV IP and optionally the GitHub repository, WGT file name, and release:

```bash
# Install default Jellyfin
docker run --rm ghcr.io/gardner/install-wgt-tizen 192.168.1.100

# Install specific WGT file and release
docker run --rm \
  -e GITHUB_REPO=your-org/your-tizen-app \
  -e WGT_FILE=YourApp \
  -e RELEASE_TAG=v1.2.3 \
  ghcr.io/gardner/install-wgt-tizen 192.168.1.100

# Using command line arguments (legacy method)
docker run --rm ghcr.io/gardner/install-wgt-tizen 192.168.1.100 YourApp v1.2.3
```

### Docker Compose (Recommended)

Create or modify `docker-compose.yml`:

```yaml
version: '3.8'
services:
  jellyfin-installer:
    image: ghcr.io/gardner/install-wgt-tizen
    environment:
      - GITHUB_REPO=jeppevinkel/jellyfin-tizen-builds
      - WGT_FILE=Jellyfin-TrueHD
      - RELEASE_TAG=latest
    command: ["192.168.1.100"]
  
  custom-app-installer:
    image: ghcr.io/gardner/install-wgt-tizen
    environment:
      - GITHUB_REPO=your-org/custom-tizen-app
      - WGT_FILE=CustomApp
      - RELEASE_TAG=v2.1.0
    command: ["192.168.1.100"]
    profiles: ["custom"]
```

Run with:
```bash
# Install Jellyfin
docker-compose up jellyfin-installer

# Install custom app
docker-compose --profile custom up custom-app-installer
```

### Configuration Options

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `GITHUB_REPO` | `jeppevinkel/jellyfin-tizen-builds` | GitHub repository (owner/repo) |
| `WGT_FILE` | `Jellyfin` | WGT file name without .wgt extension |
| `RELEASE_TAG` | `latest` | Release tag or "latest" |
| `CERTIFICATE_PASSWORD` | (empty) | Password for custom certificates |

### Custom Certificates

For newer TV models requiring custom certificates:

```bash
docker run --rm \
  -v "$(pwd)/author.p12":/certificates/author.p12 \
  -v "$(pwd)/distributor.p12":/certificates/distributor.p12 \
  -e CERTIFICATE_PASSWORD='YourPassword' \
  ghcr.io/gardner/install-wgt-tizen 192.168.1.100
```

### Validating Success
#### Common Errors

- `library initialization failed - unable to allocate file descriptor table - out of memory`

  Add `--ulimit nofile=1024:65536` to the `docker run` command:

  ```bash
  docker run --ulimit nofile=1024:65536 --rm ghcr.io/georift/install-jellyfin-tizen <samsung tv ip> <build option> <tag url>
  ```

- `install failed[118, -11], reason: Author certificate not match :`

  Uninstall the Jellyfin application from your Samsung TV, and run the installation again.

#### Success

If everything went well, you should see docker output something like the following

```txt
Installed the package: Id(AprZAARz4r.Jellyfin)
Tizen application is successfully installed.
Total time: 00:00:12.205
```

At this point you can find the installed app on your TV by navigating to Apps -> Downloaded (scroll down).

## Supported Platforms

This tool works on any amd64 based system. For ARM-based systems (Apple Silicon Macs, Raspberry Pi, etc.), use the `--platform linux/amd64` flag:

### ARM (Apple Silicon Macs, etc.)
- Ensure Docker has the "Virtualization Framework" enabled
- Verify QEMU support: `docker run --rm --platform linux/amd64 alpine uname -m` (should output **x86_64**)

Use platform flag:
```bash
docker run --rm --platform linux/amd64 ghcr.io/gardner/install-wgt-tizen 192.168.1.100
```

Or in docker-compose.yml:
```yaml
services:
  installer:
    image: ghcr.io/gardner/install-wgt-tizen
    platform: linux/amd64
```

- `install failed[118, -12], reason: Check certificate error : :Invalid certificate chain with certificate in signature.`

  Recent TV models require the installation packages to be signed with a custom certificate for your specific TV.

  See [official documentation](https://developer.samsung.com/smarttv/develop/getting-started/setting-up-sdk/creating-certificates.html) on creating your certificate and use the custom certificate arguments.

## Examples

### Install Jellyfin (Default)
```bash
docker run --rm ghcr.io/gardner/install-wgt-tizen 192.168.1.100
```

### Install Different Jellyfin Build
```bash
docker run --rm -e WGT_FILE=Jellyfin-TrueHD ghcr.io/gardner/install-wgt-tizen 192.168.1.100
```

### Install Custom Tizen App
```bash
docker run --rm \
  -e GITHUB_REPO=your-username/your-tizen-app \
  -e WGT_FILE=YourAppName \
  -e RELEASE_TAG=v1.0.0 \
  ghcr.io/gardner/install-wgt-tizen 192.168.1.100
```

## CI/CD and Container Registry

This project uses GitHub Actions to automatically build and publish Docker images to multiple registries:

- **GitHub Container Registry (GHCR)**: `ghcr.io/gardner/install-wgt-tizen`
- **Docker Hub**: `docker.io/gardner/install-wgt-tizen`

### Required Secrets

To enable automatic publishing, configure these repository secrets:

| Secret | Description | Required For |
|--------|-------------|--------------|
| `DOCKERHUB_USERNAME` | Docker Hub username | Docker Hub publishing |
| `DOCKERHUB_TOKEN` | Docker Hub access token | Docker Hub publishing |

**Note**: GHCR publishing uses the built-in `GITHUB_TOKEN` and requires no additional secrets.

### Supported Platforms

The CI builds for x86_64 architecture only:
- `linux/amd64` - x86_64 systems

**Note**: ARM64 builds are not supported because the Tizen Studio SDK contains x86-64 binaries that cannot run on ARM64 architecture.

### Automatic Tagging

Images are tagged based on Git events:
- `latest` - Latest commit on main branch
- `main`, `develop` - Branch names
- `v1.0.0` - Git tags (semver)
- `pr-123` - Pull request numbers

## Credits

This project is possible thanks to these projects:

- [jellyfin-tizen](https://github.com/jellyfin/jellyfin-tizen) - Original Jellyfin Tizen app
- [jeppevinkel/jellyfin-tizen-builds](https://github.com/jeppevinkel/jellyfin-tizen-builds) - Pre-built Jellyfin packages
- [vitalets/docker-tizen-webos-sdk](https://github.com/vitalets/docker-tizen-webos-sdk) - Docker container with Tizen SDK
