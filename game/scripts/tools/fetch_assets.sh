#!/usr/bin/env bash
# fetch_assets.sh — Downloads free CC0/OFL assets for Food Game
# Usage: bash game/scripts/tools/fetch_assets.sh
# Run from project root (c:/project/ProjectKOS/)

set -euo pipefail

GAME_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FONTS_DIR="$GAME_DIR/assets/fonts"

echo "=== Food Game Asset Pipeline ==="
echo "Game directory: $GAME_DIR"
echo ""

# --- 1. Google Fonts: Nunito (OFL license) ---
echo "--- Downloading Nunito fonts (Google Fonts, OFL license) ---"
mkdir -p "$FONTS_DIR"

NUNITO_BASE="https://github.com/google/fonts/raw/main/ofl/nunito/static"

for VARIANT in Nunito-Bold Nunito-ExtraBold Nunito-Regular; do
    DEST="$FONTS_DIR/${VARIANT}.ttf"
    if [ -f "$DEST" ] && [ "$(stat -c%s "$DEST" 2>/dev/null || stat -f%z "$DEST" 2>/dev/null)" -gt 10000 ]; then
        echo "  SKIP: $VARIANT.ttf already exists ($(stat -c%s "$DEST" 2>/dev/null || stat -f%z "$DEST" 2>/dev/null) bytes)"
    else
        echo "  Downloading $VARIANT.ttf ..."
        curl -L -o "$DEST" "$NUNITO_BASE/${VARIANT}.ttf" --silent --show-error
        SIZE=$(stat -c%s "$DEST" 2>/dev/null || stat -f%z "$DEST" 2>/dev/null)
        if [ "$SIZE" -gt 10000 ]; then
            echo "  OK: $VARIANT.ttf ($SIZE bytes)"
        else
            echo "  WARN: $VARIANT.ttf is suspiciously small ($SIZE bytes)"
        fi
    fi
done

echo ""
echo "--- Asset Pipeline Complete ---"
echo ""

# --- Summary ---
echo "=== Downloaded Assets ==="
ls -la "$FONTS_DIR"/*.ttf 2>/dev/null || echo "  No font files found!"
echo ""
echo "=== Done ==="
