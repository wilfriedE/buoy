---
name: buoy-image-build
description: Builds the Buoy SD card image using UV scripts and Docker. Use when building the image, modifying the build pipeline, or troubleshooting image creation.
---

# Buoy Image Build

## Quick Start

```bash
uv run build
```

Runs: download-base → build-image → create-manifest.

## Individual Steps

| Command | Purpose |
|---------|---------|
| `uv run download-base` | Fetch Raspberry Pi OS Lite 64-bit → `image/base/` |
| `uv run build-image` | Build SD image → `build/buoy_build.img` |
| `uv run create-manifest` | Write `build/buoy.rpi-imager-manifest` |

## Critical Constraints

1. **ROS image**: Built on host (not in chroot). dockerd fails in chroot (cgroups). Output: `build/docker_images.tar`.
2. **Build outputs**: All go to `build/` (gitignored).
3. **rsync exclusions** (docker-build-inner.sh): `.git`, `.venv`, `node_modules`, `build`, `*.img`, `*.img.xz`.

## Build Flow

1. `build-with-docker.sh` copies base to `build/`, pre-builds ROS image on host.
2. Chroot build runs Ansible with `docker_image_build=true` and `docker_image_prebuilt=true`.
3. `docker_images.tar` is copied into image at `/opt/buoy/docker/`.

## Troubleshooting

- **Base missing**: Run `uv run download-base` first.
- **ROS build fails**: Ensure Docker runs on host; check `image/build-with-docker.sh` for the pre-build step.
- **Chroot errors**: Verify `image/docker-build-inner.sh` rsync excludes and mount paths.
