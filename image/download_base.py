#!/usr/bin/env python3
"""
Download Raspberry Pi OS Lite (64-bit) base image for Maser Buoy builds.

Uses the official Raspberry Pi os_list_imagingutility_v4.json manifest to find
the latest Lite image URL. Saves to image/base/ (gitignored).

Usage:
  uv run image/download_base.py
  uv run image/download_base.py --legacy   # Bookworm (Legacy) instead of Trixie
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen

OS_LIST_URL = "https://downloads.raspberrypi.com/os_list_imagingutility_v4.json"
LITE_64_NAME = "Raspberry Pi OS Lite (64-bit)"
LEGACY_LITE_64_NAME = "Raspberry Pi OS (Legacy) Lite"


def find_image_url(data: dict, name: str) -> dict | None:
    """Recursively find an OS entry by name in the os_list structure."""

    def search(items: list) -> dict | None:
        for item in items:
            if item.get("name") == name and "url" in item:
                return item
            if "subitems" in item:
                found = search(item["subitems"])
                if found:
                    return found
        return None

    return search(data.get("os_list", []))


def download_with_progress(url: str, dest: Path, expected_sha256: str | None) -> None:
    """Download a file with progress indicator, optionally verify SHA256."""
    req = Request(url, headers={"User-Agent": "MaserBuoy/1.0"})
    with urlopen(req) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        read = 0
        hasher = hashlib.sha256() if expected_sha256 else None
        chunk_size = 1024 * 1024  # 1 MiB

        with open(dest, "wb") as f:
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                f.write(chunk)
                read += len(chunk)
                if hasher:
                    hasher.update(chunk)
                if total and total > 0:
                    pct = min(100, int(100 * read / total))
                    mb = read / (1024 * 1024)
                    total_mb = total / (1024 * 1024)
                    print(f"\r  {pct}% ({mb:.1f} / {total_mb:.1f} MiB)", end="", flush=True)

        print()

        if expected_sha256 and hasher:
            digest = hasher.hexdigest()
            if digest != expected_sha256:
                dest.unlink(missing_ok=True)
                raise SystemExit(
                    f"ERROR: SHA256 mismatch.\n  Expected: {expected_sha256}\n  Got:      {digest}"
                )
            print("  SHA256 OK")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download Raspberry Pi OS Lite (64-bit) base image for Maser Buoy."
    )
    parser.add_argument(
        "--legacy",
        action="store_true",
        help="Download Legacy (Bookworm) instead of current (Trixie)",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output path (default: image/base/<filename>)",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    base_dir = script_dir / "base"
    base_dir.mkdir(parents=True, exist_ok=True)

    name = LEGACY_LITE_64_NAME if args.legacy else LITE_64_NAME
    print(f"[*] Fetching os_list from Raspberry Pi...")
    with urlopen(OS_LIST_URL) as resp:
        data = json.load(resp)

    entry = find_image_url(data, name)
    if not entry:
        raise SystemExit(f"ERROR: Could not find '{name}' in os_list.")

    url = entry["url"]
    filename = url.split("/")[-1]
    extract_sha256 = entry.get("extract_sha256")
    # Note: extract_sha256 is for the decompressed image; the .xz has a different hash.
    # Raspberry Pi doesn't publish the .xz hash in the JSON. We skip verification for .xz.
    sha256 = None  # Could add .xz hash if published later

    dest = args.output or (base_dir / filename)
    dest = dest.expanduser().resolve()

    if dest.exists():
        print(f"[*] Already exists: {dest}")
        print("    Delete it to re-download.")
        return

    print(f"[*] Downloading {name}...")
    print(f"    URL: {url}")
    print(f"    To:  {dest}")
    download_with_progress(url, dest, sha256)

    print(f"[*] Done. Base image: {dest}")
    print("")
    print("Build the Maser Buoy image:")
    print(f"  ./image/build-with-docker.sh {dest}")


if __name__ == "__main__":
    main()
