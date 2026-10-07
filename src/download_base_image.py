#!/usr/bin/env python3
"""Use CustomPiOS 2.0's downloader with a Trixie Lite ARM64 release guard."""

import contextlib
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlparse


def download():
    custompios = Path(os.environ["CUSTOM_PI_OS_PATH"])
    destination = Path(os.environ["BASE_IMAGE_PATH"])
    if os.environ.get("BASE_BOARD") != "raspberrypiarm64":
        raise ValueError("Expected BASE_BOARD=raspberrypiarm64")
    if os.environ.get("BASE_OS") != "debian_trixie":
        raise ValueError("Expected BASE_OS=debian_trixie")
    sys.path.insert(0, str(custompios / "custompios_core"))
    import base_image_downloader as upstream

    board = upstream.get_image_config()
    if not board or board.get("type") != "rpi" or board.get("port") != "lite_arm64":
        raise ValueError("CustomPiOS board must select Raspberry Pi OS Lite ARM64")
    board = dict(board, distribution="trixie", version_file="latest", version_folder="latest")
    resolve_latest = upstream.get_location_header
    download_http = upstream.download_http
    selected = None

    def guarded_latest(url):
        nonlocal selected
        resolved = resolve_latest(url)
        parsed = urlparse(resolved)
        if parsed.scheme != "https" or parsed.hostname not in (
            "downloads.raspberrypi.org", "downloads.raspberrypi.com"
        ):
            raise ValueError("Base image must resolve to an official Raspberry Pi HTTPS URL")
        name = Path(parsed.path).name
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}-raspios-trixie-arm64-lite\.img\.xz", name):
            raise ValueError(f"Refusing a base image outside Trixie Lite ARM64: {name}")
        selected = destination / name
        return resolved

    def verified_download(url, checksum_url, folder):
        checksum = upstream.download_webpage(checksum_url)
        fields = checksum.split() if checksum else []
        if (
            selected is None or len(fields) != 2
            or not re.fullmatch(r"[0-9a-fA-F]{64}", fields[0])
            or fields[1].lstrip("*") != selected.name
        ):
            raise ValueError("Invalid SHA-256 response for the selected base image")
        # Reuse the upstream cache check, retry loop, hashing and file transfer.
        download_http(url, f"{fields[0]} {selected.name}", folder,
                      upstream.ChecksumType.STRING)
        # Upstream 2.0 can return after exhausting checksum-mismatch retries.
        # Recheck its output so an existing corrupt cache cannot reach the build.
        if not selected.is_file() or upstream.get_sha256(selected) != fields[0].lower():
            raise ValueError("The downloaded base image failed SHA-256 verification")

    upstream.get_location_header = guarded_latest
    upstream.download_http = verified_download
    destination.mkdir(parents=True, exist_ok=True)
    # Keep diagnostics separate from the selected filename consumed by Bash.
    with contextlib.redirect_stdout(sys.stderr):
        upstream.download_image_rpi(board, str(destination))
    if selected is None or not selected.is_file() or selected.stat().st_size == 0:
        raise ValueError("CustomPiOS did not produce the selected base image")
    # CustomPiOS 2.0's base config selects the newest archive by mtime. Ensure
    # it selects this verified image even when an older cached file was reused.
    selected.touch()
    return selected


if __name__ == "__main__":
    try:
        print(download())
    except Exception as error:
        print(f"Base image download failed: {error}", file=sys.stderr)
        sys.exit(1)
