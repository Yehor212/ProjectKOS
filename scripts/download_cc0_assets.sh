#!/usr/bin/env bash
## ProjectKOS — Download CC0 Assets Script
## All assets are CC0 1.0 Universal (Public Domain)
## Run: bash scripts/download_cc0_assets.sh

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$PROJECT_ROOT/game/assets"
TEMP_DIR="$PROJECT_ROOT/.asset_downloads"

echo "=== ProjectKOS CC0 Asset Downloader ==="
echo "Project: $PROJECT_ROOT"
echo ""

mkdir -p "$TEMP_DIR"
mkdir -p "$ASSETS_DIR/sprites/particles"
mkdir -p "$ASSETS_DIR/sprites/ui"
mkdir -p "$ASSETS_DIR/sprites/animals_extra"
mkdir -p "$ASSETS_DIR/audio/sfx"
mkdir -p "$ASSETS_DIR/audio/bgm"
mkdir -p "$ASSETS_DIR/backgrounds"
mkdir -p "$ASSETS_DIR/licenses"

download_and_extract() {
    local NAME="$1"
    local URL="$2"
    local ZIP_PATH="$3"
    local EXTRACT_DIR="$4"
    local TARGET_DIR="$5"
    local EXT="$6"

    echo "  Downloading $NAME..."
    if [ ! -f "$ZIP_PATH" ] || [ ! -s "$ZIP_PATH" ]; then
        curl -L --fail -o "$ZIP_PATH" "$URL" 2>/dev/null
    fi

    if [ -f "$ZIP_PATH" ] && [ -s "$ZIP_PATH" ]; then
        echo "  Extracting..."
        mkdir -p "$EXTRACT_DIR"
        unzip -qo "$ZIP_PATH" -d "$EXTRACT_DIR" 2>/dev/null || true
        find "$EXTRACT_DIR" -name "*.$EXT" -exec cp {} "$TARGET_DIR/" \; 2>/dev/null || true
        local COUNT
        COUNT=$(find "$TARGET_DIR" -name "*.$EXT" 2>/dev/null | wc -l)
        echo "  OK: $COUNT $EXT files copied to $TARGET_DIR"
    else
        echo "  [FAIL] Could not download. Please download manually:"
        echo "         URL: $URL"
        echo "         Save to: $ZIP_PATH"
    fi
}

## ============================================================
## 1. KENNEY PARTICLE PACK (CC0)
## ============================================================
echo "[1/4] Kenney Particle Pack..."
download_and_extract \
    "Particle Pack" \
    "https://kenney.nl/media/pages/assets/particle-pack/1dd3d4cbe2-1677578741/kenney_particle-pack.zip" \
    "$TEMP_DIR/particle-pack.zip" \
    "$TEMP_DIR/particles" \
    "$ASSETS_DIR/sprites/particles" \
    "png"

## ============================================================
## 2. KENNEY UI PACK (CC0)
## ============================================================
echo "[2/4] Kenney UI Pack..."
download_and_extract \
    "UI Pack" \
    "https://kenney.nl/media/pages/assets/ui-pack/af874291da-1718203990/kenney_ui-pack.zip" \
    "$TEMP_DIR/ui-pack.zip" \
    "$TEMP_DIR/ui" \
    "$ASSETS_DIR/sprites/ui" \
    "png"

## ============================================================
## 3. KENNEY UI AUDIO (CC0)
## ============================================================
echo "[3/4] Kenney UI Audio..."
download_and_extract \
    "UI Audio" \
    "https://kenney.nl/media/pages/assets/ui-audio/e19c9b1814-1677590494/kenney_ui-audio.zip" \
    "$TEMP_DIR/ui-audio.zip" \
    "$TEMP_DIR/audio" \
    "$ASSETS_DIR/audio/sfx" \
    "ogg"

## ============================================================
## 4. KENNEY ANIMAL PACK REDUX (CC0)
## ============================================================
echo "[4/4] Kenney Animal Pack Redux..."
download_and_extract \
    "Animal Pack Redux" \
    "https://kenney.nl/media/pages/assets/animal-pack-redux/c217650a92-1677666936/kenney_animal-pack-redux.zip" \
    "$TEMP_DIR/animal-pack-redux.zip" \
    "$TEMP_DIR/animals" \
    "$ASSETS_DIR/sprites/animals_extra" \
    "png"

## ============================================================
## SUMMARY
## ============================================================
echo ""
echo "=== RESULTS ==="
echo "  Particles:     $(find "$ASSETS_DIR/sprites/particles" -name "*.png" 2>/dev/null | wc -l) PNG"
echo "  UI sprites:    $(find "$ASSETS_DIR/sprites/ui" -name "*.png" 2>/dev/null | wc -l) PNG"
echo "  New SFX:       $(find "$ASSETS_DIR/audio/sfx" -name "*.ogg" 2>/dev/null | wc -l) OGG"
echo "  Extra animals: $(find "$ASSETS_DIR/sprites/animals_extra" -name "*.png" 2>/dev/null | wc -l) PNG"
echo ""
du -sh "$ASSETS_DIR" 2>/dev/null || true
echo ""
echo "=== MANUAL DOWNLOADS NEEDED ==="
echo "1. Backgrounds: https://opengameart.org/content/cc0-backgrounds"
echo "   -> Save PNGs to: game/assets/backgrounds/"
echo ""
echo "2. BGM Music: https://pixabay.com/music/search/children%20game%20happy/"
echo "   -> Download 3-4 OGG tracks to: game/assets/audio/bgm/"
echo ""
echo "Temp files in: $TEMP_DIR"
