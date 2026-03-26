#!/usr/bin/env python3
"""
Download Twemoji PNG emojis and resize to 256x256 for game icons.
Twemoji: CC BY 4.0 license - https://github.com/twitter/twemoji
Graphics by Twitter/X - https://github.com/twitter/twemoji

Downloads 72x72 PNGs from GitHub and upscales to 256x256 using Pillow LANCZOS.
Also attempts SVG download + svglib conversion for best quality.
"""

import io
import os
import urllib.request
from PIL import Image

# Output directory
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "game_icons")
SIZE = 256

# Twemoji PNG and SVG URLs (GitHub raw)
PNG_URL = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/"
SVG_URL = "https://raw.githubusercontent.com/twitter/twemoji/master/assets/svg/"

# Try svglib for better SVG→PNG conversion
try:
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
    HAS_SVGLIB = True
except ImportError:
    HAS_SVGLIB = False

# Mapping: icon_id -> (emoji_codepoint, description)
ICON_MAP = {
    "fork_knife":  ("1f374",  "Fork and Knife"),
    "ghost":       ("1f47b",  "Ghost"),
    "brain":       ("1f9e0",  "Brain"),
    "bubble":      ("1fae7",  "Bubbles"),
    "diamond":     ("1f48e",  "Gem Stone"),
    "numbers":     ("1f522",  "Input Numbers"),
    "puzzle":      ("1f9e9",  "Puzzle Piece"),
    "magnifier":   ("1f50d",  "Magnifying Glass Left"),
    "pencil":      ("270f",   "Pencil"),
    "music_note":  ("1f3b5",  "Musical Notes"),
    "cycle":       ("1f504",  "Counterclockwise Arrows"),
    "scales":      ("2696",   "Balance Scale"),
    "folder":      ("1f4c1",  "File Folder"),
    "ruler":       ("1f4cf",  "Straight Ruler"),
    "factory":     ("1f3ed",  "Factory"),
    "soap":        ("1f9fc",  "Soap"),
    "weather":     ("2600",   "Sun"),
    "flag":        ("1f6a9",  "Triangular Flag"),
    "palette":     ("1f3a8",  "Artist Palette"),
    "robot":       ("1f916",  "Robot"),
    "money":       ("1f4b0",  "Money Bag"),
    "recycle":     ("267b",   "Recycling Symbol"),
    "knight":      ("265f",   "Chess Pawn"),
    "beaker":      ("1f9ea",  "Test Tube"),
    "target":      ("1f3af",  "Bullseye"),
    "letters":     ("1f524",  "Input Latin Letters"),
    "planet":      ("1fa90",  "Ringed Planet"),
    "clock":       ("23f0",   "Alarm Clock"),
    "star":        ("2b50",   "Star"),
}

# Fallback codepoints if primary not found
FALLBACK_MAP = {
    "bubble": ("1f9fc", "Soap (fallback for bubbles)"),
    "knight": ("1f434", "Horse Face (fallback for chess pawn)"),
}


def download_url(url: str) -> bytes | None:
    """Download content from URL."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ProjectKOS-icon-downloader/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read()
    except Exception as e:
        return None


def download_and_resize_png(codepoint: str, output_path: str) -> bool:
    """Download 72x72 PNG and resize to 256x256 using Pillow LANCZOS."""
    url = f"{PNG_URL}{codepoint}.png"
    data = download_url(url)
    if data is None:
        return False

    img = Image.open(io.BytesIO(data))
    # Ensure RGBA
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    # Resize with best quality
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(output_path, "PNG", optimize=True)
    return True


def download_svg_and_convert(codepoint: str, output_path: str) -> bool:
    """Download SVG and convert to 256x256 PNG using svglib (if available)."""
    if not HAS_SVGLIB:
        return False

    url = f"{SVG_URL}{codepoint}.svg"
    data = download_url(url)
    if data is None:
        return False

    try:
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".svg", delete=False, mode="wb") as f:
            f.write(data)
            tmp_svg = f.name

        drawing = svg2rlg(tmp_svg)
        if drawing is None:
            os.unlink(tmp_svg)
            return False

        # Scale to target size
        sx = SIZE / drawing.width
        sy = SIZE / drawing.height
        drawing.width = SIZE
        drawing.height = SIZE
        drawing.scale(sx, sy)

        renderPM.drawToFile(drawing, output_path, fmt="PNG")
        os.unlink(tmp_svg)
        return True
    except Exception as e:
        print(f"    svglib conversion failed: {e}")
        if os.path.exists(tmp_svg):
            os.unlink(tmp_svg)
        return False


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    print(f"svglib available: {HAS_SVGLIB}")
    print(f"Output: {OUT_DIR}")
    print(f"Target size: {SIZE}x{SIZE}\n")

    success = 0
    failed = []

    for icon_id, (codepoint, desc) in ICON_MAP.items():
        out_path = os.path.join(OUT_DIR, f"icon_{icon_id}.png")
        print(f"[{icon_id}] {desc} ({codepoint})...", end=" ")

        # Try SVG first (best quality), then PNG fallback
        ok = False
        if HAS_SVGLIB:
            ok = download_svg_and_convert(codepoint, out_path)
            if ok:
                print("OK (SVG)")

        if not ok:
            ok = download_and_resize_png(codepoint, out_path)
            if ok:
                print("OK (PNG upscaled)")

        # Try fallback if primary failed
        if not ok and icon_id in FALLBACK_MAP:
            fb_cp, fb_desc = FALLBACK_MAP[icon_id]
            print(f"\n  Trying fallback: {fb_desc} ({fb_cp})...", end=" ")
            if HAS_SVGLIB:
                ok = download_svg_and_convert(fb_cp, out_path)
                if ok:
                    print("OK (SVG fallback)")
            if not ok:
                ok = download_and_resize_png(fb_cp, out_path)
                if ok:
                    print("OK (PNG fallback)")

        if ok:
            fsize = os.path.getsize(out_path)
            success += 1
        else:
            print("FAILED")
            failed.append(icon_id)

    print(f"\n{'='*50}")
    print(f"RESULT: {success}/{len(ICON_MAP)} icons downloaded")
    if failed:
        print(f"FAILED: {', '.join(failed)}")
    else:
        print("All icons downloaded successfully!")


if __name__ == "__main__":
    main()
