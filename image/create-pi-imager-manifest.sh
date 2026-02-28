#!/usr/bin/env bash
# Create a Raspberry Pi Imager manifest for the Buoy custom image.
# This enables the settings gear (hostname, WiFi, SSH) when flashing.
#
# Usage:
#   ./image/create-pi-imager-manifest.sh [path-to-buoy_build.img]
#   ./image/create-pi-imager-manifest.sh --url "https://example.com/image.img.xz"
#
# Then: Pi Imager -> App Options -> Content Repository -> Use custom file
#       -> select build/buoy.rpi-imager-manifest
# Or double-click the manifest file to open it in Imager.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
OUTPUT_MANIFEST="$BUILD_DIR/buoy.rpi-imager-manifest"
FILE_URL=""

# Parse --url
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      FILE_URL="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -z "$FILE_URL" ]; then
  if [ -n "$1" ]; then
    IMG_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  else
    IMG_PATH="$BUILD_DIR/buoy_build.img"
  fi
  if [ ! -f "$IMG_PATH" ]; then
    echo "ERROR: Image not found: $IMG_PATH"
    echo "  Build first: ./image/build-with-docker.sh"
    echo "  Or pass the path: $0 /path/to/buoy_build.img"
    echo "  Or use --url for release manifests: $0 --url 'https://...'"
    exit 1
  fi
  FILE_URL="file://${IMG_PATH}"
fi

mkdir -p "$(dirname "$OUTPUT_MANIFEST")"

# init_format: cloudinit-rpi matches Raspberry Pi OS Trixie (our base)
# This enables hostname, SSH customization. Do NOT configure WiFi in the gear—
# Buoy uses wlan0 as AP; Pi Imager's WiFi would make it a client and conflict.
# Our image is based on RPi OS, so these options may apply.
cat > "$OUTPUT_MANIFEST" << EOF
{
  "os_list": [
    {
      "name": "Buoy",
      "description": "Headless ROS 2 hub with WiFi AP, .buoy DNS, command center",
      "url": "$FILE_URL",
      "init_format": "cloudinit-rpi",
      "devices": ["pi5-64bit", "pi4-64bit", "pi3-64bit"],
      "capabilities": ["rpi_connect"]
    }
  ]
}
EOF

echo "Created: $OUTPUT_MANIFEST"
echo ""
echo "To use: Pi Imager -> App Options (gear) -> Content Repository -> EDIT"
echo "        -> Use custom file -> select $OUTPUT_MANIFEST -> APPLY & RESTART"
echo ""
echo "Or double-click the manifest file to open it in Imager."
