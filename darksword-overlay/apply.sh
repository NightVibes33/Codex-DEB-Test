#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"

chmod +x "$SCRIPT_DIR/apply-core.sh"
"$SCRIPT_DIR/apply-core.sh" "$TARGET"

chmod +x "$SCRIPT_DIR/backport_perception.py"
python3 "$SCRIPT_DIR/backport_perception.py" "$TARGET"

grep -q 'Perception:' "$TARGET/apps/ios/project.yml"
grep -q '@Perceptible' "$TARGET/apps/ios/Sources/Litter/Models/AppState.swift"
grep -q 'WithPerceptionTracking' "$TARGET/apps/ios/Sources/Litter/LitterApp.swift"

echo "DarkSword core overlay and iOS 16 Perception backport completed for $TARGET."
