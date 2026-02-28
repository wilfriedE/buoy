#!/usr/bin/env bash
# Create a Raspberry Pi Imager manifest for the Maser Buoy custom image.
# This enables the settings gear (hostname, WiFi, SSH) when flashing.
#
# Usage:
#   ./image/create-pi-imager-manifest.sh [path-to-maser_buoy_build.img]
#
# Then: Pi Imager -> App Options -> Content Repository -> Use custom file
#       -> select image/maser_buoy.rpi-imager-manifest
# Or double-click the manifest file to open it in Imager.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$SCRIPT_DIR"
OUTPUT_MANIFEST="$IMAGE_DIR/maser_buoy.rpi-imager-manifest"

if [ -n "$1" ]; then
  IMG_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
else
  IMG_PATH="$(cd "$IMAGE_DIR" && pwd)/maser_buoy_build.img"
fi

if [ ! -f "$IMG_PATH" ]; then
  echo "ERROR: Image not found: $IMG_PATH"
  echo "  Build first: ./image/build-with-docker.sh"
  echo "  Or pass the path: $0 /path/to/maser_buoy_build.img"
  exit 1
fi

# Pi Imager expects file:// URLs for local images
FILE_URL="file://${IMG_PATH}"

# init_format: cloudinit-rpi matches Raspberry Pi OS Trixie (our base)
# This enables hostname, SSH customization. Do NOT configure WiFi in the gear—
# Maser Buoy uses wlan0 as AP; Pi Imager's WiFi would make it a client and conflict.
# Our image is based on RPi OS, so these options may apply.
cat > "$OUTPUT_MANIFEST" << EOF
{
  "os_list": [
    {
      "name": "Maser Buoy",
      "description": "Headless ROS 2 hub with RaspAP WiFi, .buoy DNS, command center",
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
