#!/usr/bin/env bash
# Builds Windows, Linux and Android packages into dist/ at the repository root.
# Usage: godot/tools/export_all.sh   (GODOT can point at the editor binary; default ~/Godot/godot)
set -euo pipefail

GODOT="${GODOT:-$HOME/Godot/godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/godot/project.godot")"
OUT="$ROOT/dist"
STAGE="$OUT/godot"

mkdir -p "$STAGE"
cd "$ROOT/godot"
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release Windows
"$GODOT" --headless --export-release Linux
# Signed with the Android debug key: fine for sharing with friends, not for the Play Store.
"$GODOT" --headless --export-debug Android

cd "$STAGE"
rm -f "$OUT/Nightball-$VERSION-windows.zip" "$OUT/Nightball-$VERSION-linux.tar.gz"
zip -q -9 "$OUT/Nightball-$VERSION-windows.zip" Nightball.exe
tar czf "$OUT/Nightball-$VERSION-linux.tar.gz" Nightball.x86_64
cp Nightball.apk "$OUT/Nightball-$VERSION-android.apk"
cd "$OUT"
rm -rf "$STAGE"
ls -la "$OUT"
