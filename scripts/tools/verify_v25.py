#!/usr/bin/env python3
"""V25.0 End-to-End Verification Script."""
import os
from PIL import Image
import numpy as np

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ANIMALS_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "food")

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


def main():
    print("=== V25.0 End-to-End Verification ===\n")

    all_pass = True
    checked = 0

    # CHECK 1: All 38 sprites = 512x512 RGBA with transparent bg
    print("--- CHECK 1: Sprite format (512x512 RGBA, transparent bg) ---")
    for category, names, dir_path in [("Animal", ANIMAL_NAMES, ANIMALS_DIR), ("Food", FOOD_NAMES, FOOD_DIR)]:
        for name in names:
            path = os.path.join(dir_path, "%s.png" % name)
            if not os.path.exists(path):
                print("  FAIL  %s.png MISSING" % name)
                all_pass = False
                continue

            img = Image.open(path).convert("RGBA")
            arr = np.array(img)
            size_ok = img.size == (512, 512)

            corners = [arr[0, 0, 3], arr[0, -1, 3], arr[-1, 0, 3], arr[-1, -1, 3]]
            transparent_corners = sum(1 for c in corners if c < 10)
            bg_ok = transparent_corners >= 3

            size_kb = os.path.getsize(path) / 1024

            if size_ok and bg_ok:
                print("  PASS  %s/%s.png  512x512  corners=%d/4  %.1fKB" % (
                    category, name, transparent_corners, size_kb))
                checked += 1
            else:
                status = []
                if not size_ok:
                    status.append("size=%dx%d" % img.size)
                if not bg_ok:
                    status.append("corners=%d/4" % transparent_corners)
                print("  FAIL  %s/%s.png  %s" % (category, name, ", ".join(status)))
                all_pass = False

    print()

    # CHECK 2: Original *1.png files still exist
    print("--- CHECK 2: Original *1.png files preserved ---")
    originals_ok = 0
    originals_missing = []
    for names, dir_path in [(ANIMAL_NAMES, ANIMALS_DIR), (FOOD_NAMES, FOOD_DIR)]:
        for name in names:
            src = os.path.join(dir_path, "%s1.png" % name)
            if os.path.exists(src):
                originals_ok += 1
            else:
                originals_missing.append(name)

    if originals_ok == 38:
        print("  PASS  All 38 original *1.png files preserved")
    else:
        print("  FAIL  %d/38 originals, missing: %s" % (originals_ok, ", ".join(originals_missing)))
        all_pass = False

    print()

    # CHECK 3: Names match GameData
    print("--- CHECK 3: Names match game_data.gd ---")
    gd_path = os.path.join(PROJECT_ROOT, "game", "scripts", "game_data.gd")
    if os.path.exists(gd_path):
        with open(gd_path, "r", encoding="utf-8") as f:
            gd_content = f.read()

        gd_ok = 0
        gd_missing = []

        for name in ANIMAL_NAMES + FOOD_NAMES:
            if ('"%s"' % name) in gd_content:
                gd_ok += 1
            else:
                gd_missing.append(name)

        if gd_ok == 38:
            print("  PASS  All 38 names found in game_data.gd")
        else:
            print("  FAIL  Missing: %s" % ", ".join(gd_missing))
            all_pass = False
    else:
        print("  SKIP  game_data.gd not found")

    print()

    # CHECK 4: Font file
    print("--- CHECK 4: Font file ---")
    font_path = os.path.join(PROJECT_ROOT, "game", "assets", "fonts", "Nunito-Bold.ttf")
    if os.path.exists(font_path):
        size_kb = os.path.getsize(font_path) / 1024
        print("  PASS  Nunito-Bold.ttf exists (%.1fKB)" % size_kb)
    else:
        print("  FAIL  Nunito-Bold.ttf MISSING")
        all_pass = False

    print()

    # CHECK 5: Menu text verification
    print("--- CHECK 5: Menu text (translations + fallback) ---")
    csv_path = os.path.join(PROJECT_ROOT, "game", "assets", "translations", "translations.csv")
    if os.path.exists(csv_path):
        with open(csv_path, "r", encoding="utf-8") as f:
            csv_content = f.read()
        required_keys = ["TITLE_GAME", "BTN_PLAY", "BTN_SETTINGS", "BTN_SHOP", "BTN_QUIT"]
        keys_found = 0
        for key in required_keys:
            if key in csv_content:
                keys_found += 1
            else:
                print("  FAIL  Missing key: %s" % key)
                all_pass = False
        if keys_found == len(required_keys):
            print("  PASS  All %d translation keys present" % keys_found)
    else:
        print("  SKIP  translations.csv not found")

    tscn_path = os.path.join(PROJECT_ROOT, "game", "scenes", "ui", "main_menu.tscn")
    if os.path.exists(tscn_path):
        with open(tscn_path, "r", encoding="utf-8") as f:
            tscn_content = f.read()
        has_ukr = all(text in tscn_content for text in ["Грати", "Налаштування", "Магазин", "Вийти"])
        no_font_ext = "ext_resource" not in tscn_content.lower() or "font" not in tscn_content.lower()
        if has_ukr:
            print("  PASS  Ukrainian fallback text in main_menu.tscn")
        else:
            print("  FAIL  Missing Ukrainian fallback text")
            all_pass = False
        # Check no font ExtResource
        has_font_ext = False
        for line in tscn_content.split("\n"):
            if "ext_resource" in line.lower() and "font" in line.lower():
                has_font_ext = True
                break
        if not has_font_ext:
            print("  PASS  No font ExtResource refs (theme inheritance OK)")
        else:
            print("  WARN  Font ExtResource found in main_menu.tscn")

    print()

    # CHECK 6: Visual spot check (file sizes reasonable)
    print("--- CHECK 6: File size sanity check ---")
    sizes = []
    for names, dir_path in [(ANIMAL_NAMES, ANIMALS_DIR), (FOOD_NAMES, FOOD_DIR)]:
        for name in names:
            path = os.path.join(dir_path, "%s.png" % name)
            if os.path.exists(path):
                sizes.append(os.path.getsize(path) / 1024)
    if sizes:
        avg = sum(sizes) / len(sizes)
        mn = min(sizes)
        mx = max(sizes)
        print("  INFO  Size range: %.1f - %.1fKB (avg %.1fKB)" % (mn, mx, avg))
        if mn > 50 and mx < 500:
            print("  PASS  All sizes reasonable (50-500KB range)")
        else:
            print("  WARN  Some sizes outside expected range")

    print()

    # SUMMARY
    print("=" * 50)
    print("SPRITES:  %d/38 verified (512x512 RGBA transparent)" % checked)
    print("ORIGINALS: %d/38 *1.png preserved" % originals_ok)
    print("OVERALL:  %s" % ("ALL PASS" if all_pass else "SOME FAILURES"))
    print("=" * 50)


if __name__ == "__main__":
    main()
