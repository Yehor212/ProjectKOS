"""
V24.0 Beautiful Sprite Generator — Cute, recognizable cartoon animals & food for kids.
Uses Pillow with 2x supersample + LANCZOS downsample for smooth anti-aliased edges.
Features: soft drop shadows, 3-layer gradient fills, large kawaii eyes with sparkle,
warm rosy cheeks, detailed shapes. Output: 512x512 RGBA PNGs.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter

# Render at 2x then downsample for anti-aliasing
RENDER_SIZE = 1024
OUTPUT_SIZE = 512
OUTLINE_W = 10
BG = (0, 0, 0, 0)

ANIMALS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sprites", "animals")
FOOD_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "sprites", "food")
BG_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "backgrounds")
ICON_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "icons")

S = RENDER_SIZE  # shorthand


def new_canvas():
    return Image.new("RGBA", (S, S), BG)


def finalize(img):
    """Downsample from render size to output size with LANCZOS."""
    return img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)


def add_shadow(img, offset=(6, 8), blur_radius=12, opacity=60):
    """Add a soft drop shadow behind all visible pixels."""
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = img.split()[3]
    shadow_layer = Image.new("RGBA", img.size, (0, 0, 0, opacity))
    shadow.paste(shadow_layer, offset, alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))
    shadow.paste(img, (0, 0), img)
    return shadow


# --- Drawing helpers ---

def ellipse(draw, bbox, fill, outline_color=(40, 35, 30, 255), width=OUTLINE_W):
    draw.ellipse(bbox, fill=fill, outline=outline_color, width=width)


def circle(draw, cx, cy, r, fill, outline_color=(40, 35, 30, 255), width=OUTLINE_W):
    ellipse(draw, [cx - r, cy - r, cx + r, cy + r], fill, outline_color, width)


def rounded_rect(draw, bbox, fill, radius=30, outline_color=(40, 35, 30, 255), width=OUTLINE_W):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline_color, width=width)


def gradient_ellipse(draw, bbox, base_color, highlight_shift=40):
    """Draw ellipse with 3-layer gradient for smooth depth."""
    draw.ellipse(bbox, fill=base_color, outline=(40, 35, 30, 255), width=OUTLINE_W)
    cx = (bbox[0] + bbox[2]) // 2
    cy = (bbox[1] + bbox[3]) // 2
    w = (bbox[2] - bbox[0]) // 2
    h = (bbox[3] - bbox[1]) // 2
    a = base_color[3] if len(base_color) > 3 else 255
    # Mid layer
    mw, mh = int(w * 0.7), int(h * 0.7)
    mid = (min(255, base_color[0] + highlight_shift // 2),
           min(255, base_color[1] + highlight_shift // 2),
           min(255, base_color[2] + highlight_shift // 2), a)
    draw.ellipse([cx - mw, cy - mh - h // 8, cx + mw, cy + mh - h // 8], fill=mid, width=0)
    # Bright center highlight
    iw, ih = int(w * 0.45), int(h * 0.45)
    highlight = (min(255, base_color[0] + highlight_shift),
                 min(255, base_color[1] + highlight_shift),
                 min(255, base_color[2] + highlight_shift), a)
    draw.ellipse([cx - iw, cy - ih - h // 5, cx + iw, cy + ih - h // 5], fill=highlight, width=0)


def gradient_circle(draw, cx, cy, r, base_color, highlight_shift=40):
    gradient_ellipse(draw, [cx - r, cy - r, cx + r, cy + r], base_color, highlight_shift)


def kawaii_eye(draw, cx, cy, r=32):
    """Big kawaii eye with iris, pupil, and sparkle highlights."""
    # White sclera
    circle(draw, cx, cy, r, (255, 255, 255, 255), width=OUTLINE_W)
    # Dark iris
    iris_r = int(r * 0.7)
    circle(draw, cx + 2, cy + 3, iris_r, (45, 40, 35, 255), width=0)
    # Primary sparkle (top-left)
    hl_r = int(r * 0.3)
    circle(draw, cx - int(r * 0.22), cy - int(r * 0.25), hl_r, (255, 255, 255, 255), width=0)
    # Secondary sparkle (bottom-right)
    hl2_r = int(r * 0.17)
    circle(draw, cx + int(r * 0.22), cy + int(r * 0.18), hl2_r, (255, 255, 255, 255), width=0)


def kawaii_eyes(draw, cx, cy, spread=90, r=32):
    kawaii_eye(draw, cx - spread // 2, cy, r)
    kawaii_eye(draw, cx + spread // 2, cy, r)


def blush(draw, cx, cy, r=30):
    """Warm visible pink blush — opacity 140 for clear visibility."""
    circle(draw, cx, cy, r, (255, 140, 160, 140), width=0)


def blush_pair(draw, cx, cy, spread=110, r=30):
    blush(draw, cx - spread // 2, cy, r)
    blush(draw, cx + spread // 2, cy, r)


def smile(draw, cx, cy, w=40, h=16):
    draw.arc([cx - w, cy - h, cx + w, cy + h], 10, 170, fill=(60, 50, 45, 255), width=6)


def triangle(draw, pts, fill, outline_color=(40, 35, 30, 255), width=OUTLINE_W):
    draw.polygon(pts, fill=fill, outline=outline_color, width=width)


# --- ANIMALS ---

def draw_bunny():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (225, 220, 230, 255)
    inner_ear = (255, 185, 195, 255)
    # Long upright ears
    ellipse(d, [300, 20, 390, 360], body_color)
    ellipse(d, [318, 60, 372, 340], inner_ear, width=0)
    ellipse(d, [610, 20, 700, 360], body_color)
    ellipse(d, [628, 60, 682, 340], inner_ear, width=0)
    # Round body
    gradient_ellipse(d, [260, 490, 740, 880], body_color)
    # Head
    gradient_ellipse(d, [280, 280, 720, 660], body_color, 30)
    # Face
    kawaii_eyes(d, 500, 430, 150, 32)
    d.polygon([(485, 530), (515, 530), (500, 555)], fill=(255, 150, 165, 255), outline=(40, 35, 30, 255))
    smile(d, 500, 575, 35)
    blush_pair(d, 500, 520, 200)
    # Cotton tail
    circle(d, 680, 720, 35, (255, 255, 255, 255))
    # Feet
    ellipse(d, [310, 800, 440, 880], body_color)
    ellipse(d, [560, 800, 690, 880], body_color)
    return add_shadow(finalize(img))


def draw_dog():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (210, 160, 100, 255)
    belly_color = (245, 220, 180, 255)
    ear_color = (170, 115, 70, 255)
    # Floppy ears (curved down)
    ellipse(d, [180, 270, 310, 560], ear_color)
    ellipse(d, [690, 270, 820, 560], ear_color)
    # Body
    gradient_ellipse(d, [270, 500, 730, 840], body_color)
    ellipse(d, [340, 550, 660, 790], belly_color, width=0)
    # Head
    gradient_ellipse(d, [290, 190, 710, 590], body_color, 30)
    ellipse(d, [360, 370, 640, 570], belly_color, width=0)
    # Face
    kawaii_eyes(d, 500, 360, 130, 30)
    circle(d, 500, 460, 22, (55, 45, 40, 255), width=0)
    # Tongue sticking out
    ellipse(d, [480, 510, 520, 575], (255, 140, 150, 255))
    smile(d, 500, 510, 35)
    blush_pair(d, 500, 470, 180)
    # Collar
    d.arc([340, 530, 660, 620], 10, 170, fill=(220, 60, 60, 255), width=12)
    # Feet
    ellipse(d, [320, 770, 440, 850], body_color)
    ellipse(d, [560, 770, 680, 850], body_color)
    return add_shadow(finalize(img))


def draw_bear():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (175, 115, 70, 255)
    belly_color = (225, 185, 140, 255)
    # Round ears
    gradient_circle(d, 310, 195, 70, body_color)
    circle(d, 310, 195, 40, belly_color, width=0)
    gradient_circle(d, 690, 195, 70, body_color)
    circle(d, 690, 195, 40, belly_color, width=0)
    # Big round body
    gradient_ellipse(d, [250, 490, 750, 890], body_color)
    ellipse(d, [330, 550, 670, 840], belly_color, width=0)
    # Head
    gradient_ellipse(d, [270, 190, 730, 590], body_color, 25)
    ellipse(d, [370, 400, 630, 575], belly_color)
    # Face
    kawaii_eyes(d, 500, 360, 140, 30)
    circle(d, 500, 460, 20, (55, 45, 40, 255), width=0)
    smile(d, 500, 510, 35)
    blush_pair(d, 500, 470, 200)
    # Feet
    ellipse(d, [290, 810, 420, 890], body_color)
    ellipse(d, [580, 810, 710, 890], body_color)
    return add_shadow(finalize(img))


def draw_monkey():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (170, 110, 65, 255)
    face_color = (245, 210, 175, 255)
    ear_outer = (200, 155, 115, 255)
    # Big round ears
    gradient_circle(d, 240, 400, 75, ear_outer)
    circle(d, 240, 400, 45, face_color, width=0)
    gradient_circle(d, 760, 400, 75, ear_outer)
    circle(d, 760, 400, 45, face_color, width=0)
    # Body
    gradient_ellipse(d, [300, 550, 700, 870], body_color)
    ellipse(d, [370, 600, 630, 820], (235, 195, 155, 255), width=0)
    # Head — larger
    gradient_ellipse(d, [290, 180, 710, 590], body_color, 25)
    # Large distinct face area
    ellipse(d, [330, 290, 670, 580], face_color, width=0)
    # Face
    kawaii_eyes(d, 500, 380, 120, 30)
    # Heart-shaped nose area
    circle(d, 500, 470, 16, (55, 45, 40, 255), width=0)
    smile(d, 500, 510, 35)
    blush_pair(d, 500, 470, 170)
    # Curly tail
    d.arc([660, 700, 830, 870], 0, 300, fill=body_color, width=14)
    return add_shadow(finalize(img))


def draw_cat():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (255, 175, 90, 255)
    inner_ear = (255, 210, 160, 255)
    # Pointy ears
    triangle(d, [(310, 140), (235, 345), (405, 335)], body_color)
    d.polygon([(320, 175), (260, 325), (385, 320)], fill=inner_ear)
    triangle(d, [(690, 140), (595, 335), (765, 345)], body_color)
    d.polygon([(680, 175), (615, 320), (740, 325)], fill=inner_ear)
    # Body
    gradient_ellipse(d, [270, 510, 730, 860], body_color)
    # Head
    gradient_ellipse(d, [280, 270, 720, 620], body_color, 30)
    # Face
    kawaii_eyes(d, 500, 400, 130, 30)
    d.polygon([(488, 490), (512, 490), (500, 512)], fill=(255, 155, 165, 255), outline=(40, 35, 30, 255))
    # Whiskers
    for dy in [-8, 8]:
        d.line([(260, 500 + dy), (395, 492 + dy)], fill=(40, 35, 30, 255), width=4)
        d.line([(605, 492 + dy), (740, 500 + dy)], fill=(40, 35, 30, 255), width=4)
    smile(d, 500, 540, 28)
    blush_pair(d, 500, 500, 180)
    # Curved tail
    d.arc([690, 600, 870, 830], 180, 350, fill=body_color, width=22)
    return add_shadow(finalize(img))


def draw_chicken():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (255, 255, 245, 255)
    # Larger red comb
    for i in range(3):
        cx = 430 + i * 50
        circle(d, cx, 135, 38, (230, 55, 50, 255))
    # Round body
    gradient_ellipse(d, [260, 250, 740, 740], body_color, 20)
    # Wing
    ellipse(d, [540, 390, 730, 640], (245, 245, 230, 255))
    # Face
    kawaii_eyes(d, 500, 380, 110, 26)
    # Beak
    d.polygon([(460, 470), (540, 470), (500, 525)], fill=(255, 195, 60, 255), outline=(40, 35, 30, 255))
    # Wattle
    ellipse(d, [478, 520, 522, 575], (230, 60, 55, 255))
    blush_pair(d, 500, 450, 160)
    # Feet
    d.line([(400, 730), (400, 830), (355, 855)], fill=(255, 195, 60, 255), width=10)
    d.line([(400, 830), (430, 860)], fill=(255, 195, 60, 255), width=10)
    d.line([(600, 730), (600, 830), (555, 855)], fill=(255, 195, 60, 255), width=10)
    d.line([(600, 830), (630, 860)], fill=(255, 195, 60, 255), width=10)
    return add_shadow(finalize(img))


def draw_cow():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (255, 255, 255, 255)
    spot_color = (90, 70, 55, 255)
    # Horns
    d.arc([290, 90, 390, 240], 180, 360, fill=(230, 210, 160, 255), width=16)
    d.arc([610, 90, 710, 240], 180, 360, fill=(230, 210, 160, 255), width=16)
    # Floppy ears
    ellipse(d, [220, 240, 315, 360], body_color)
    ellipse(d, [685, 240, 780, 360], body_color)
    # Body with spots
    gradient_ellipse(d, [260, 510, 740, 880], body_color, 15)
    circle(d, 380, 640, 42, spot_color, width=0)
    circle(d, 630, 710, 35, spot_color, width=0)
    # Head
    gradient_ellipse(d, [285, 195, 715, 570], body_color, 15)
    circle(d, 380, 315, 40, spot_color, width=0)
    circle(d, 630, 350, 32, spot_color, width=0)
    # Face
    kawaii_eyes(d, 500, 350, 130, 30)
    # Muzzle
    ellipse(d, [380, 440, 620, 565], (245, 210, 190, 255))
    circle(d, 455, 495, 10, (60, 50, 45, 255), width=0)
    circle(d, 545, 495, 10, (60, 50, 45, 255), width=0)
    smile(d, 500, 535, 30)
    blush_pair(d, 500, 455, 190)
    return add_shadow(finalize(img))


def draw_crocodile():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (90, 175, 80, 255)
    belly_color = (180, 230, 130, 255)
    # Body
    gradient_ellipse(d, [210, 420, 790, 780], body_color)
    ellipse(d, [310, 530, 690, 740], belly_color, width=0)
    # Longer snout head
    rounded_rect(d, [220, 220, 780, 550], body_color, radius=70)
    rounded_rect(d, [265, 285, 735, 430], (110, 195, 100, 255), radius=50, width=0)
    # Eyes
    kawaii_eyes(d, 500, 300, 160, 26)
    # Nostrils
    circle(d, 430, 365, 9, (55, 90, 45, 255), width=0)
    circle(d, 570, 365, 9, (55, 90, 45, 255), width=0)
    # Teeth — more detail
    for x in range(300, 700, 32):
        d.polygon([(x, 430), (x + 10, 470), (x + 20, 430)], fill=(255, 255, 255, 255), outline=(40, 35, 30, 255))
    smile(d, 500, 490, 55, 14)
    blush_pair(d, 500, 395, 210)
    # Scaly bumps on back
    for bx in range(340, 680, 50):
        circle(d, bx, 415, 8, (75, 155, 65, 255), width=0)
    # Tail
    d.arc([700, 650, 900, 830], 90, 270, fill=body_color, width=24)
    return add_shadow(finalize(img))


def draw_frog():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (90, 205, 95, 255)
    belly_color = (195, 245, 155, 255)
    # Body
    gradient_ellipse(d, [260, 420, 740, 840], body_color)
    ellipse(d, [330, 510, 670, 780], belly_color, width=0)
    # Head
    gradient_ellipse(d, [270, 230, 730, 570], body_color, 30)
    # Bulging eyes
    gradient_circle(d, 350, 240, 60, body_color, 35)
    gradient_circle(d, 650, 240, 60, body_color, 35)
    kawaii_eye(d, 350, 240, 36)
    kawaii_eye(d, 650, 240, 36)
    # Wide mouth smile
    d.arc([300, 380, 700, 540], 10, 170, fill=(40, 35, 30, 255), width=7)
    blush_pair(d, 500, 430, 220)
    # Webbed feet
    for x in [310, 560]:
        ellipse(d, [x, 780, x + 130, 870], body_color)
    return add_shadow(finalize(img))


def draw_deer():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (210, 155, 95, 255)
    face_color = (240, 210, 165, 255)
    antler = (155, 110, 70, 255)
    # Larger antlers
    d.line([(360, 220), (320, 90), (280, 45)], fill=antler, width=14)
    d.line([(320, 90), (360, 55)], fill=antler, width=14)
    d.line([(320, 140), (270, 110)], fill=antler, width=12)
    d.line([(640, 220), (680, 90), (720, 45)], fill=antler, width=14)
    d.line([(680, 90), (640, 55)], fill=antler, width=14)
    d.line([(680, 140), (730, 110)], fill=antler, width=12)
    # Ears
    ellipse(d, [235, 250, 325, 375], body_color)
    ellipse(d, [675, 250, 765, 375], body_color)
    # Body
    gradient_ellipse(d, [275, 540, 725, 880], body_color)
    # Head
    gradient_ellipse(d, [295, 210, 705, 580], (215, 165, 105, 255), 30)
    ellipse(d, [375, 430, 625, 570], face_color, width=0)
    # White spots on body
    for sx, sy in [(350, 620), (500, 600), (650, 630)]:
        circle(d, sx, sy, 12, (240, 215, 175, 255), width=0)
    # Face
    kawaii_eyes(d, 500, 370, 115, 30)
    circle(d, 500, 475, 15, (55, 45, 40, 255), width=0)
    smile(d, 500, 520, 28)
    blush_pair(d, 500, 470, 170)
    return add_shadow(finalize(img))


# PART 2: Remaining animals will follow below

def draw_elephant():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (170, 185, 210, 255)
    inner_ear = (200, 210, 230, 255)
    # Bigger flappy ears
    gradient_ellipse(d, [150, 210, 360, 630], body_color)
    ellipse(d, [185, 265, 335, 580], inner_ear, width=0)
    gradient_ellipse(d, [640, 210, 850, 630], body_color)
    ellipse(d, [665, 265, 815, 580], inner_ear, width=0)
    # Body
    gradient_ellipse(d, [285, 500, 715, 850], body_color)
    # Head
    gradient_ellipse(d, [305, 180, 695, 590], body_color, 25)
    # Face
    kawaii_eyes(d, 500, 340, 105, 30)
    # Longer trunk
    d.arc([440, 420, 560, 750], 0, 180, fill=body_color, width=40)
    d.arc([440, 420, 560, 750], 0, 180, fill=(40, 35, 30, 255), width=8)
    # Trunk curl at bottom
    circle(d, 560, 735, 18, body_color, width=6)
    blush_pair(d, 500, 450, 170)
    # Feet
    ellipse(d, [310, 780, 430, 870], body_color)
    ellipse(d, [570, 780, 690, 870], body_color)
    # Toenails
    for fx in [345, 385]:
        circle(d, fx, 860, 8, (200, 210, 225, 255), width=0)
    for fx in [605, 645]:
        circle(d, fx, 860, 8, (200, 210, 225, 255), width=0)
    return add_shadow(finalize(img))


def draw_horse():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (195, 145, 90, 255)
    mane_color = (155, 100, 60, 255)
    muzzle_color = (230, 195, 155, 255)
    # Forelock / mane on top
    for i in range(6):
        cy = 150 + i * 45
        cx = 500 + int(math.sin(i * 0.5) * 15)
        circle(d, cx, cy, 42, mane_color, width=0)
    # Ears
    triangle(d, [(360, 120), (330, 235), (400, 230)], body_color)
    triangle(d, [(640, 120), (600, 230), (670, 235)], body_color)
    # Body
    gradient_ellipse(d, [270, 520, 730, 860], body_color)
    # Head
    gradient_ellipse(d, [295, 195, 705, 570], body_color, 25)
    # Muzzle
    ellipse(d, [370, 440, 630, 580], muzzle_color)
    # Face
    kawaii_eyes(d, 500, 350, 110, 30)
    circle(d, 440, 500, 8, (60, 50, 45, 255), width=0)
    circle(d, 560, 500, 8, (60, 50, 45, 255), width=0)
    smile(d, 500, 545, 28)
    blush_pair(d, 500, 455, 170)
    return add_shadow(finalize(img))


def draw_lion():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (240, 195, 80, 255)
    mane_color = (230, 160, 45, 255)
    # Fluffy mane — more circles for fullness
    for angle in range(0, 360, 20):
        rad = math.radians(angle)
        cx = 500 + int(175 * math.cos(rad))
        cy = 400 + int(175 * math.sin(rad))
        circle(d, cx, cy, 75, mane_color, outline_color=(200, 135, 30, 255), width=5)
    # Body
    gradient_ellipse(d, [290, 600, 710, 880], body_color)
    # Face
    gradient_circle(d, 500, 400, 150, body_color, 30)
    kawaii_eyes(d, 500, 370, 85, 30)
    circle(d, 500, 435, 18, (90, 60, 35, 255), width=0)
    smile(d, 500, 480, 35)
    blush_pair(d, 500, 445, 150)
    # Tail with tuft
    d.arc([670, 720, 860, 870], 90, 300, fill=body_color, width=12)
    circle(d, 770, 720, 20, mane_color, width=0)
    return add_shadow(finalize(img))


def draw_penguin():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (50, 55, 70, 255)
    belly_color = (245, 248, 255, 255)
    # Rounder body with tuxedo pattern
    gradient_ellipse(d, [265, 270, 735, 850], body_color)
    # White belly — larger, rounder
    ellipse(d, [320, 360, 680, 810], belly_color, width=0)
    # Head
    gradient_ellipse(d, [300, 160, 700, 500], body_color)
    # Face
    kawaii_eyes(d, 500, 320, 90, 28)
    # Orange beak
    d.polygon([(460, 395), (540, 395), (500, 445)], fill=(255, 185, 50, 255), outline=(40, 35, 30, 255))
    blush_pair(d, 500, 380, 140)
    # Wide orange feet
    ellipse(d, [300, 800, 440, 890], (255, 185, 50, 255))
    ellipse(d, [560, 800, 700, 890], (255, 185, 50, 255))
    # Flippers
    ellipse(d, [215, 390, 310, 700], body_color)
    ellipse(d, [690, 390, 785, 700], body_color)
    # Bow tie for cuteness
    d.polygon([(470, 510), (500, 530), (530, 510)], fill=(255, 70, 70, 255), outline=(40, 35, 30, 255))
    d.polygon([(470, 550), (500, 530), (530, 550)], fill=(255, 70, 70, 255), outline=(40, 35, 30, 255))
    return add_shadow(finalize(img))


def draw_panda():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_white = (252, 252, 255, 255)
    body_black = (50, 50, 50, 255)
    # Round ears
    gradient_circle(d, 315, 195, 65, body_black)
    gradient_circle(d, 685, 195, 65, body_black)
    # Body
    gradient_ellipse(d, [275, 510, 725, 870], body_white, 10)
    # Black arms
    ellipse(d, [205, 540, 310, 730], body_black)
    ellipse(d, [690, 540, 795, 730], body_black)
    # Head
    gradient_ellipse(d, [285, 185, 715, 570], body_white, 10)
    # Eye patches
    ellipse(d, [335, 310, 445, 430], body_black, width=0)
    ellipse(d, [555, 310, 665, 430], body_black, width=0)
    # Eyes
    kawaii_eye(d, 390, 370, 26)
    kawaii_eye(d, 610, 370, 26)
    # Nose
    circle(d, 500, 465, 18, body_black, width=0)
    smile(d, 500, 505, 28)
    blush_pair(d, 500, 460, 190)
    return add_shadow(finalize(img))


def draw_goat():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (240, 235, 225, 255)
    horn_color = (190, 175, 150, 255)
    # Curved horns — larger, more visible
    d.arc([300, 40, 420, 240], 150, 340, fill=horn_color, width=18)
    d.arc([580, 40, 700, 240], 200, 30, fill=horn_color, width=18)
    # Pointy ears
    triangle(d, [(250, 300), (220, 420), (330, 380)], body_color)
    triangle(d, [(750, 300), (670, 380), (780, 420)], body_color)
    # Rectangular body (not snowman!)
    rounded_rect(d, [280, 540, 720, 860], body_color, radius=40)
    ellipse(d, [350, 590, 650, 820], (250, 245, 235, 255), width=0)
    # Smaller head (proportional)
    gradient_ellipse(d, [300, 210, 700, 550], body_color, 15)
    ellipse(d, [380, 400, 620, 540], (250, 245, 238, 255), width=0)
    # Face
    kawaii_eyes(d, 500, 350, 105, 30)
    circle(d, 500, 450, 13, (55, 50, 45, 255), width=0)
    smile(d, 500, 490, 25)
    blush_pair(d, 500, 440, 160)
    # Beard tuft
    for bx in range(460, 545, 14):
        d.line([(bx, 540), (bx - 5, 620)], fill=(220, 215, 200, 255), width=6)
    # Hooves
    ellipse(d, [310, 830, 410, 890], (100, 85, 70, 255))
    ellipse(d, [590, 830, 690, 890], (100, 85, 70, 255))
    return add_shadow(finalize(img))


def draw_mouse():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (195, 195, 205, 255)
    inner_ear = (255, 200, 200, 255)
    belly_color = (230, 230, 240, 255)
    # Bigger round ears
    gradient_circle(d, 310, 210, 105, body_color)
    circle(d, 310, 210, 65, inner_ear, width=0)
    gradient_circle(d, 690, 210, 105, body_color)
    circle(d, 690, 210, 65, inner_ear, width=0)
    # Body
    gradient_ellipse(d, [300, 510, 700, 820], body_color)
    ellipse(d, [370, 560, 630, 780], belly_color, width=0)
    # Head
    gradient_ellipse(d, [310, 270, 690, 590], (200, 200, 212, 255), 25)
    # Face
    kawaii_eyes(d, 500, 380, 95, 26)
    circle(d, 500, 465, 15, (255, 160, 170, 255), width=0)
    # Whiskers
    for dy in [-8, 8]:
        d.line([(275, 480 + dy), (395, 470 + dy)], fill=(40, 35, 30, 255), width=3)
        d.line([(605, 470 + dy), (725, 480 + dy)], fill=(40, 35, 30, 255), width=3)
    smile(d, 500, 510, 22)
    blush_pair(d, 500, 480, 160)
    # Longer curvy tail
    d.arc([620, 680, 870, 900], 90, 320, fill=body_color, width=10)
    d.arc([750, 600, 900, 760], 200, 340, fill=body_color, width=10)
    return add_shadow(finalize(img))


def draw_squirrel():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (195, 130, 60, 255)
    belly_color = (250, 215, 165, 255)
    tail_color = (215, 140, 55, 255)
    # Tail — reduced 40%, behind body
    gradient_ellipse(d, [630, 280, 830, 650], tail_color)
    ellipse(d, [650, 310, 810, 510], (240, 175, 90, 255), width=0)
    # Pointy ears with tufts
    triangle(d, [(340, 145), (310, 260), (385, 255)], body_color)
    circle(d, 348, 150, 10, (215, 145, 65, 255), width=0)
    triangle(d, [(655, 145), (615, 255), (690, 260)], body_color)
    circle(d, 648, 150, 10, (215, 145, 65, 255), width=0)
    # Bigger body
    gradient_ellipse(d, [270, 510, 730, 870], body_color)
    ellipse(d, [340, 570, 660, 830], belly_color, width=0)
    # Head
    gradient_ellipse(d, [290, 200, 710, 580], body_color, 25)
    ellipse(d, [380, 390, 620, 560], belly_color, width=0)
    # Face
    kawaii_eyes(d, 500, 360, 100, 26)
    circle(d, 500, 445, 13, (55, 45, 40, 255), width=0)
    smile(d, 500, 490, 22)
    blush_pair(d, 500, 450, 160)
    # Tiny paws holding something
    circle(d, 380, 580, 18, body_color)
    circle(d, 620, 580, 18, body_color)
    return add_shadow(finalize(img))


def draw_hedgehog():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (215, 175, 125, 255)
    belly_color = (250, 225, 185, 255)
    spine_color = (155, 115, 70, 255)
    # Spines around top
    for angle in range(-150, -30, 11):
        rad = math.radians(angle)
        bx = 500 + int(235 * math.cos(rad))
        by = 490 + int(235 * math.sin(rad))
        tx = 500 + int(350 * math.cos(rad))
        ty = 490 + int(350 * math.sin(rad))
        d.polygon([(bx - 24, by), (tx, ty), (bx + 24, by)], fill=spine_color, outline=(115, 85, 50, 255), width=3)
    for angle in range(210, 330, 11):
        rad = math.radians(angle)
        bx = 500 + int(235 * math.cos(rad))
        by = 490 + int(235 * math.sin(rad))
        tx = 500 + int(350 * math.cos(rad))
        ty = 490 + int(350 * math.sin(rad))
        d.polygon([(bx - 24, by), (tx, ty), (bx + 24, by)], fill=spine_color, outline=(115, 85, 50, 255), width=3)
    # Body
    gradient_ellipse(d, [260, 370, 740, 810], body_color)
    ellipse(d, [320, 490, 680, 770], belly_color, width=0)
    # Head
    gradient_ellipse(d, [315, 285, 685, 590], (225, 190, 145, 255), 25)
    # Face
    kawaii_eyes(d, 500, 405, 95, 28)
    circle(d, 500, 485, 15, (55, 45, 40, 255), width=0)
    smile(d, 500, 530, 25)
    blush_pair(d, 500, 490, 160)
    # Feet
    ellipse(d, [330, 760, 430, 830], body_color)
    ellipse(d, [570, 760, 670, 830], body_color)
    return add_shadow(finalize(img))


# --- FOOD ---

def draw_carrot():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # Green leaves
    for dx in [-45, 0, 45]:
        d.polygon([(500 + dx, 100), (465 + dx, 280), (535 + dx, 280)], fill=(75, 195, 75, 255), outline=(40, 140, 35, 255), width=5)
    # Orange body
    d.polygon([(350, 280), (650, 280), (500, 870)], fill=(255, 175, 60, 255), outline=(40, 35, 30, 255), width=OUTLINE_W)
    # Highlight
    d.polygon([(420, 300), (500, 300), (475, 720)], fill=(255, 205, 105, 255), width=0)
    # Texture lines
    for y in [400, 510, 640]:
        d.arc([385, y - 15, 615, y + 15], 10, 170, fill=(240, 145, 40, 255), width=5)
    return add_shadow(finalize(img))


def draw_bone():
    img = new_canvas(); d = ImageDraw.Draw(img)
    bone_color = (250, 245, 235, 255)
    rounded_rect(d, [290, 430, 710, 570], bone_color, radius=16)
    for x in [290, 670]:
        gradient_circle(d, x, 420, 55, bone_color, 15)
        gradient_circle(d, x, 580, 55, bone_color, 15)
    d.line([(340, 460), (660, 460)], fill=(255, 255, 255, 255), width=8)
    return add_shadow(finalize(img))


def draw_honey():
    img = new_canvas(); d = ImageDraw.Draw(img)
    jar_color = (255, 220, 90, 255)
    # Jar body
    rounded_rect(d, [300, 320, 700, 810], jar_color, radius=24)
    # Highlight
    rounded_rect(d, [330, 350, 460, 760], (255, 235, 130, 255), radius=15, width=0)
    # Lid
    rounded_rect(d, [345, 270, 655, 345], (210, 165, 55, 255), radius=12)
    # Label
    rounded_rect(d, [330, 500, 670, 650], (255, 255, 245, 255), radius=12, outline_color=(210, 165, 55, 255))
    # Honey bee on label
    circle(d, 500, 575, 22, (255, 210, 60, 255), width=3)
    d.line([(485, 565), (515, 585)], fill=(55, 45, 35, 255), width=3)
    d.line([(485, 585), (515, 565)], fill=(55, 45, 35, 255), width=3)
    # Honey drip
    ellipse(d, [640, 360, 720, 430], (255, 200, 50, 255), width=0)
    return add_shadow(finalize(img))


def draw_banana():
    img = new_canvas(); d = ImageDraw.Draw(img)
    d.arc([130, 160, 870, 810], 200, 340, fill=(255, 230, 60, 255), width=115)
    d.arc([130, 160, 870, 810], 200, 340, fill=(40, 35, 30, 255), width=8)
    # Stem
    rounded_rect(d, [655, 155, 700, 265], (155, 120, 60, 255), radius=8)
    # Tip
    circle(d, 320, 735, 16, (135, 100, 50, 255), width=0)
    # Highlight
    d.arc([160, 190, 840, 780], 220, 310, fill=(255, 245, 120, 255), width=32)
    return add_shadow(finalize(img))


def draw_fish():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (95, 195, 250, 255)
    belly_color = (195, 230, 255, 255)
    # Tail fin
    d.polygon([(200, 370), (120, 430), (120, 580), (200, 650), (200, 510)], fill=(60, 165, 235, 255), outline=(40, 35, 30, 255))
    # Body
    gradient_ellipse(d, [200, 330, 810, 680], body_color, 35)
    # Belly
    ellipse(d, [280, 490, 750, 660], belly_color, width=0)
    # Scales pattern
    for sx, sy in [(400, 440), (500, 420), (600, 440), (350, 500), (450, 480), (550, 480), (650, 500)]:
        d.arc([sx - 20, sy - 15, sx + 20, sy + 15], 30, 150, fill=(70, 170, 230, 200), width=3)
    # Eye
    kawaii_eye(d, 680, 460, 32)
    # Gill mark
    circle(d, 760, 530, 10, (215, 110, 110, 255), width=0)
    # Dorsal fin
    d.polygon([(420, 340), (460, 235), (570, 340)], fill=(70, 175, 245, 255), outline=(40, 35, 30, 255))
    return add_shadow(finalize(img))


def draw_wheat():
    img = new_canvas(); d = ImageDraw.Draw(img)
    grain_color = (240, 210, 80, 255)
    # Stem
    d.line([(500, 830), (500, 200)], fill=(195, 175, 70, 255), width=10)
    # Grain pairs
    for i, y in enumerate([240, 300, 360, 420, 490]):
        offset = 32 + i * 5
        ellipse(d, [500 - offset - 35, y - 20, 500 - offset, y + 20], grain_color)
        ellipse(d, [500 + offset, y - 20, 500 + offset + 35, y + 20], grain_color)
    # Top grain
    ellipse(d, [475, 170, 525, 250], grain_color)
    return add_shadow(finalize(img))


def draw_grass():
    img = new_canvas(); d = ImageDraw.Draw(img)
    grass_g = (90, 215, 95, 255)
    dark_g = (60, 175, 60, 255)
    light_g = (140, 240, 140, 255)
    # More blades, varied heights
    blades = [(280, 510, -22), (350, 580, -12), (420, 630, -5), (500, 680, 0),
              (580, 640, 6), (650, 570, 15), (720, 500, 24)]
    for cx, h, lean in blades:
        pts = [(cx - 20, 850), (cx + lean, 850 - h), (cx + 20, 850)]
        d.polygon(pts, fill=grass_g, outline=dark_g, width=5)
        # Center vein
        d.line([(cx + lean // 2, 850 - h + 20), (cx + 2, 850 - 20)], fill=light_g, width=4)
    # Dewdrops
    for dx, dy in [(340, 520), (500, 400), (640, 490)]:
        circle(d, dx, dy, 8, (200, 240, 255, 200), width=0)
        circle(d, dx - 2, dy - 2, 3, (255, 255, 255, 255), width=0)
    return add_shadow(finalize(img))


def draw_drumstick():
    img = new_canvas(); d = ImageDraw.Draw(img)
    bone_color = (250, 245, 235, 255)
    meat_color = (215, 115, 70, 255)
    # Bone handle
    rounded_rect(d, [220, 560, 390, 830], bone_color, radius=18)
    gradient_circle(d, 310, 810, 32, bone_color, 15)
    # Meat body
    gradient_ellipse(d, [300, 190, 800, 650], meat_color, 35)
    ellipse(d, [400, 275, 700, 530], (240, 155, 95, 255), width=0)
    return add_shadow(finalize(img))


def draw_mosquito():
    img = new_canvas(); d = ImageDraw.Draw(img)
    body_color = (90, 80, 70, 255)
    wing_color = (215, 230, 250, 140)
    # Larger transparent wings
    ellipse(d, [210, 150, 420, 410], wing_color, outline_color=(180, 195, 215, 200))
    ellipse(d, [580, 150, 790, 410], wing_color, outline_color=(180, 195, 215, 200))
    # Body
    gradient_ellipse(d, [390, 300, 610, 730], body_color)
    # Head
    gradient_circle(d, 500, 280, 60, (100, 90, 80, 255))
    kawaii_eyes(d, 500, 270, 55, 20)
    # Proboscis
    d.line([(500, 230), (500, 110)], fill=(110, 100, 90, 255), width=8)
    # More visible legs
    for side in [-1, 1]:
        for dy in [0, 55, 110]:
            sx = 500 + side * 75
            ex = 500 + side * 185
            d.line([(sx, 440 + dy), (ex, 490 + dy)], fill=(90, 80, 70, 255), width=6)
    return add_shadow(finalize(img))


def draw_leaf():
    img = new_canvas(); d = ImageDraw.Draw(img)
    leaf_color = (95, 205, 70, 255)
    # Leaf shape
    d.polygon([(500, 110), (770, 490), (500, 830), (230, 490)], fill=leaf_color, outline=(50, 145, 35, 255), width=OUTLINE_W)
    # Highlight
    d.polygon([(500, 155), (630, 490), (500, 710), (390, 490)], fill=(130, 225, 105, 255), width=0)
    # Central vein
    d.line([(500, 140), (500, 800)], fill=(60, 155, 45, 255), width=7)
    # Side veins
    for y in [310, 420, 540, 660]:
        d.line([(500, y), (360, y - 55)], fill=(60, 155, 45, 255), width=4)
        d.line([(500, y), (640, y - 55)], fill=(60, 155, 45, 255), width=4)
    # Stem
    d.line([(500, 800), (500, 910)], fill=(135, 100, 55, 255), width=10)
    return add_shadow(finalize(img))


def draw_watermelon():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # Green rind
    d.pieslice([165, 200, 835, 830], 180, 360, fill=(60, 175, 60, 255), outline=(40, 35, 30, 255), width=OUTLINE_W)
    # White inner rind
    d.pieslice([190, 235, 810, 810], 180, 360, fill=(230, 245, 230, 255), width=0)
    # Red flesh
    d.pieslice([215, 265, 785, 790], 180, 360, fill=(250, 70, 70, 255), width=0)
    # Highlight
    d.pieslice([245, 285, 575, 655], 180, 360, fill=(255, 110, 100, 255), width=0)
    # Seeds
    for sx, sy in [(360, 415), (500, 395), (640, 415), (420, 465), (570, 465)]:
        ellipse(d, [sx - 9, sy - 15, sx + 9, sy + 15], (40, 35, 30, 255), width=0)
    return add_shadow(finalize(img))


def draw_hay():
    img = new_canvas(); d = ImageDraw.Draw(img)
    hay_color = (230, 200, 115, 255)
    dark_hay = (195, 165, 80, 255)
    strap_color = (175, 135, 60, 255)
    # Hay bale
    rounded_rect(d, [245, 360, 755, 830], hay_color, radius=24)
    rounded_rect(d, [275, 385, 500, 800], (245, 220, 145, 255), radius=18, width=0)
    # Texture lines
    for y in [435, 515, 600, 685, 760]:
        d.line([(275, y), (725, y)], fill=dark_hay, width=5)
    # Straps
    d.line([(370, 360), (370, 830)], fill=strap_color, width=9)
    d.line([(630, 360), (630, 830)], fill=strap_color, width=9)
    # Straw sticking out
    d.line([(320, 360), (300, 280)], fill=hay_color, width=7)
    d.line([(500, 360), (520, 270)], fill=hay_color, width=7)
    d.line([(670, 360), (690, 300)], fill=hay_color, width=7)
    return add_shadow(finalize(img))


def draw_meat():
    img = new_canvas(); d = ImageDraw.Draw(img)
    meat_color = (215, 85, 65, 255)
    # T-bone steak shape — clear bone
    # Main meat
    gradient_ellipse(d, [200, 280, 800, 740], meat_color, 35)
    # Pink/red gradient areas
    ellipse(d, [280, 360, 730, 660], (240, 130, 95, 255), width=0)
    # Bone — T shape clearly visible
    rounded_rect(d, [470, 300, 530, 720], (250, 245, 235, 255), radius=10)
    d.line([(370, 470), (630, 470)], fill=(250, 245, 235, 255), width=20)
    # Bone outline
    rounded_rect(d, [470, 300, 530, 720], (250, 245, 235, 255), radius=10, outline_color=(40, 35, 30, 255), width=4)
    d.line([(370, 460), (630, 460)], fill=(40, 35, 30, 255), width=4)
    d.line([(370, 480), (630, 480)], fill=(40, 35, 30, 255), width=4)
    # Fat marbling
    d.arc([310, 380, 460, 580], 200, 340, fill=(255, 210, 195, 255), width=8)
    d.arc([550, 400, 720, 600], 200, 340, fill=(255, 210, 195, 255), width=8)
    return add_shadow(finalize(img))


def draw_shrimp():
    img = new_canvas(); d = ImageDraw.Draw(img)
    shrimp_color = (250, 155, 115, 255)
    # Segmented body
    for i, y in enumerate([320, 390, 460, 530, 600]):
        w = 105 - i * 10
        ellipse(d, [500 - w, y - 26, 500 + w, y + 26], shrimp_color)
    # Head
    gradient_ellipse(d, [340, 220, 660, 370], shrimp_color, 30)
    kawaii_eye(d, 565, 290, 20)
    # Tail fan
    d.polygon([(425, 620), (360, 745), (500, 700), (640, 745), (575, 620)], fill=(255, 175, 135, 255), outline=(40, 35, 30, 255))
    # Antennae
    d.arc([360, 120, 520, 270], 180, 310, fill=(215, 135, 90, 255), width=6)
    d.arc([460, 100, 650, 250], 230, 360, fill=(215, 135, 90, 255), width=6)
    return add_shadow(finalize(img))


def draw_bamboo():
    img = new_canvas(); d = ImageDraw.Draw(img)
    bamboo_g = (115, 195, 80, 255)
    dark_g = (80, 155, 55, 255)
    # Main stalk
    rounded_rect(d, [425, 70, 575, 920], bamboo_g, radius=14)
    rounded_rect(d, [440, 80, 510, 910], (150, 220, 115, 255), radius=10, width=0)
    # Nodes
    for y in [230, 400, 570, 730]:
        rounded_rect(d, [415, y - 10, 585, y + 10], dark_g, radius=6, width=0)
    # Leaves
    for lx, ly, flip in [(300, 190, -1), (660, 360, 1), (270, 530, -1), (690, 670, 1)]:
        pts = [(lx, ly), (lx + 90 * flip, ly - 50), (lx + 55 * flip, ly + 18)]
        d.polygon(pts, fill=(95, 185, 70, 255), outline=dark_g, width=3)
    return add_shadow(finalize(img))


def draw_cabbage():
    img = new_canvas(); d = ImageDraw.Draw(img)
    outer = (135, 215, 95, 255)
    inner = (175, 235, 115, 255)
    core = (205, 245, 145, 255)
    # Outer leaves
    for dx, dy in [(-55, 40), (55, 40), (0, -40), (-40, 55), (40, 55)]:
        gradient_ellipse(d, [265 + dx, 265 + dy, 735 + dx, 775 + dy], outer)
    # Inner layers
    gradient_circle(d, 500, 510, 135, inner, 30)
    circle(d, 500, 500, 90, core, width=0)
    d.arc([365, 400, 635, 610], 200, 340, fill=(115, 195, 80, 255), width=5)
    return add_shadow(finalize(img))


def draw_cheese():
    img = new_canvas(); d = ImageDraw.Draw(img)
    cheese_color = (255, 220, 70, 255)
    cheese_top = (255, 235, 95, 255)
    # Side face
    d.polygon([(165, 685), (835, 685), (835, 325)], fill=cheese_color, outline=(40, 35, 30, 255), width=OUTLINE_W)
    d.polygon([(195, 675), (505, 675), (505, 415)], fill=(255, 235, 110, 255), width=0)
    # Top face
    d.polygon([(165, 685), (835, 325), (700, 265), (85, 615)], fill=cheese_top, outline=(40, 35, 30, 255), width=OUTLINE_W)
    # Holes
    for hx, hy, hr in [(475, 570, 30), (685, 535, 24), (365, 630, 22), (615, 610, 18)]:
        circle(d, hx, hy, hr, (240, 195, 40, 255), width=0)
    return add_shadow(finalize(img))


def draw_walnut():
    img = new_canvas(); d = ImageDraw.Draw(img)
    shell_color = (185, 135, 80, 255)
    # Main shell
    gradient_ellipse(d, [240, 260, 760, 740], shell_color, 35)
    # Center crack line
    d.line([(500, 280), (500, 730)], fill=(145, 100, 55, 255), width=8)
    # Shell texture — brain-like ridges
    d.arc([290, 310, 490, 520], 20, 160, fill=(155, 110, 60, 255), width=5)
    d.arc([510, 310, 710, 520], 20, 160, fill=(155, 110, 60, 255), width=5)
    d.arc([300, 430, 490, 650], 200, 340, fill=(155, 110, 60, 255), width=5)
    d.arc([510, 430, 700, 650], 200, 340, fill=(155, 110, 60, 255), width=5)
    d.arc([330, 530, 480, 700], 30, 150, fill=(155, 110, 60, 255), width=5)
    d.arc([520, 530, 670, 700], 30, 150, fill=(155, 110, 60, 255), width=5)
    # Lighter inside peeking through crack
    ellipse(d, [340, 340, 490, 540], (210, 165, 110, 255), width=0)
    ellipse(d, [510, 360, 660, 550], (210, 165, 110, 255), width=0)
    return add_shadow(finalize(img))


def draw_apple():
    img = new_canvas(); d = ImageDraw.Draw(img)
    apple_color = (235, 50, 50, 255)
    # Main apple
    gradient_ellipse(d, [235, 280, 765, 830], apple_color, 40)
    # Highlight
    ellipse(d, [290, 325, 520, 595], (250, 95, 85, 255), width=0)
    # Stem
    rounded_rect(d, [480, 195, 520, 310], (135, 90, 50, 255), radius=6)
    # Leaf
    d.polygon([(520, 245), (650, 185), (580, 280)], fill=(95, 195, 70, 255), outline=(50, 135, 35, 255), width=3)
    # Dimple at top
    d.arc([415, 245, 585, 345], 210, 330, fill=(195, 35, 35, 255), width=7)
    return add_shadow(finalize(img))


# --- BACKGROUNDS & ICONS ---


def upscale_icon_1024():
    """Upscale current 512x512 icon to 1024x1024 using LANCZOS."""
    src_path = os.path.join(ICON_DIR, "icon.png")
    if not os.path.exists(src_path):
        print(f"  Icon source not found: {src_path}")
        return None
    img = Image.open(src_path)
    return img.resize((1024, 1024), Image.LANCZOS)


# --- MAIN ---

ANIMALS = {
    "Bunny": draw_bunny, "Dog": draw_dog, "Bear": draw_bear, "Monkey": draw_monkey,
    "Cat": draw_cat, "Chicken": draw_chicken, "Cow": draw_cow, "Crocodile": draw_crocodile,
    "Frog": draw_frog, "Deer": draw_deer, "Elephant": draw_elephant, "Horse": draw_horse,
    "Lion": draw_lion, "Penguin": draw_penguin, "Panda": draw_panda, "Goat": draw_goat,
    "Mouse": draw_mouse, "Squirrel": draw_squirrel, "Hedgehog": draw_hedgehog,
}

FOOD = {
    "Carrot": draw_carrot, "Bone": draw_bone, "Honey": draw_honey, "Banana": draw_banana,
    "Fish": draw_fish, "Wheat": draw_wheat, "Grass": draw_grass, "Drumstick": draw_drumstick,
    "Mosquito": draw_mosquito, "Leaf": draw_leaf, "Watermelon": draw_watermelon,
    "Hay": draw_hay, "Meat": draw_meat, "Shrimp": draw_shrimp, "Bamboo": draw_bamboo,
    "Cabbage": draw_cabbage, "Cheese": draw_cheese, "Walnut": draw_walnut, "Apple": draw_apple,
}


def main():
    os.makedirs(ANIMALS_DIR, exist_ok=True)
    os.makedirs(FOOD_DIR, exist_ok=True)
    os.makedirs(BG_DIR, exist_ok=True)
    os.makedirs(ICON_DIR, exist_ok=True)

    print("Generating 19 animal sprites (V24.0, 2x supersample)...")
    for name, func in ANIMALS.items():
        path = os.path.join(ANIMALS_DIR, f"{name}.png")
        img = func()
        img.save(path)
        print(f"  {name}.png ({img.size[0]}x{img.size[1]})")

    print("Generating 19 food sprites (V24.0, 2x supersample)...")
    for name, func in FOOD.items():
        path = os.path.join(FOOD_DIR, f"{name}.png")
        img = func()
        img.save(path)
        print(f"  {name}.png ({img.size[0]}x{img.size[1]})")

    print("Upscaling icon to 1024x1024...")
    icon_img = upscale_icon_1024()
    if icon_img:
        icon_path = os.path.join(ICON_DIR, "icon_1024.png")
        icon_img.save(icon_path)
        print(f"  icon_1024.png ({icon_img.size[0]}x{icon_img.size[1]})")

    total = len(ANIMALS) + len(FOOD)
    print(f"\nDone! {len(ANIMALS)} animals + {len(FOOD)} food + 1 background + 1 icon = {total + 2} assets")


if __name__ == "__main__":
    main()
