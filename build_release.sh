#!/bin/bash
set -euo pipefail

# Конфігурація
VERSION="1.0.0"
PRESET="Android"
OUTPUT_DIR="build"
OUTPUT_FILE="$OUTPUT_DIR/FoodGame_v${VERSION}.aab"
PROJECT_DIR="game"

# Перевірка godot
GODOT_CMD="${GODOT_PATH:-godot}"
if ! command -v "$GODOT_CMD" &>/dev/null; then
    echo "ERROR: Godot not found in PATH."
    echo "Set GODOT_PATH to your Godot executable, e.g.:"
    echo "  export GODOT_PATH=\"/path/to/Godot_v4.4-stable_win64.exe\""
    echo "  ./build_release.sh"
    exit 1
fi

# Перевірка keystore
if [ ! -f "$PROJECT_DIR/.keys/release.keystore" ]; then
    echo "ERROR: Keystore not found. Run first:"
    echo "  bash scripts/tools/generate_keystore.sh"
    exit 1
fi

## Пароль keystore — через змінну середовища (Godot 4.3+ підтримує нативно)
if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}" ]; then
    echo "WARNING: GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD not set."
    echo "Export may fail if keystore requires a password."
    echo "  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='your_password'"
fi

mkdir -p "$OUTPUT_DIR"

echo "Building $OUTPUT_FILE..."
"$GODOT_CMD" --headless --path "$PROJECT_DIR" --export-release "$PRESET" "../$OUTPUT_FILE"

echo "Build complete: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"
