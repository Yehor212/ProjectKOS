#!/usr/bin/env python3
"""
V25.0 — Process Gemini-generated sprites for game use.

Takes raw PNG images from Gemini Pro (with white backgrounds, suffix "1"),
removes the background, centers on 512x512 transparent canvas,
and saves as main RGBA PNG ready for Godot.

Workflow: Cat1.png (2048x2048 white bg) -> Cat.png (512x512 transparent)
Original *1.png files are NOT deleted.

Usage:
    python process_gemini_sprites.py
"""
import os
import sys
from PIL import Image
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ANIMALS_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "food")

OUTPUT_SIZE = 512

ANIMAL_NAMES = [
    "Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
    "Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse", "Lion",
    "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

FOOD_NAMES = [
    "Apple", "Bamboo", "Banana", "Bone", "Cabbage", "Carrot", "Cheese",
    "Drumstick", "Fish", "Grass", "Hay", "Honey", "Leaf", "Meat",
    "Mosquito", "Shrimp", "Walnut", "Watermelon", "Wheat",
]


def remove_white_background(img, tolerance=30):
    """Remove white/near-white background using connected components from edges."""
    img = img.convert("RGBA")
    arr = np.array(img)

    # Create mask: pixels that are "white-ish" (R,G,B all > 255-tolerance)
    threshold = 255 - tolerance
    white_mask = (
        (arr[:, :, 0] > threshold) &
        (arr[:, :, 1] > threshold) &
        (arr[:, :, 2] > threshold)
    )

    from scipy import ndimage

    # Label connected components of white pixels
    labeled, num_features = ndimage.label(white_mask)

    # Find which labels touch the border
    border_labels = set()
    border_labels.update(labeled[0, :].flatten())    # top
    border_labels.update(labeled[-1, :].flatten())   # bottom
    border_labels.update(labeled[:, 0].flatten())    # left
    border_labels.update(labeled[:, -1].flatten())   # right
    border_labels.discard(0)  # 0 = non-white pixels

    # Create background mask from border-touching white regions
    bg_mask = np.zeros_like(white_mask)
    for label_id in border_labels:
        bg_mask |= (labeled == label_id)

    # Set background pixels to transparent
    arr[bg_mask, 3] = 0

    return Image.fromarray(arr)


def remove_white_background_simple(img, tolerance=25):
    """Simple white background removal (fallback if scipy not available)."""
    img = img.convert("RGBA")
    data = list(img.getdata())
    threshold = 255 - tolerance
    new_data = []
    for r, g, b, a in data:
        if r > threshold and g > threshold and b > threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, a))
    img.putdata(new_data)
    return img


def trim_and_center(img, size=OUTPUT_SIZE):
    """Trim transparent borders and center on square canvas."""
    img = img.convert("RGBA")

    # Find bounding box of non-transparent pixels
    bbox = img.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Crop to content
    cropped = img.crop(bbox)

    # Scale to fit in canvas with 5% margin
    margin = int(size * 0.05)
    available = size - 2 * margin
    ratio = min(available / cropped.width, available / cropped.height)

    new_w = int(cropped.width * ratio)
    new_h = int(cropped.height * ratio)
    cropped = cropped.resize((new_w, new_h), Image.LANCZOS)

    # Center on canvas
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - cropped.width) // 2
    y = (size - cropped.height) // 2
    canvas.paste(cropped, (x, y), cropped)
    return canvas


def process_sprite(src_path, dst_path):
    """Process a single sprite: read *1.png, remove bg, center on 512x512, save as *.png."""
    img = Image.open(src_path).convert("RGBA")
    src_name = os.path.basename(src_path)
    dst_name = os.path.basename(dst_path)

    original_size = img.size

    # Remove white background
    print("  Removing white background...")
    try:
        img = remove_white_background(img)
    except ImportError:
        print("  (scipy not available, using simple threshold)")
        img = remove_white_background_simple(img)

    # Trim and center on 512x512
    img = trim_and_center(img)

    img.save(dst_path, "PNG")
    size_kb = os.path.getsize(dst_path) / 1024
    print("  OK    %s -> %s: %s -> %s (%.1fKB)" % (
        src_name, dst_name, original_size, img.size, size_kb))
    return True


def main():
    print("=== V25.0 Process Gemini Sprites ===")
    print("Workflow: *1.png (Gemini raw) -> *.png (512x512 transparent)\n")

    # Check scipy availability
    try:
        from scipy import ndimage
        print("Using scipy flood-fill for background removal\n")
    except ImportError:
        print("WARNING: scipy not installed, using simple threshold removal")
        print("For better results: pip install scipy\n")

    processed = 0
    missing = []

    print("--- Animals ---")
    for name in ANIMAL_NAMES:
        src = os.path.join(ANIMALS_DIR, "%s1.png" % name)
        dst = os.path.join(ANIMALS_DIR, "%s.png" % name)
        if not os.path.exists(src):
            print("  MISSING %s1.png" % name)
            missing.append(name)
            continue
        if process_sprite(src, dst):
            processed += 1

    print("\n--- Food ---")
    for name in FOOD_NAMES:
        src = os.path.join(FOOD_DIR, "%s1.png" % name)
        dst = os.path.join(FOOD_DIR, "%s.png" % name)
        if not os.path.exists(src):
            print("  MISSING %s1.png" % name)
            missing.append(name)
            continue
        if process_sprite(src, dst):
            processed += 1

    total = len(ANIMAL_NAMES) + len(FOOD_NAMES)
    print("\n=== Result: %d/%d processed, %d missing ===" % (
        processed, total, len(missing)))
    if missing:
        print("Missing source files: %s" % ", ".join(missing))
    else:
        print("All 38 sprites processed successfully!")


if __name__ == "__main__":
    main()
