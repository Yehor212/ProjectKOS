#!/usr/bin/env python3
"""
V24.3 — Generate 6 missing sprites via Gemini API.

These sprites were not found in the Godot import cache and are currently
Twemoji fallbacks that don't match the original cartoon style.

Uses Gemini 2.0 Flash with image generation to create matching sprites.
Requires GEMINI_API_KEY or GOOGLE_API_KEY environment variable.
"""
import os
import sys
import io
import time
from PIL import Image

try:
    import google.generativeai as genai
except ImportError:
    print("ERROR: google-generativeai not installed. Run: pip install google-generativeai")
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
ANIMALS_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "sprites", "food")

OUTPUT_SIZE = 512

# Style description matching the original cartoon sprites
STYLE_PREFIX = (
    "Create a single cute cartoon clipart illustration for a children's educational game. "
    "Art style: thick dark brown outlines (3-4 pixels), warm saturated colors, soft color gradients, "
    "kawaii/cute proportions, simple and instantly recognizable shape. "
    "The image must have a completely transparent background (PNG with alpha channel). "
    "The subject should be centered and fill most of the frame. "
    "No text, no watermarks, no extra objects. Just the single item on transparent background. "
)

# Sprites to generate: (name, output_dir, prompt_suffix)
MISSING_SPRITES = [
    ("Monkey", ANIMALS_DIR,
     "A cute baby monkey sitting down, facing forward. Brown fur, light beige face and round belly, "
     "big round dark eyes with white highlights, small cute smile, long curly brown tail. "
     "Full body visible, sitting pose like a stuffed toy."),

    ("Banana", FOOD_DIR,
     "A single peeled banana. Bright yellow peel pulled back, creamy white banana visible inside. "
     "Cartoon style with thick outlines, warm yellow tones."),

    ("Drumstick", FOOD_DIR,
     "A cartoon chicken drumstick (cooked chicken leg). Golden brown crispy skin, "
     "white bone sticking out at the bottom. Simple, appetizing, cartoon food style."),

    ("Hay", FOOD_DIR,
     "A rectangular hay bale. Golden yellow dried straw/grass, tied with two brown rope straps. "
     "Some loose straw sticking out from top. Warm golden tones."),

    ("Shrimp", FOOD_DIR,
     "A cute cartoon shrimp (prawn). Pink-orange curved body with segments, "
     "small dark eye, thin antennae, fan-shaped tail. Simple cartoon seafood."),

    ("Watermelon", FOOD_DIR,
     "A triangular slice of watermelon. Bright red juicy flesh, black oval seeds, "
     "thin white rind layer, green outer rind. Cartoon fruit style."),
]


def remove_background(img: Image.Image, threshold: int = 240) -> Image.Image:
    """Remove near-white background pixels and make them transparent."""
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    for r, g, b, a in data:
        # If pixel is very light (near-white background), make transparent
        if r > threshold and g > threshold and b > threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append((r, g, b, a))
    img.putdata(new_data)
    return img


def center_on_canvas(img: Image.Image, size: int = OUTPUT_SIZE) -> Image.Image:
    """Center image on a transparent square canvas, fitting within size."""
    img = img.convert("RGBA")
    # Scale to fit within canvas
    ratio = min(size / img.width, size / img.height)
    if ratio < 1.0:
        new_w = int(img.width * ratio)
        new_h = int(img.height * ratio)
        img = img.resize((new_w, new_h), Image.LANCZOS)
    # Center on canvas
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - img.width) // 2
    y = (size - img.height) // 2
    canvas.paste(img, (x, y), img)
    return canvas


def has_transparency(img: Image.Image) -> bool:
    """Check if image actually has transparent pixels."""
    if img.mode != "RGBA":
        return False
    extrema = img.getextrema()
    return extrema[3][0] < 250  # Alpha channel min < 250 means some transparency


def generate_sprite(model, name: str, prompt: str) -> Image.Image | None:
    """Generate a sprite using Gemini API."""
    full_prompt = STYLE_PREFIX + prompt

    print(f"  Generating {name}...")
    try:
        response = model.generate_content(full_prompt)

        # Extract image from response
        for part in response.candidates[0].content.parts:
            if hasattr(part, "inline_data") and part.inline_data.mime_type.startswith("image/"):
                img_data = part.inline_data.data
                img = Image.open(io.BytesIO(img_data)).convert("RGBA")
                return img

        print(f"  WARNING: No image in response for {name}")
        # Try with text content
        if response.text:
            print(f"  Response text: {response.text[:200]}")
        return None

    except Exception as e:
        print(f"  ERROR generating {name}: {e}")
        return None


def main():
    # Configure API
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("ERROR: Set GEMINI_API_KEY or GOOGLE_API_KEY environment variable")
        sys.exit(1)

    genai.configure(api_key=api_key)

    # Use Gemini 2.0 Flash with image generation
    model = genai.GenerativeModel(
        "gemini-2.0-flash-exp",
        generation_config=genai.GenerationConfig(
            response_modalities=["TEXT", "IMAGE"],
        ),
    )

    print("=== V24.3 Generate Missing Sprites via Gemini ===\n")

    os.makedirs(ANIMALS_DIR, exist_ok=True)
    os.makedirs(FOOD_DIR, exist_ok=True)

    success = 0
    failed = []

    for name, out_dir, prompt in MISSING_SPRITES:
        out_path = os.path.join(out_dir, f"{name}.png")

        img = generate_sprite(model, name, prompt)

        if img is None:
            failed.append(name)
            continue

        print(f"  Raw image: {img.size} {img.mode}")

        # Check if background is transparent
        if not has_transparency(img):
            print(f"  Removing white background...")
            img = remove_background(img)

        # Center on 512x512 canvas
        img = center_on_canvas(img)
        img.save(out_path, "PNG")

        size_kb = os.path.getsize(out_path) / 1024
        print(f"  OK    {name}.png -> {img.size} {size_kb:.1f}KB")
        success += 1

        # Rate limiting
        time.sleep(2)

    print(f"\n=== Result: {success}/{len(MISSING_SPRITES)} generated ===")
    if failed:
        print(f"Failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
