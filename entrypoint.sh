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

# Enhanced logging and validation before installation
echo ""
echo "=== WGT Package Validation ==="
if [ -f "$WGT_FILE.wgt" ]; then
    echo "✅ WGT file exists: $WGT_FILE.wgt"
    WGT_SIZE=$(stat -c%s "$WGT_FILE.wgt" 2>/dev/null || stat -f%z "$WGT_FILE.wgt")
    echo "📊 WGT file size: $(numfmt --to=iec $WGT_SIZE)"
    
    # Validate WGT structure
    echo "🔍 Validating WGT structure..."
    if unzip -t "$WGT_FILE.wgt" > /dev/null 2>&1; then
        echo "✅ WGT file structure is valid"
        
        # Extract and examine config.xml
        echo "📋 Extracting config.xml for validation..."
        unzip -o "$WGT_FILE.wgt" config.xml -d /tmp/ 2>/dev/null
        
        if [ -f "/tmp/config.xml" ]; then
            echo "✅ config.xml found in WGT"
            
            # Parse key information from config.xml
            WIDGET_ID=$(grep -o 'id="[^"]*"' /tmp/config.xml | cut -d'"' -f2)
            WIDGET_VERSION=$(grep -o 'version="[^"]*"' /tmp/config.xml | cut -d'"' -f2) 
            APP_ID=$(grep -o '<tizen:application id="[^"]*"' /tmp/config.xml | cut -d'"' -f2)
            REQUIRED_VERSION=$(grep -o 'required_version="[^"]*"' /tmp/config.xml | cut -d'"' -f2)
            
            echo "📝 Widget ID: $WIDGET_ID"
            echo "📝 Widget Version: $WIDGET_VERSION" 
            echo "📝 App ID: $APP_ID"
            echo "📝 Required Tizen Version: $REQUIRED_VERSION"
            
            # Validate version format (x.y.z where x,y ≤ 255, z ≤ 65535)
            if [[ $WIDGET_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
                X=${BASH_REMATCH[1]}
                Y=${BASH_REMATCH[2]}
                Z=${BASH_REMATCH[3]}
                
                if [ "$X" -gt 255 ] || [ "$Y" -gt 255 ] || [ "$Z" -gt 65535 ]; then
                    echo "❌ ERROR: Version format violates Tizen constraints!"
                    echo "   x($X) and y($Y) must be ≤ 255, z($Z) must be ≤ 65535"
                    echo "   Current: $WIDGET_VERSION"
                    exit 1
                else
                    echo "✅ Version format is valid for Tizen"
                fi
            else
                echo "❌ ERROR: Version format is invalid! Must be x.y.z format"
                echo "   Current: $WIDGET_VERSION"
                exit 1
            fi
            
            # Check for required elements
            if [ -z "$WIDGET_ID" ] || [ -z "$APP_ID" ] || [ -z "$WIDGET_VERSION" ]; then
                echo "❌ ERROR: Missing required elements in config.xml"
                echo "   Widget ID: $WIDGET_ID"
                echo "   App ID: $APP_ID" 
                echo "   Version: $WIDGET_VERSION"
                exit 1
            fi
            
            echo "✅ config.xml validation passed"
            rm -f /tmp/config.xml
        else
            echo "❌ ERROR: config.xml not found in WGT package"
            exit 1
        fi
        
        # List WGT contents for debugging
        echo "📦 WGT package contents:"
        unzip -l "$WGT_FILE.wgt" | head -20
        
    else
        echo "❌ ERROR: WGT file is corrupted or invalid"
        exit 1
    fi
else
    echo "❌ ERROR: WGT file not found: $WGT_FILE.wgt"
    exit 1
fi

echo ""
echo "=== Starting Installation ==="
echo "Installing to TV: $TV_NAME"
echo "App ID will be: $APP_ID"

# Run installation with enhanced error reporting
echo "Running: tizen install -n $WGT_FILE.wgt -t \"$TV_NAME\""
if ! tizen install -n "$WGT_FILE.wgt" -t "$TV_NAME"; then
    echo ""
    echo "❌ Installation failed!"
    echo ""
    echo "🔍 Debugging Information:"
    echo "- TV Name: $TV_NAME"
    echo "- WGT File: $WGT_FILE.wgt"
    echo "- Widget ID: $WIDGET_ID"
    echo "- App ID: $APP_ID" 
    echo "- Version: $WIDGET_VERSION"
    echo "- Required Tizen: $REQUIRED_VERSION"
    echo ""
    echo "💡 Common causes of 'Parsing error -19':"
    echo "1. Version format violates Tizen limits (x,y ≤ 255, z ≤ 65535)"
    echo "2. Invalid XML syntax in config.xml"
    echo "3. Missing required config.xml elements"
    echo "4. Corrupted WGT file"
    echo "5. Incompatible Tizen version requirement"
    exit 1
else
    echo ""
    echo "🎉 Installation successful!"
    echo "✅ $WGT_FILE.wgt installed with App ID: $APP_ID"
fi
