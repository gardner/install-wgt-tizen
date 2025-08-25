#!/bin/bash

# Environment variables with defaults
GITHUB_REPO="${GITHUB_REPO:-jeppevinkel/jellyfin-tizen-builds}"
WGT_FILE="${WGT_FILE:-Jellyfin}"
RELEASE_TAG="${RELEASE_TAG:-latest}"
CERTIFICATE_PASSWORD="${CERTIFICATE_PASSWORD:-}"

if [ -z "$1" ]; then
    echo "Please pass the IP address of your Samsung TV as part of the commandline arguments for this script.";
    echo "Usage: $0 <TV_IP> [WGT_FILE] [RELEASE_TAG] [CERTIFICATE_PASSWORD]";
    echo "Or use environment variables: GITHUB_REPO, WGT_FILE, RELEASE_TAG, CERTIFICATE_PASSWORD";
		exit 1;
fi

# Override defaults with command line arguments if provided
WGT_FILE="${2:-$WGT_FILE}";
RELEASE_TAG="${3:-$RELEASE_TAG}";
CERTIFICATE_PASSWORD="${4:-$CERTIFICATE_PASSWORD}";

# Construct release URL
if [ "$RELEASE_TAG" = "latest" ]; then
    TAG_URL="https://github.com/$GITHUB_REPO/releases/latest"
else
    TAG_URL="https://github.com/$GITHUB_REPO/releases/tag/$RELEASE_TAG"
fi

echo "Using repository: $GITHUB_REPO";
echo "Using WGT file: $WGT_FILE";
echo "Using release: $RELEASE_TAG";

if [ "$RELEASE_TAG" = "latest" ]; then
	FULL_TAG_URL=$(curl -sLI $TAG_URL | grep -i 'location:' | sed -e 's/^[Ll]ocation: //g' | tr -d '\r');

	# Check if FULL_TAG_URL is not empty and valid
	if [ -z "$FULL_TAG_URL" ]; then
		echo "Error: Could not fetch the latest tag URL from $TAG_URL"
		exit 1
	fi
 
	TAG=$(basename "$FULL_TAG_URL");
	echo "Resolved latest version to: $TAG";
else
	TAG="$RELEASE_TAG"
fi

if [ -z "$CERTIFICATE_PASSWORD" ]; then
	echo "Certificate information not provided, using default dev certificate."
else
	if [ -f /certificates/author.p12 ] && [ -f /certificates/distributor.p12 ]; then
		echo "Using custom certificates with provided password."
	else
		echo "Certificate password provided but certificate files not found at /certificates/"
		exit 1
	fi
fi	

DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG/$WGT_FILE.wgt";

echo ""
echo "Using WGT package: $WGT_FILE.wgt";
echo "From repository: $GITHUB_REPO";
echo "Release: $TAG";
echo "Download URL: $DOWNLOAD_URL";
echo ""

TV_IP="$1";

echo "Attempting to connect to Samsung TV at IP address $TV_IP"
sdb connect $1

echo "Attempting to get the TV name..."
TV_NAME=$(sdb devices | grep -E 'device\s+\w+[-]?\w+' -o | sed 's/device//' - | xargs)

if [ -z "$TV_NAME" ]; then
    echo "We were unable to find the TV name.";
		exit 1;
fi
echo "Found TV name: $TV_NAME"

echo "Downloading $WGT_FILE.wgt from $GITHUB_REPO release: $TAG"
wget -q --show-progress "$DOWNLOAD_URL"; echo ""

if ! [ -z "$CERTIFICATE_PASSWORD" ]; then
	echo "Attempting to sign package using provided certificate"
	sed -i "s/_CERTIFICATEPASSWORD_/$CERTIFICATE_PASSWORD/" profile.xml
	sed -i '/<\/profile>/ r profile.xml' /home/developer/tizen-studio-data/profile/profiles.xml
	tizen package -t wgt -s custom -- $WGT_FILE.wgt
fi

echo "Attempting to install $WGT_FILE.wgt from release: $TAG"
tizen install -n $WGT_FILE.wgt -t "$TV_NAME"
