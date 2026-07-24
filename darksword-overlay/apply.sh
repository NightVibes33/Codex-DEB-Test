#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$SCRIPT_DIR/../upstream/litter}"

chmod +x "$SCRIPT_DIR/apply-core.sh"
"$SCRIPT_DIR/apply-core.sh" "$TARGET"

COMPATIBILITY_SOURCE="$SCRIPT_DIR/app/DarkSwordCompatibility.swift"
test -f "$COMPATIBILITY_SOURCE"

mkdir -p "$TARGET/apps/ios/Sources/Litter/DarkSword"
cp "$COMPATIBILITY_SOURCE" \
  "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"

for source_root in \
  LitterLiveActivity \
  LitterWatch \
  LitterWatchComplications
do
  test -d "$TARGET/apps/ios/Sources/$source_root"
  cp "$COMPATIBILITY_SOURCE" \
    "$TARGET/apps/ios/Sources/$source_root/DarkSwordCompatibility.swift"
done

chmod +x "$SCRIPT_DIR/backport_perception.py"
python3 "$SCRIPT_DIR/backport_perception.py" "$TARGET"

grep -q 'Perception:' "$TARGET/apps/ios/project.yml"
grep -q '@Perceptible' "$TARGET/apps/ios/Sources/Litter/Models/AppState.swift"
grep -q 'WithPerceptionTracking' "$TARGET/apps/ios/Sources/Litter/LitterApp.swift"
grep -q 'darkswordOnChange' "$TARGET/apps/ios/Sources/Litter/DarkSword/DarkSwordCompatibility.swift"

echo "DarkSword core overlay and iOS 16 compatibility backports completed for $TARGET."
