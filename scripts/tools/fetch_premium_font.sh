#!/usr/bin/env bash
## Завантаження Fredoka One (OFL license) для заголовків UI.
## Ідемпотентний — пропускає якщо файл вже існує.
##
## ПРИМІТКА: Google Fonts API та GitHub LFS не дозволяють прямий curl.
## Для ручного завантаження:
##   1. https://fonts.google.com/specimen/Fredoka+One → Download Family
##   2. Витягнути FredokaOne-Regular.ttf → game/assets/fonts/FredokaOne-Regular.ttf
##
## Fallback: ThemeManager автоматично використовує Nunito-ExtraBold
## (вже є в проекті) якщо Fredoka One не знайдено.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FONT_DIR="$PROJECT_ROOT/game/assets/fonts"
TARGET="$FONT_DIR/FredokaOne-Regular.ttf"

if [ -f "$TARGET" ]; then
    echo "OK: Fredoka One already exists at $TARGET"
    exit 0
fi

echo "Fredoka One not found at $TARGET"
echo "Manual download required:"
echo "  1. Visit https://fonts.google.com/specimen/Fredoka+One"
echo "  2. Click 'Download Family'"
echo "  3. Extract FredokaOne-Regular.ttf to $FONT_DIR/"
echo ""
echo "Fallback: Nunito-ExtraBold will be used for headings."

# Перевірити fallback
if [ -f "$FONT_DIR/Nunito-ExtraBold.ttf" ]; then
    echo "OK: Nunito-ExtraBold.ttf available as fallback."
else
    echo "WARN: No fallback heading font found!"
fi
