#!/usr/bin/env python3
"""
Build the Buoy Raspberry Pi image.

Thin wrapper around image/build-with-docker.sh. Requires Docker.

Usage:
  uv run build-image
  uv run build-image /path/to/raspios-lite.img
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    script = Path(__file__).resolve().parent / "build-with-docker.sh"
    args = ["bash", str(script)] + sys.argv[1:]
    subprocess.run(args, cwd=repo_root, check=True)


if __name__ == "__main__":
    main()
