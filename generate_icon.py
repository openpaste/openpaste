#!/usr/bin/env python3
"""Generate OpenPaste app icon - a modern clipboard manager icon."""

from PIL import Image, ImageDraw, ImageChops
import os

SIZE = 1024
ICON_DIR = "OpenPaste/Assets.xcassets/AppIcon.appiconset"


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_rounded_rect(draw, bbox, radius, fill):
    x1, y1, x2, y2 = [int(v) for v in bbox]
    r = int(radius)
    if hasattr(draw, 'rounded_rectangle'):
        draw.rounded_rectangle([x1, y1, x2, y2], radius=r, fill=fill)
    else:
        draw.rectangle([x1 + r, y1, x2 - r, y2], fill=fill)
        draw.rectangle([x1, y1 + r, x2, y2 - r], fill=fill)
        draw.pieslice([x1, y1, x1 + 2*r, y1 + 2*r], 180, 270, fill=fill)
        draw.pieslice([x2 - 2*r, y1, x2, y1 + 2*r], 270, 360, fill=fill)
        draw.pieslice([x1, y2 - 2*r, x1 + 2*r, y2], 90, 180, fill=fill)
        draw.pieslice([x2 - 2*r, y2 - 2*r, x2, y2], 0, 90, fill=fill)


def create_icon():
    canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))

    # === Rounded rect mask ===
    mask = Image.new('L', (SIZE, SIZE), 0)
    corner_radius = int(SIZE * 0.22)
    draw_rounded_rect(ImageDraw.Draw(mask), [0, 0, SIZE - 1, SIZE - 1], corner_radius, 255)

    # === Gradient background ===
    bg = Image.new('RGB', (SIZE, SIZE), (0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(SIZE):
        t = y / SIZE
        t = t * t * (3 - 2 * t)
        color = lerp_color((15, 30, 60), (0, 180, 180), t)
        bg_draw.line([(0, y), (SIZE, y)], fill=color)
    bg_rgba = bg.convert('RGBA')
    bg_rgba.putalpha(mask)
    canvas = Image.alpha_composite(canvas, bg_rgba)

    # === Subtle glow ===
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = int(SIZE * 0.3), int(SIZE * 0.25)
    for i in range(150):
        a = int(25 * (1 - i / 150))
        r = int(SIZE * 0.25) + i * 3
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, a))
    canvas = Image.alpha_composite(canvas, glow)

    # === Clipboard body ===
    cb_l, cb_r = int(SIZE * 0.22), int(SIZE * 0.78)
    cb_t, cb_b = int(SIZE * 0.20), int(SIZE * 0.88)
    cb_rad = int(SIZE * 0.06)

    # Shadow
    s = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_rounded_rect(ImageDraw.Draw(s), [cb_l+8, cb_t+12, cb_r+8, cb_b+12], cb_rad, (0, 0, 0, 70))
    canvas = Image.alpha_composite(canvas, s)

    # White body
    cb = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_rounded_rect(ImageDraw.Draw(cb), [cb_l, cb_t, cb_r, cb_b], cb_rad, (255, 255, 255, 240))
    canvas = Image.alpha_composite(canvas, cb)

    # === Clip (top) ===
    cw, ch = int(SIZE * 0.24), int(SIZE * 0.08)
    cx = (SIZE - cw) // 2
    cy = cb_t - ch // 2
    cr = int(SIZE * 0.025)
    cl = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    cl_draw = ImageDraw.Draw(cl)
    draw_rounded_rect(cl_draw, [cx, cy, cx + cw, cy + ch], cr, (50, 70, 90, 255))
    m = int(SIZE * 0.02)
    draw_rounded_rect(cl_draw, [cx+m, cy+m, cx+cw-m, cy+m+int(ch*0.5)], cr//2, (35, 55, 75, 255))
    canvas = Image.alpha_composite(canvas, cl)

    # === Text lines on clipboard ===
    lh = int(SIZE * 0.022)
    lr = lh // 2
    ly0 = int(SIZE * 0.34)
    lsp = int(SIZE * 0.055)
    ll = int(SIZE * 0.30)
    lines = [
        ((0, 160, 160, 200), 0.70),
        ((0, 140, 160, 160), 0.58),
        ((0, 160, 160, 200), 0.65),
        ((0, 140, 160, 160), 0.70),
        ((0, 160, 160, 120), 0.55),
    ]
    ll_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ll_draw = ImageDraw.Draw(ll_layer)
    for i, (col, rp) in enumerate(lines):
        y = ly0 + i * lsp
        draw_rounded_rect(ll_draw, [ll, y, int(SIZE * rp), y + lh], lr, col)
    canvas = Image.alpha_composite(canvas, ll_layer)

    # === Second card (paste overlay) - kept INSIDE icon bounds ===
    c2_l, c2_r = int(SIZE * 0.42), int(SIZE * 0.75)
    c2_t, c2_b = int(SIZE * 0.52), int(SIZE * 0.82)
    c2_rad = int(SIZE * 0.05)

    # Card shadow
    cs = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_rounded_rect(ImageDraw.Draw(cs), [c2_l+5, c2_t+7, c2_r+5, c2_b+7], c2_rad, (0, 0, 0, 50))
    canvas = Image.alpha_composite(canvas, cs)

    # Card body
    c2 = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_rounded_rect(ImageDraw.Draw(c2), [c2_l, c2_t, c2_r, c2_b], c2_rad, (235, 245, 255, 245))
    canvas = Image.alpha_composite(canvas, c2)

    # Lines on paste card
    c2l = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    c2l_d = ImageDraw.Draw(c2l)
    c2_lines = [
        ((0, 130, 200, 180), 0.70),
        ((0, 130, 200, 130), 0.60),
        ((0, 130, 200, 160), 0.67),
    ]
    c2ll = int(SIZE * 0.48)
    c2ly = int(SIZE * 0.58)
    for i, (col, rp) in enumerate(c2_lines):
        y = c2ly + i * int(SIZE * 0.05)
        draw_rounded_rect(c2l_d, [c2ll, y, int(SIZE * rp), y + lh], lr, col)
    canvas = Image.alpha_composite(canvas, c2l)

    # === Paste badge ===
    badge = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bx, by = int(SIZE * 0.70), int(SIZE * 0.52)
    br = int(SIZE * 0.055)
    bd.ellipse([bx-br, by-br, bx+br, by+br], fill=(0, 180, 180, 230))

    # Down arrow
    aw = int(SIZE * 0.018)
    al = int(SIZE * 0.022)
    bd.rectangle([bx-aw//2, by-al, bx+aw//2, by+al], fill=(255, 255, 255, 240))
    hs = int(SIZE * 0.018)
    bd.polygon([(bx, by+al+hs), (bx-hs-2, by+al-hs+3), (bx+hs+2, by+al-hs+3)],
               fill=(255, 255, 255, 240))
    canvas = Image.alpha_composite(canvas, badge)

    # === Final mask clip ===
    alpha = canvas.split()[3]
    canvas.putalpha(ImageChops.multiply(alpha, mask))

    return canvas


def export_sizes(img):
    os.makedirs(ICON_DIR, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
    }
    for fname, sz in sizes.items():
        img.resize((sz, sz), Image.LANCZOS).save(os.path.join(ICON_DIR, fname), "PNG")
        print(f"  ✓ {fname} ({sz}x{sz})")

    import json
    contents = {
        "images": [
            {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1}
    }
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("  ✓ Contents.json")


if __name__ == "__main__":
    print("🎨 Generating OpenPaste icon...")
    icon = create_icon()
    print("📐 Exporting all sizes...")
    export_sizes(icon)
    print("✅ Done! →", ICON_DIR)
