#!/usr/bin/env python3
"""
Create Raspberry Pi Imager manifest for the Maser Buoy image.

Thin wrapper around image/create-pi-imager-manifest.sh. Enables the settings
gear (hostname, SSH) when flashing with Pi Imager.

Usage:
  uv run create-manifest
  uv run create-manifest /path/to/maser_buoy_build.img
  uv run create-manifest --url "https://github.com/.../releases/download/v1.0/maser_buoy_build.img.xz"
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create Raspberry Pi Imager manifest for Maser Buoy."
    )
    parser.add_argument(
        "--url",
        help="URL for image (e.g. GitHub release). Default: file:// path to local image.",
    )
    parser.add_argument(
        "image_path",
        nargs="?",
        help="Path to maser_buoy_build.img (default: build/maser_buoy_build.img)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    script = Path(__file__).resolve().parent / "create-pi-imager-manifest.sh"
    cmd = ["bash", str(script)]
    if args.url:
        cmd.extend(["--url", args.url])
    elif args.image_path:
        cmd.append(args.image_path)
    subprocess.run(cmd, cwd=repo_root, check=True)


if __name__ == "__main__":
    main()
