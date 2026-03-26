#!/usr/bin/env python3
"""
Twemoji Asset Pipeline for ProjectKOS
Downloads cohesive emoji sprites from Twemoji CDN (CC-BY 4.0)
as 72x72 PNGs, then upscales to 512x512 with Pillow for game use.
"""

import os
import sys
import urllib.request

try:
    from PIL import Image
    import io
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

# Twemoji CDN base URL (72x72 pre-rendered PNGs)
TWEMOJI_BASE = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"

# Output directories
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ANIMAL_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "food")

OUTPUT_SIZE = 512

# Animal → Unicode codepoint (hex, lowercase)
ANIMALS = {
    "Bunny":     "1f430",
    "Dog":       "1f415",
    "Bear":      "1f43b",
    "Monkey":    "1f435",
    "Cat":       "1f431",
    "Chicken":   "1f414",
    "Cow":       "1f404",
    "Crocodile": "1f40a",
    "Frog":      "1f438",
    "Deer":      "1f98c",
    "Elephant":  "1f418",
    "Horse":     "1f434",
    "Lion":      "1f981",
    "Penguin":   "1f427",
    "Panda":     "1f43c",
    "Goat":      "1f410",
    "Mouse":     "1f42d",
    "Squirrel":  "1f43f",
    "Hedgehog":  "1f994",
}

# Food → Unicode codepoint (hex, lowercase)
FOODS = {
    "Carrot":     "1f955",
    "Bone":       "1f9b4",
    "Honey":      "1f36f",
    "Banana":     "1f34c",
    "Fish":       "1f41f",
    "Wheat":      "1f33e",
    "Grass":      "1f33f",
    "Drumstick":  "1f357",
    "Mosquito":   "1f99f",
    "Leaf":       "1f343",
    "Watermelon": "1f349",
    "Hay":        "1f33b",  # Sunflower — visually distinct from Wheat
    "Meat":       "1f969",
    "Shrimp":     "1f990",
    "Bamboo":     "1f38b",
    "Cabbage":    "1f96c",
    "Cheese":     "1f9c0",
    "Walnut":     "1f330",
    "Apple":      "1f34e",
}


def download_png(codepoint: str) -> bytes:
    """Download PNG from Twemoji CDN."""
    url = f"{TWEMOJI_BASE}/{codepoint}.png"
    req = urllib.request.Request(url, headers={"User-Agent": "ProjectKOS/1.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read()


def upscale_png(data: bytes, output_path: str, size: int = OUTPUT_SIZE) -> None:
    """Upscale PNG to target size using LANCZOS resampling."""
    img = Image.open(io.BytesIO(data)).convert("RGBA")
    img = img.resize((size, size), Image.LANCZOS)
    img.save(output_path, "PNG")


def process_set(mapping: dict, output_dir: str, label: str) -> int:
    """Download and upscale a set of emoji sprites. Returns success count."""
    os.makedirs(output_dir, exist_ok=True)
    success = 0
    for name, codepoint in mapping.items():
        output_path = os.path.join(output_dir, f"{name}.png")
        try:
            png_data = download_png(codepoint)
            upscale_png(png_data, output_path)
            size_kb = os.path.getsize(output_path) / 1024
            print(f"  OK  {label}/{name}.png  ({codepoint})  {size_kb:.1f}KB")
            success += 1
        except Exception as e:
            print(f"  FAIL {label}/{name}.png  ({codepoint}): {e}")
    return success


def main():
    print("=== Twemoji Asset Pipeline ===")
    print(f"Source: {TWEMOJI_BASE}")
    print(f"Output size: {OUTPUT_SIZE}x{OUTPUT_SIZE}")
    print(f"Animals dir: {ANIMAL_DIR}")
    print(f"Food dir:    {FOOD_DIR}")
    print()

    print(f"--- Downloading {len(ANIMALS)} animal sprites ---")
    animal_ok = process_set(ANIMALS, ANIMAL_DIR, "animals")
    print()

    print(f"--- Downloading {len(FOODS)} food sprites ---")
    food_ok = process_set(FOODS, FOOD_DIR, "foods")
    print()

    total = len(ANIMALS) + len(FOODS)
    ok = animal_ok + food_ok
    print(f"=== Done: {ok}/{total} sprites generated ===")

    if ok < total:
        print("WARNING: Some sprites failed!")
        sys.exit(1)
    else:
        print("All sprites downloaded and upscaled successfully.")
        print(f"License: Twemoji by Twitter — CC-BY 4.0")
        print(f"Attribution: https://twemoji.twitter.com/")


if __name__ == "__main__":
    main()
