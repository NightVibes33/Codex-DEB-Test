#!/usr/bin/env python3
"""Back-port Litter's SwiftUI Observation usage to iOS 16 with Perception.

The upstream app targets iOS 17+ Observation APIs extensively. Point-Free's
swift-perception provides source-compatible Environment support down to iOS 13,
with @Perceptible, @Perception.Bindable and WithPerceptionTracking.

This transform is intentionally idempotent and runs after every upstream import.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PERCEPTION_REVISION = "de219a1cf34e958134e75a9ebb134cf09bf52fc6"
SOURCE_ROOTS = (
    "apps/ios/Sources/Litter",
    "apps/ios/Sources/LitterLiveActivity",
    "apps/ios/Sources/LitterWatch",
    "apps/ios/Sources/LitterWatchComplications",
)


def matching_brace(source: str, opening: int) -> int:
    depth = 0
    index = opening
    state = "code"
    block_comment_depth = 0

    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""
        next_two = source[index : index + 3]

        if state == "code":
            if char == "/" and next_char == "/":
                state = "line_comment"
                index += 2
                continue
            if char == "/" and next_char == "*":
                state = "block_comment"
                block_comment_depth = 1
                index += 2
                continue
            if next_two == '"""':
                state = "triple_string"
                index += 3
                continue
            if char == '"':
                state = "string"
                index += 1
                continue
            if char == "'":
                state = "character"
                index += 1
                continue
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return index
            index += 1
            continue

        if state == "line_comment":
            if char == "\n":
                state = "code"
            index += 1
            continue

        if state == "block_comment":
            if char == "/" and next_char == "*":
                block_comment_depth += 1
                index += 2
                continue
            if char == "*" and next_char == "/":
                block_comment_depth -= 1
                index += 2
                if block_comment_depth == 0:
                    state = "code"
                continue
            index += 1
            continue

        if state == "triple_string":
            if next_two == '"""':
                state = "code"
                index += 3
            else:
                index += 1
            continue

        if state in {"string", "character"}:
            if char == "\\":
                index += 2
                continue
            terminator = '"' if state == "string" else "'"
            if char == terminator:
                state = "code"
            index += 1
            continue

    raise ValueError(f"unmatched opening brace at offset {opening}")


def add_import(source: str) -> str:
    if re.search(r"(?m)^\s*import\s+Perception\s*$", source):
        return source

    imports = list(re.finditer(r"(?m)^(?:@_\w+\s+)?import\s+[^\n]+\n", source))
    if imports:
        insert_at = imports[-1].end()
        return source[:insert_at] + "import Perception\n" + source[insert_at:]
    return "import Perception\n" + source


def wrap_view_bodies(source: str) -> tuple[str, int]:
    pattern = re.compile(r"\bvar\s+body\s*:\s*some\s+View\s*\{")
    spans: list[tuple[int, int, str]] = []

    for match in pattern.finditer(source):
        opening = source.find("{", match.start(), match.end())
        closing = matching_brace(source, opening)
        body_prefix = source[opening + 1 : min(closing, opening + 240)]
        if re.match(r"\s*WithPerceptionTracking\s*\{", body_prefix):
            continue
        line_start = source.rfind("\n", 0, match.start()) + 1
        indent = re.match(r"[ \t]*", source[line_start:match.start()]).group(0)
        spans.append((opening, closing, indent))

    for opening, closing, indent in reversed(spans):
        source = (
            source[: opening + 1]
            + f"\n{indent}    WithPerceptionTracking {{"
            + source[opening + 1 : closing]
            + f"\n{indent}    }}"
            + source[closing:]
        )
    return source, len(spans)


def transform_swift(path: Path) -> tuple[bool, int]:
    source = path.read_text()
    original = source

    source = re.sub(r"(?m)^\s*import\s+Observation\s*$", "import Perception", source)
    source = re.sub(r"(?<![A-Za-z0-9_.])@Observable\b", "@Perceptible", source)
    source = re.sub(r"(?<![A-Za-z0-9_.])@ObservationIgnored\b", "@PerceptionIgnored", source)
    source = re.sub(r"(?<![A-Za-z0-9_.])@Bindable\b", "@Perception.Bindable", source)
    source = re.sub(r"\bwithObservationTracking\b", "withPerceptionTracking", source)
    source = re.sub(r"\bObservations\b", "Perceptions", source)

    wrapped = 0
    if re.search(r"\bvar\s+body\s*:\s*some\s+View\s*\{", source):
        source, wrapped = wrap_view_bodies(source)

    needs_perception = source != original or wrapped > 0
    if needs_perception:
        source = add_import(source)
        # Remove duplicate imports created when Observation was replaced in a
        # file that already imported Perception.
        lines = source.splitlines(keepends=True)
        seen = False
        deduped: list[str] = []
        for line in lines:
            if re.fullmatch(r"\s*import\s+Perception\s*\n?", line):
                if seen:
                    continue
                seen = True
                line = "import Perception\n"
            deduped.append(line)
        source = "".join(deduped)

    if source != original:
        path.write_text(source)
        return True, wrapped
    return False, 0


def target_blocks(project: str) -> list[tuple[str, int, int]]:
    targets_match = re.search(r"(?m)^targets:\s*$", project)
    if not targets_match:
        raise ValueError("project.yml has no targets section")
    start = targets_match.end()
    headers = list(re.finditer(r"(?m)^  ([A-Za-z0-9_.+-]+):\s*$", project[start:]))
    blocks: list[tuple[str, int, int]] = []
    for index, header in enumerate(headers):
        block_start = start + header.start()
        block_end = start + (headers[index + 1].start() if index + 1 < len(headers) else len(project[start:]))
        blocks.append((header.group(1), block_start, block_end))
    return blocks


def add_package_and_dependencies(project_path: Path) -> None:
    project = project_path.read_text()
    if "  Perception:\n" not in project:
        packages_marker = "packages:\n"
        package = (
            "  Perception:\n"
            "    url: https://github.com/pointfreeco/swift-perception.git\n"
            f"    revision: {PERCEPTION_REVISION}\n"
        )
        if packages_marker not in project:
            raise ValueError("project.yml has no packages section")
        project = project.replace(packages_marker, packages_marker + package, 1)

    relevant_sources = (
        "Sources/Litter",
        "Sources/LitterLiveActivity",
        "Sources/LitterWatch",
        "Sources/LitterWatchComplications",
    )

    edits: list[tuple[int, str]] = []
    for name, start, end in target_blocks(project):
        block = project[start:end]
        if not any(source in block for source in relevant_sources):
            continue
        if re.search(r"(?m)^\s+- package: Perception\s*$", block):
            continue
        dependency = "      - package: Perception\n        product: Perception\n"
        dependencies = re.search(r"(?m)^    dependencies:\s*$", block)
        if dependencies:
            insert_at = start + dependencies.end()
            edits.append((insert_at, "\n" + dependency.rstrip("\n")))
            continue
        insertion = re.search(r"(?m)^    (?:postBuildScripts|settings|sources|resources):\s*$", block)
        insert_at = start + (insertion.start() if insertion else len(block))
        edits.append((insert_at, "    dependencies:\n" + dependency))

    for insert_at, text in sorted(edits, reverse=True):
        project = project[:insert_at] + text + project[insert_at:]

    project_path.write_text(project)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    project = root / "apps/ios/project.yml"
    if not project.exists():
        print(f"error: missing {project}", file=sys.stderr)
        return 2

    changed_files = 0
    wrapped_bodies = 0
    for relative in SOURCE_ROOTS:
        source_root = root / relative
        if not source_root.exists():
            continue
        for path in sorted(source_root.rglob("*.swift")):
            changed, wrapped = transform_swift(path)
            changed_files += int(changed)
            wrapped_bodies += wrapped

    add_package_and_dependencies(project)

    print(
        f"Perception iOS 16 backport applied: {changed_files} Swift files changed, "
        f"{wrapped_bodies} View bodies wrapped, package revision {PERCEPTION_REVISION}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
