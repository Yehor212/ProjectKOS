#!/usr/bin/env python3
"""
Procedural Button Texture Generator for ProjectKOS.
Generates white/grayscale 9-slice button PNGs — tinted at runtime via modulate_color.
Pure Python stdlib (struct, zlib, math) — no PIL dependency.
"""

import math
import os
import struct
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
UI_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "textures", "ui")

SIZE = 128
CORNER_RADIUS = 32
LIP_HEIGHT = 32
SHADOW_HEIGHT = 8
FACE_BOTTOM = SIZE - LIP_HEIGHT - SHADOW_HEIGHT  # 88
LIP_BOTTOM = SIZE - SHADOW_HEIGHT  # 120

# Brightness values (0-255) — will be tinted by modulate_color at runtime
FACE_TOP_BRIGHT = 255
FACE_BOTTOM_BRIGHT = 248  # subtle gradient
LIP_BRIGHT = 196  # 0.77 ratio — matches depth_color/color ratio
PRESSED_BRIGHT = 240
HIGHLIGHT_ALPHA = 60  # top edge highlight


def _sdf_rounded_rect(x: float, y: float, w: float, h: float, r: float) -> float:
    """Signed distance to rounded rectangle. Negative = inside."""
    dx = max(abs(x - w / 2) - (w / 2 - r), 0.0)
    dy = max(abs(y - h / 2) - (h / 2 - r), 0.0)
    return math.sqrt(dx * dx + dy * dy) - r


def _coverage(dist: float) -> float:
    """Anti-aliased coverage from signed distance (1px transition)."""
    if dist < -0.5:
        return 1.0
    if dist > 0.5:
        return 0.0
    return 0.5 - dist


def _generate_normal() -> list[tuple[int, int, int, int]]:
    """Generate btn_candy_normal: face + lip + baked shadow."""
    pixels: list[tuple[int, int, int, int]] = []

    for y in range(SIZE):
        for x in range(SIZE):
            # Determine which zone this pixel is in
            if y < FACE_BOTTOM:
                # Face zone — white with subtle gradient
                t = y / max(FACE_BOTTOM - 1, 1)
                bright = int(FACE_TOP_BRIGHT + (FACE_BOTTOM_BRIGHT - FACE_TOP_BRIGHT) * t)
                zone_h = FACE_BOTTOM
                dist = _sdf_rounded_rect(x, y, SIZE, zone_h, CORNER_RADIUS)
                alpha = _coverage(dist)

                # Top highlight (1px lighter edge)
                if y < 2 and alpha > 0:
                    r = min(255, bright + 5)
                    g = min(255, bright + 5)
                    b = min(255, bright + 5)
                    a = int(alpha * 255)
                    # Blend highlight
                    hl = HIGHLIGHT_ALPHA / 255.0 * alpha
                    r = min(255, int(bright + (255 - bright) * hl))
                    pixels.append((r, r, r, a))
                else:
                    pixels.append((bright, bright, bright, int(alpha * 255)))

            elif y < LIP_BOTTOM:
                # Lip zone — darker gray for 3D depth
                # Use full rect SDF (face + lip as one shape)
                full_h = LIP_BOTTOM
                dist = _sdf_rounded_rect(x, y, SIZE, full_h, CORNER_RADIUS)
                alpha = _coverage(dist)
                pixels.append((LIP_BRIGHT, LIP_BRIGHT, LIP_BRIGHT, int(alpha * 255)))

            else:
                # Shadow zone — black with gaussian falloff
                shadow_t = (y - LIP_BOTTOM) / max(SHADOW_HEIGHT - 1, 1)
                # Gaussian-ish falloff
                shadow_alpha = 0.18 * math.exp(-3.0 * shadow_t * shadow_t)
                # Shadow extends from the lip shape — check horizontal bounds
                margin = CORNER_RADIUS * 0.3  # shadow is narrower
                if x < margin or x >= SIZE - margin:
                    shadow_alpha *= max(0, 1.0 - abs(x - SIZE / 2) / (SIZE / 2 - margin + 1))
                pixels.append((0, 0, 0, int(shadow_alpha * 255)))

    return pixels


def _generate_pressed() -> list[tuple[int, int, int, int]]:
    """Generate btn_candy_pressed: flat face, no lip, no shadow, shifted down 6px."""
    pixels: list[tuple[int, int, int, int]] = []
    offset_y = 6  # top padding — simulates button pushed down
    face_start = offset_y
    face_end = SIZE  # fills to bottom

    for y in range(SIZE):
        for x in range(SIZE):
            if y < face_start:
                # Top transparent padding
                pixels.append((0, 0, 0, 0))
            else:
                # Face zone — uniform slightly darker white
                local_y = y - face_start
                local_h = face_end - face_start
                dist = _sdf_rounded_rect(x, local_y, SIZE, local_h, CORNER_RADIUS)
                alpha = _coverage(dist)
                pixels.append((PRESSED_BRIGHT, PRESSED_BRIGHT, PRESSED_BRIGHT,
                               int(alpha * 255)))

    return pixels


def _write_png(path: str, width: int, height: int,
               pixels: list[tuple[int, int, int, int]]) -> None:
    """Write RGBA PNG file using pure Python (struct + zlib)."""
    sig = b'\x89PNG\r\n\x1a\n'

    def _chunk(chunk_type: bytes, data: bytes) -> bytes:
        c = chunk_type + data
        crc = zlib.crc32(c) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + c + struct.pack('>I', crc)

    # IHDR: width, height, bit_depth=8, color_type=6 (RGBA), compress=0, filter=0, interlace=0
    ihdr = _chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))

    # IDAT: filter=0 (None) per row, then raw RGBA bytes
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type: None
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw.extend([r, g, b, a])
    compressed = zlib.compress(bytes(raw), 9)
    idat = _chunk(b'IDAT', compressed)

    # IEND
    iend = _chunk(b'IEND', b'')

    with open(path, 'wb') as f:
        f.write(sig + ihdr + idat + iend)


def main() -> None:
    print("=== ProjectKOS Button Texture Generator ===")
    os.makedirs(UI_DIR, exist_ok=True)

    # Normal button (with lip + shadow)
    normal_path = os.path.join(UI_DIR, "btn_candy_normal.png")
    print("  Generating btn_candy_normal.png...", end="")
    pixels_normal = _generate_normal()
    _write_png(normal_path, SIZE, SIZE, pixels_normal)
    size_kb = os.path.getsize(normal_path) / 1024
    print(f"  OK ({size_kb:.1f} KB)")

    # Pressed button (no lip, no shadow, shifted down)
    pressed_path = os.path.join(UI_DIR, "btn_candy_pressed.png")
    print("  Generating btn_candy_pressed.png...", end="")
    pixels_pressed = _generate_pressed()
    _write_png(pressed_path, SIZE, SIZE, pixels_pressed)
    size_kb = os.path.getsize(pressed_path) / 1024
    print(f"  OK ({size_kb:.1f} KB)")

    print()
    print(f"=== Done: 2 textures generated in {UI_DIR} ===")
    print("White/grayscale base — tinted at runtime via StyleBoxTexture.modulate_color")


if __name__ == "__main__":
    main()
