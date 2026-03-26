#!/usr/bin/env python3
"""
V24.2 — Recover original cartoon sprites from Godot import cache.

Godot caches imported textures as .ctex files (GST2 format) in
game/.godot/imported/. The original August 2025 sprites are still
there as WebP data inside the .ctex wrapper.

This script:
1. Scans .ctex files from 2025
2. Extracts WebP data (RIFF marker)
3. Converts to PNG via Pillow
4. Centers on 512×512 transparent canvas if needed
5. Saves to game/assets/sprites/{animals,food}/
"""
import os
import struct
import time
import io
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
CACHE_DIR = os.path.join(PROJECT_ROOT, "game", ".godot", "imported")
ANIMALS_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "food")

OUTPUT_SIZE = 512

# Which sprites go where
ANIMAL_NAMES = {
    "Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
    "Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse", "Lion",
    "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
}

FOOD_NAMES = {
    "Apple", "Bamboo", "Banana", "Bone", "Cabbage", "Carrot", "Cheese",
    "Drumstick", "Fish", "Grass", "Hay", "Honey", "Leaf", "Meat",
    "Mosquito", "Shrimp", "Walnut", "Watermelon", "Wheat",
}


def extract_webp_from_ctex(ctex_path: str) -> bytes | None:
    """Extract WebP data from a Godot .ctex file."""
    with open(ctex_path, "rb") as f:
        data = f.read()
    riff_pos = data.find(b"RIFF")
    if riff_pos < 0:
        return None
    webp_size = struct.unpack_from("<I", data, riff_pos + 4)[0] + 8
    return data[riff_pos:riff_pos + webp_size]


def center_on_canvas(img: Image.Image, size: int = OUTPUT_SIZE) -> Image.Image:
    """Center image on a transparent square canvas."""
    if img.size == (size, size):
        return img
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - img.width) // 2
    y = (size - img.height) // 2
    canvas.paste(img, (x, y), img if img.mode == "RGBA" else None)
    return canvas


def find_best_ctex(name: str, cache_files: dict) -> str | None:
    """Find the best .ctex file for a sprite name (largest from 2025)."""
    # Try PascalCase first, then lowercase
    candidates = cache_files.get(name, []) + cache_files.get(name.lower(), [])
    if not candidates:
        return None
    # Pick the largest file (most detail)
    candidates.sort(key=lambda x: x[1], reverse=True)
    return candidates[0][0]


def main():
    print("=== V24.2 Sprite Recovery from Godot Cache ===\n")

    # Scan cache for 2025 .ctex files
    cache_files: dict[str, list[tuple[str, int]]] = {}
    for f in os.listdir(CACHE_DIR):
        if not f.endswith(".ctex"):
            continue
        path = os.path.join(CACHE_DIR, f)
        mtime = os.stat(path).st_mtime
        ts = time.localtime(mtime)
        if ts.tm_year != 2025:
            continue
        if ".png-" not in f:
            continue
        name = f.split(".png-")[0]
        size = os.path.getsize(path)
        if name not in cache_files:
            cache_files[name] = []
        cache_files[name].append((path, size))

    print(f"Found {len(cache_files)} unique sprites in cache from 2025\n")

    recovered = 0
    skipped = []

    for sprite_name in sorted(ANIMAL_NAMES | FOOD_NAMES):
        out_dir = ANIMALS_DIR if sprite_name in ANIMAL_NAMES else FOOD_DIR
        out_path = os.path.join(out_dir, f"{sprite_name}.png")

        ctex_path = find_best_ctex(sprite_name, cache_files)
        if ctex_path is None:
            print(f"  SKIP  {sprite_name} — not in cache (keeping current)")
            skipped.append(sprite_name)
            continue

        webp_data = extract_webp_from_ctex(ctex_path)
        if webp_data is None:
            print(f"  FAIL  {sprite_name} — no WebP data in .ctex")
            skipped.append(sprite_name)
            continue

        img = Image.open(io.BytesIO(webp_data)).convert("RGBA")
        original_size = img.size
        img = center_on_canvas(img)
        img.save(out_path, "PNG")

        size_kb = os.path.getsize(out_path) / 1024
        print(f"  OK    {sprite_name}.png  {original_size} -> {img.size}  {size_kb:.1f}KB")
        recovered += 1

    total = len(ANIMAL_NAMES) + len(FOOD_NAMES)
    print(f"\n=== Result: {recovered}/{total} recovered, {len(skipped)} kept as-is ===")
    if skipped:
        print(f"Kept current (Twemoji): {', '.join(skipped)}")


if __name__ == "__main__":
    main()
