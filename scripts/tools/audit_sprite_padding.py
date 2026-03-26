#!/usr/bin/env python3
"""
Sprite Padding Auditor for ProjectKOS.
Checks if animal/food PNG sprites have sufficient transparent padding
for shader effects (outline, glow). Pure Python stdlib (struct, zlib).
"""

import os
import struct
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SPRITES_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites")

MIN_PADDING = 4  # мінімум пікселів прозорої рамки


def _read_png(path: str) -> tuple[int, int, list[int]]:
    """Read PNG and return (width, height, alpha_channel)."""
    with open(path, "rb") as f:
        sig = f.read(8)
        if sig != b'\x89PNG\r\n\x1a\n':
            raise ValueError(f"Not a PNG: {path}")

        width = height = 0
        idat_chunks = []

        while True:
            raw = f.read(8)
            if len(raw) < 8:
                break
            length, chunk_type = struct.unpack(">I4s", raw)
            data = f.read(length)
            f.read(4)  # CRC

            if chunk_type == b"IHDR":
                width, height = struct.unpack(">II", data[:8])
                bit_depth = data[8]
                color_type = data[9]
                if bit_depth != 8 or color_type != 6:
                    # Не RGBA 8-bit — пропускаємо
                    return width, height, []
            elif chunk_type == b"IDAT":
                idat_chunks.append(data)
            elif chunk_type == b"IEND":
                break

        raw_data = zlib.decompress(b"".join(idat_chunks))
        alphas = []
        stride = 1 + width * 4  # filter byte + RGBA per pixel
        for y in range(height):
            row_start = y * stride + 1  # skip filter byte
            for x in range(width):
                px_start = row_start + x * 4
                alphas.append(raw_data[px_start + 3])

        return width, height, alphas


def _check_padding(path: str) -> tuple[bool, str]:
    """Check if sprite has MIN_PADDING transparent border."""
    try:
        w, h, alphas = _read_png(path)
    except Exception as e:
        return False, f"ERROR reading: {e}"

    if not alphas:
        return True, "skipped (not RGBA8)"

    for border_px in range(MIN_PADDING):
        # Перевірити верхній і нижній ряди
        for x in range(w):
            if alphas[border_px * w + x] > 0:
                return False, f"non-transparent at top row {border_px}, x={x}"
            if alphas[(h - 1 - border_px) * w + x] > 0:
                return False, f"non-transparent at bottom row {h - 1 - border_px}, x={x}"
        # Перевірити лівий і правий стовпці
        for y in range(h):
            if alphas[y * w + border_px] > 0:
                return False, f"non-transparent at left col {border_px}, y={y}"
            if alphas[y * w + (w - 1 - border_px)] > 0:
                return False, f"non-transparent at right col {w - 1 - border_px}, y={y}"

    return True, f"OK ({w}x{h}, {MIN_PADDING}px+ padding)"


def main() -> None:
    print(f"=== Sprite Padding Audit (min {MIN_PADDING}px transparent border) ===")
    dirs = ["animals", "food"]
    total = 0
    passed = 0
    failed = 0

    for subdir in dirs:
        sprite_dir = os.path.join(SPRITES_DIR, subdir)
        if not os.path.isdir(sprite_dir):
            print(f"  SKIP: {subdir}/ not found")
            continue
        print(f"\n  --- {subdir}/ ---")
        for fname in sorted(os.listdir(sprite_dir)):
            if not fname.endswith(".png"):
                continue
            fpath = os.path.join(sprite_dir, fname)
            ok, msg = _check_padding(fpath)
            total += 1
            if ok:
                passed += 1
                print(f"  PASS: {fname} — {msg}")
            else:
                failed += 1
                print(f"  FAIL: {fname} — {msg}")

    print(f"\n=== Done: {passed}/{total} passed, {failed} failed ===")
    if failed > 0:
        print("NOTE: Failed sprites need transparent padding for shader effects.")


if __name__ == "__main__":
    main()
