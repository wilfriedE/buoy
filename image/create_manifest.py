#!/usr/bin/env python3
"""
Create Raspberry Pi Imager manifest for the Maser Buoy image.

Thin wrapper around image/create-pi-imager-manifest.sh. Enables the settings
gear (hostname, SSH) when flashing with Pi Imager.

Usage:
  uv run create-manifest
  uv run create-manifest /path/to/maser_buoy_build.img
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    script = Path(__file__).resolve().parent / "create-pi-imager-manifest.sh"
    args = ["bash", str(script)] + sys.argv[1:]
    subprocess.run(args, cwd=repo_root, check=True)


if __name__ == "__main__":
    main()
