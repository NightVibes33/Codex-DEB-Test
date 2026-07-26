#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: resolve-github-environment.py <environments.json> <environment-id>", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    target_id = int(sys.argv[2])
    payload = json.loads(source.read_text(encoding="utf-8"))

    for environment in payload.get("environments", []):
        if int(environment.get("id", -1)) == target_id:
            name = environment.get("name")
            if not isinstance(name, str) or not name:
                raise RuntimeError("matched environment has no valid name")
            print(f"environment_name={name}")
            return 0

    raise RuntimeError(f"environment id {target_id} was not found")


if __name__ == "__main__":
    raise SystemExit(main())
