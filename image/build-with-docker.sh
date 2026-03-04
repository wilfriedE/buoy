#!/usr/bin/env bash
# Build the Buoy Raspberry Pi image using a privileged Docker container
# (QEMU user-mode + chroot). Requires Docker Desktop (or any Docker with
# privileged mode and loop device support).
#
# Usage:
#   ./image/build-with-docker.sh [path-to-raspios-lite.img]
#
# If no path is given, looks for image/*.img or image/*.img.xz (Raspberry Pi OS
# 64-bit Trixie Lite). Output: build/buoy_build.img

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_DIR="$SCRIPT_DIR"
BUILD_DIR="$REPO_ROOT/build"
OUTPUT_IMG="$BUILD_DIR/buoy_build.img"
[ -n "${BUOY_LLM}" ] && OUTPUT_IMG="$BUILD_DIR/buoy_build_llm.img"

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
  # Look for .img or .img.xz in image/base/ first, then image/
  INPUT_IMG=""
  for f in "$IMAGE_DIR"/base/*.img "$IMAGE_DIR"/base/*.img.xz \
           "$IMAGE_DIR"/*.img "$IMAGE_DIR"/*.img.xz; do
    [ -e "$f" ] && INPUT_IMG="$f" && break
  done
  if [ -z "$INPUT_IMG" ]; then
    echo "ERROR: No Raspberry Pi OS image found."
    echo "  Download the base image:  uv run download-base"
    echo "  Or manually from: https://www.raspberrypi.com/software/operating-systems/"
    echo "  Place the .img or .img.xz in image/base/ or pass: $0 /path/to/raspios-lite.img"
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

# --- Create build directory ---
mkdir -p "$BUILD_DIR"

# --- Create writable copy so we don't modify the original ---
echo "[*] Creating writable copy: $(basename "$OUTPUT_IMG")"
cp -f "$INPUT_IMG" "$OUTPUT_IMG"

# --- Build ROS image on host (chroot cannot run dockerd; socket bind-mount is unreliable) ---
echo "[*] Building ROS image for arm64 (on host Docker)..."
if [ -n "${BUOY_LLM}" ]; then
  echo "[*] LLM variant: building Ollama, Whisper, LLM node..."
  mkdir -p "$BUILD_DIR/ollama"
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$BUILD_DIR:/work:rw" \
    -e BUOY_LLM=1 \
    -e "WORK_HOST=$BUILD_DIR" \
    docker:latest \
    sh -c 'cd /repo/docker && docker compose build && docker compose --profile llm build && docker pull ollama/ollama:latest && docker run --rm -v "${WORK_HOST}/ollama:/root/.ollama" --entrypoint sh ollama/ollama:latest -c "ollama serve & count=0; until ollama list 2>/dev/null || [ \$count -ge 120 ]; do sleep 1; count=\$((count+1)); done; [ \$count -ge 120 ] && { echo \"Timeout waiting for Ollama\"; exit 1; }; ollama pull llava:7b" && docker save -o /work/docker_images.tar docker-ros2_rosbridge:latest ollama/ollama:latest docker-whisper:latest docker-llm_node:latest'
else
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$REPO_ROOT:/repo:ro" \
    -v "$BUILD_DIR:/work:rw" \
    docker:latest \
    sh -c 'cd /repo/docker && docker compose build && docker save -o /work/docker_images.tar docker-ros2_rosbridge:latest'
fi

# --- Run privileged container ---
# IMG must be the path inside the container (/work), not the host path
IMG_IN_CONTAINER="/work/$(basename "$OUTPUT_IMG")"
echo "[*] Running image build in Docker (this may take a long time)..."
docker run --rm --privileged --cgroupns=host \
  -v "$REPO_ROOT:/repo:ro" \
  -v "$BUILD_DIR:/work:rw" \
  -v "$SCRIPT_DIR/docker-build-inner.sh:/run-inner.sh:ro" \
  -e "IMG=$IMG_IN_CONTAINER" \
  -e "BUOY_LLM=$BUOY_LLM" \
  debian:trixie \
  bash /run-inner.sh

echo ""
echo "Done. Flash this image to your SD card:"
echo "  $OUTPUT_IMG"
echo ""
echo "Use Raspberry Pi Imager -> 'Use custom' and select the file above, or:"
echo "  dd if=$OUTPUT_IMG of=/dev/sdX bs=4M status=progress  # Linux; replace sdX with your card"
echo ""
