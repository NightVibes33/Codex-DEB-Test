"""Private AlleyCat CI bootstrap hooks for Python-based project patchers.

Python imports ``sitecustomize`` from the script search path before running a
script. The full sideload lane already executes Python helpers from this folder
immediately before XcodeGen, so this is a deterministic place to apply the
Hairball iOS 16 compatibility rewrite without affecting ordinary builds.
"""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import sys


def _apply_hairball_ios16_compatibility() -> None:
    if os.environ.get("LITTER_NYXIAN_PRIVATE_BUILD") != "1":
        return

    current_script = Path(sys.argv[0]).name if sys.argv else ""
    if current_script == "patch-hairball-ios16-compat.py":
        return

    script = Path(__file__).with_name("patch-hairball-ios16-compat.py")
    if not script.is_file():
        raise RuntimeError(f"missing AlleyCat Hairball compatibility patch: {script}")

    spec = importlib.util.spec_from_file_location("alleycat_hairball_ios16_compat", script)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load AlleyCat Hairball compatibility patch: {script}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.patch_project()
    module.patch_effects()
    print("Applied AlleyCat Hairball iOS 16 compatibility before XcodeGen.")


_apply_hairball_ios16_compatibility()
