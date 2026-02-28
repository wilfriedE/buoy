#!/usr/bin/env bash
# Build the Maser Buoy Raspberry Pi image using a privileged Docker container
# (QEMU user-mode + chroot). Requires Docker Desktop (or any Docker with
# privileged mode and loop device support).
#
# Usage:
#   ./image/build-with-docker.sh [path-to-raspios-lite.img]
#
# If no path is given, looks for image/*.img or image/*.img.xz (Raspberry Pi OS
# 64-bit Trixie Lite). Output: image/maser_buoy_build.img

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_DIR="$SCRIPT_DIR"
OUTPUT_IMG="$IMAGE_DIR/maser_buoy_build.img"

# --- Check Docker ---
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed or not in PATH. Install Docker Desktop and try again."
  exit 1
fi
if ! docker info &>/dev/null; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop and try again."
  exit 1
fi

# --- Resolve input image ---
if [ -n "$1" ]; then
  INPUT_IMG="$1"
  if [ ! -f "$INPUT_IMG" ]; then
    echo "ERROR: Image file not found: $INPUT_IMG"
    exit 1
  fi
else
  # Look for .img or .img.xz in image/
  INPUT_IMG=""
  for f in "$IMAGE_DIR"/*.img "$IMAGE_DIR"/*.img.xz; do
    [ -e "$f" ] && INPUT_IMG="$f" && break
  done
  if [ -z "$INPUT_IMG" ]; then
    echo "ERROR: No Raspberry Pi OS image found."
    echo "  Download Raspberry Pi OS 64-bit (Trixie) Lite from:"
    echo "  https://www.raspberrypi.com/software/operating-systems/"
    echo "  Place the .img or .img.xz file in: $IMAGE_DIR/"
    echo "  Or pass the path as an argument: $0 /path/to/raspios-lite.img"
    exit 1
  fi
fi

# --- Decompress if needed ---
if [[ "$INPUT_IMG" == *.xz ]]; then
  echo "[*] Decompressing $(basename "$INPUT_IMG")..."
  DECOMPRESSED="${INPUT_IMG%.xz}"
  xz -dk "$INPUT_IMG" 2>/dev/null || xz -dc "$INPUT_IMG" > "$DECOMPRESSED"
  INPUT_IMG="$DECOMPRESSED"
fi

# --- Create writable copy so we don't modify the original ---
echo "[*] Creating writable copy: maser_buoy_build.img"
cp -f "$INPUT_IMG" "$OUTPUT_IMG"

# --- Pre-pull RaspAP Docker image so the baked image works offline on first boot ---
RASPAP_TAR="$IMAGE_DIR/raspap-docker.tar"
if [ ! -f "$RASPAP_TAR" ]; then
  echo "[*] Pulling RaspAP Docker image (linux/arm64) for offline first boot..."
  docker pull --platform linux/arm64 ghcr.io/raspap/raspap-docker:latest
  docker save -o "$RASPAP_TAR" ghcr.io/raspap/raspap-docker:latest
else
  echo "[*] Using existing RaspAP image tarball (delete to re-pull): $RASPAP_TAR"
fi

# --- Run privileged container ---
echo "[*] Running build in Docker (this may take a long time)..."
docker run --rm --privileged \
  -v "$REPO_ROOT:/repo:ro" \
  -v "$IMAGE_DIR:/work:rw" \
  -v "$SCRIPT_DIR/docker-build-inner.sh:/run-inner.sh:ro" \
  -e "IMG=/work/maser_buoy_build.img" \
  debian:trixie \
  bash /run-inner.sh

echo ""
echo "Done. Flash this image to your SD card:"
echo "  $OUTPUT_IMG"
echo ""
echo "Use Raspberry Pi Imager -> 'Use custom' and select the file above, or:"
echo "  dd if=$OUTPUT_IMG of=/dev/sdX bs=4M status=progress  # Linux; replace sdX with your card"
echo ""
