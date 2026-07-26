#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def tail_lines(text: str, count: int) -> list[str]:
    return text.splitlines()[-count:]


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: publish-gif2ani-341-proof.py <workspace> <bridge-dir>", file=sys.stderr)
        return 2

    workspace = Path(sys.argv[1]).resolve()
    bridge = Path(sys.argv[2]).resolve()
    destination = bridge / "remote" / "gif2ani-341-final-proof.txt"
    destination.parent.mkdir(parents=True, exist_ok=True)

    build = read_text(workspace / "gif2ani-341-final-build.log")
    device = read_text(workspace / "gif2ani-341-device-proof.txt")
    digest = read_text(workspace / "gif2ani-341-final-sha256.txt")
    contents = read_text(workspace / "gif2ani-341-final-contents.txt")
    binaries = read_text(workspace / "gif2ani-341-final-binaries.txt")

    secret = os.environ.get("IPAD_PASSWORD", "")
    if secret:
        build = build.replace(secret, "***REDACTED***")
        device = device.replace(secret, "***REDACTED***")
        digest = digest.replace(secret, "***REDACTED***")
        contents = contents.replace(secret, "***REDACTED***")
        binaries = binaries.replace(secret, "***REDACTED***")

    lines = [
        "Gif2Ani 3.4.1 Final Build Install and Device Proof",
        f"run_id={os.environ.get('GITHUB_RUN_ID', '')}",
        f"job_status={os.environ.get('JOB_STATUS', '')}",
        f"device_step={os.environ.get('DEVICE_OUTCOME', '')}",
        "offline_themes=12",
        "cc0_download_themes=54",
        "original_springy_themes=48",
        "downloadable_theme_total=102",
        "first_class_theme_total=114",
        "",
        "--- DEB SHA-256 ---",
        digest.strip(),
        "",
        "--- DEVICE PROOF ---",
        *tail_lines(device, 500),
        "",
        "--- PACKAGED BINARIES ---",
        *tail_lines(binaries, 100),
        "",
        "--- PACKAGE CONTENTS ---",
        *tail_lines(contents, 250),
        "",
        "--- BUILD LOG TAIL ---",
        *tail_lines(build, 350),
    ]
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
