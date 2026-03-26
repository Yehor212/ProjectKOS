#!/usr/bin/env python3
"""
Download Microsoft Fluent Emoji 3D PNGs for game icons.
Source: https://github.com/microsoft/fluentui-emoji
License: MIT — free for commercial use, no attribution required.
"""

import os
import urllib.request
import urllib.parse

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "textures", "game_icons")

BASE_URL = "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/"

# icon_id -> (folder_name, file_name)
ICON_MAP = {
    "fork_knife":  ("Fork and knife", "fork_and_knife"),
    "ghost":       ("Ghost", "ghost"),
    "brain":       ("Brain", "brain"),
    "bubble":      ("Bubbles", "bubbles"),
    "diamond":     ("Gem stone", "gem_stone"),
    "numbers":     ("Input numbers", "input_numbers"),
    "puzzle":      ("Puzzle piece", "puzzle_piece"),
    "magnifier":   ("Magnifying glass tilted left", "magnifying_glass_tilted_left"),
    "pencil":      ("Pencil", "pencil"),
    "music_note":  ("Musical notes", "musical_notes"),
    "cycle":       ("Counterclockwise arrows button", "counterclockwise_arrows_button"),
    "scales":      ("Balance scale", "balance_scale"),
    "folder":      ("File folder", "file_folder"),
    "ruler":       ("Straight ruler", "straight_ruler"),
    "factory":     ("Factory", "factory"),
    "soap":        ("Soap", "soap"),
    "weather":     ("Sun", "sun"),
    "flag":        ("Triangular flag", "triangular_flag"),
    "palette":     ("Artist palette", "artist_palette"),
    "robot":       ("Robot", "robot"),
    "money":       ("Money bag", "money_bag"),
    "recycle":     ("Recycling symbol", "recycling_symbol"),
    "knight":      ("Chess pawn", "chess_pawn"),
    "beaker":      ("Test tube", "test_tube"),
    "target":      ("Bullseye", "bullseye"),
    "letters":     ("Input latin letters", "input_latin_letters"),
    "planet":      ("Ringed planet", "ringed_planet"),
    "clock":       ("Alarm clock", "alarm_clock"),
    "star":        ("Star", "star"),
}


def download(icon_id: str, folder: str, filename: str) -> bool:
    """Download a single Fluent 3D emoji PNG."""
    path = f"{folder}/3D/{filename}_3d.png"
    encoded = urllib.parse.quote(path, safe="/")
    url = BASE_URL + encoded
    out_path = os.path.join(OUT_DIR, f"icon_{icon_id}.png")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ProjectKOS-icon-downloader/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
        with open(out_path, "wb") as f:
            f.write(data)
        print(f"  OK: icon_{icon_id}.png ({len(data):,} bytes)")
        return True
    except Exception as e:
        print(f"  FAIL: icon_{icon_id}.png — {e}")
        return False


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Downloading Microsoft Fluent Emoji 3D (MIT license)")
    print(f"Output: {OUT_DIR}\n")

    success = 0
    failed = []

    for icon_id, (folder, filename) in ICON_MAP.items():
        print(f"[{icon_id}]", end="")
        if download(icon_id, folder, filename):
            success += 1
        else:
            failed.append(icon_id)

    print(f"\n{'='*50}")
    print(f"RESULT: {success}/{len(ICON_MAP)} icons downloaded")
    if failed:
        print(f"FAILED: {', '.join(failed)}")
    else:
        print("All icons downloaded successfully!")


if __name__ == "__main__":
    main()
