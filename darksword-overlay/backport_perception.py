#!/usr/bin/env python3
"""DarkSword-specific compatibility pass layered over the core Perception transform."""

from __future__ import annotations

import re
from pathlib import Path

import backport_perception_core as core


def unconditional_perception_import(source: str) -> str:
    if re.search(r"(?m)^\s*import\s+Perception\s*$", source):
        return source
    # Keep the import outside any conditional import blocks. Swift accepts an
    # import before a leading license comment, and this is safer than placing it
    # inside a canImport/#if region.
    return "import Perception\n" + source


core.add_import = unconditional_perception_import
_core_transform_swift = core.transform_swift


def transform_swift(path: Path) -> tuple[bool, int]:
    changed, wrapped = _core_transform_swift(path)
    if path.name == "DarkSwordCompatibility.swift":
        return changed, wrapped

    source = path.read_text()
    transformed = source

    # iOS 17 introduced zero- and two-value onChange closures. Route every
    # upstream call through DarkSword's overload family, which preserves the
    # one-value form and back-ports old/new value delivery on iOS 16.
    transformed = re.sub(
        r"(?<![A-Za-z0-9_])\.onChange\(",
        ".darkswordOnChange(",
        transformed,
    )

    # Common iOS 17 empty-state view used by DarkSword/upstream Litter.
    transformed = re.sub(
        r"(?<![A-Za-z0-9_])ContentUnavailableView\b",
        "DarkSwordContentUnavailableView",
        transformed,
    )

    # ToolbarItemPlacement.topBar* was added after iOS 16. The navigation-bar
    # placements are equivalent for this app's navigation-stack surfaces.
    transformed = transformed.replace(".topBarTrailing", ".navigationBarTrailing")
    transformed = transformed.replace(".topBarLeading", ".navigationBarLeading")

    if transformed != source:
        path.write_text(transformed)
        changed = True
    return changed, wrapped


core.transform_swift = transform_swift

if __name__ == "__main__":
    raise SystemExit(core.main())
