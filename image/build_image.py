#!/usr/bin/env python3
"""
Build the Buoy Raspberry Pi image.

Thin wrapper around image/build-with-docker.sh. Requires Docker.

Usage:
  uv run build-image
  uv run build-image /path/to/raspios-lite.img
  uv run build-image --with-llm
  uv run build-image --both  # build basic then LLM
"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--with-llm", action="store_true", help="Build LLM variant")
    parser.add_argument("--both", action="store_true", help="Build basic then LLM")
    parser.add_argument("image_path", nargs="?", help="Path to base Raspios image")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    script = Path(__file__).resolve().parent / "build-with-docker.sh"
    cmd = ["bash", str(script)]
    if args.image_path:
        cmd.append(args.image_path)

    if args.both:
        subprocess.run(cmd, cwd=repo_root, check=True)
        env = os.environ.copy()
        env["BUOY_LLM"] = "1"
        subprocess.run(cmd, cwd=repo_root, check=True, env=env)
    else:
        env = os.environ.copy()
        if args.with_llm:
            env["BUOY_LLM"] = "1"
        subprocess.run(cmd, cwd=repo_root, check=True, env=env)


if __name__ == "__main__":
    main()
