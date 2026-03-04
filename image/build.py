#!/usr/bin/env python3
"""
Build the full Buoy image: download base (if needed), build, create manifest.

One command to go from zero to a flashable image with Pi Imager manifest.

Usage:
  uv run build
  uv run build --legacy   # Use Bookworm (Legacy) base instead of Trixie
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def find_base_image(image_dir: Path) -> Path | None:
    """Return first .img or .img.xz in image/base/ or image/, or None."""
    for pattern in ("base/*.img", "base/*.img.xz", "*.img", "*.img.xz"):
        for p in image_dir.glob(pattern):
            if p.is_file():
                return p
    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download base (if needed), build image, create Pi Imager manifest."
    )
    parser.add_argument(
        "--legacy",
        action="store_true",
        help="Use Raspberry Pi OS Legacy (Bookworm) instead of Trixie",
    )
    parser.add_argument(
        "--with-llm",
        action="store_true",
        help="Build image with Ollama, Whisper, and LLM ROS node",
    )
    parser.add_argument(
        "--both",
        action="store_true",
        help="Build both basic and LLM images (runs build twice)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    image_dir = repo_root / "image"

    # 1. Ensure base image exists
    base = find_base_image(image_dir)
    if base is None:
        print("[*] No base image found. Downloading Raspberry Pi OS Lite (64-bit)...")
        download_args = [sys.executable, "-m", "image.download_base"]
        if args.legacy:
            download_args.append("--legacy")
        subprocess.run(download_args, cwd=repo_root, check=True)
    else:
        print(f"[*] Using existing base image: {base}")

    builds = []
    if args.both:
        builds = [(False, "basic"), (True, "LLM")]
    else:
        builds = [(args.with_llm, "LLM" if args.with_llm else "basic")]

    for with_llm, label in builds:
        print(f"[*] Building Buoy image ({label})...")
        build_script = image_dir / "build-with-docker.sh"
        env = os.environ.copy()
        if with_llm:
            env["BUOY_LLM"] = "1"
        subprocess.run(["bash", str(build_script)], cwd=repo_root, check=True, env=env)

    # 3. Create Pi Imager manifest(s)
    print("[*] Creating Pi Imager manifest...")
    manifest_script = image_dir / "create-pi-imager-manifest.sh"
    build_dir = repo_root / "build"
    if args.both:
        subprocess.run(
            ["bash", str(manifest_script), str(build_dir / "buoy_build.img")],
            cwd=repo_root,
            check=True,
        )
        subprocess.run(
            ["bash", str(manifest_script), str(build_dir / "buoy_build_llm.img")],
            cwd=repo_root,
            check=True,
        )
    else:
        subprocess.run(["bash", str(manifest_script)], cwd=repo_root, check=True)

    print("")
    print("Done. Flash with Raspberry Pi Imager:")
    if args.both:
        print("  build/buoy.rpi-imager-manifest (basic)")
        print("  build/buoy_llm.rpi-imager-manifest (LLM)")
    else:
        print("  build/buoy.rpi-imager-manifest")
    print("")


if __name__ == "__main__":
    main()
