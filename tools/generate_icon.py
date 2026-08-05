#!/usr/bin/env python3
"""
TruthPulse アプリアイコン生成

キャラクター「ウソミ」の顔と伸びた鼻。App Store の一覧で他の
嘘発見器アプリと並んだときに、まず形で見分けがつくことを狙っています。

4096px で描いてから 1024px に縮小しています（アンチエイリアス目的）。
アイコンは透明を含められないので RGB で書き出します。

使い方:
    python3 tools/generate_icon.py
"""

import math
import os
from PIL import Image, ImageDraw

SS = 4                      # スーパーサンプリング倍率
OUT = 1024
S = OUT * SS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "TruthPulse", "Assets.xcassets", "AppIcon.appiconset")

# ブランドカラー
DEEP = (10, 13, 30)
TINT_TOP = (43, 10, 34)
TINT_BOTTOM = (18, 10, 50)
MAGENTA = (255, 61, 154)
MAGENTA_SOFT = (255, 143, 194)
AMBER = (255, 176, 32)
BODY = (42, 15, 51)
CYAN = (52, 229, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    """左上→右下の斜めグラデーション。行ごとに描いて軽く済ませる。"""
    img = Image.new("RGB", (S, S), DEEP)
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        if t < 0.5:
            c = lerp(TINT_TOP, DEEP, t / 0.5)
        else:
            c = lerp(DEEP, TINT_BOTTOM, (t - 0.5) / 0.5)
        d.line([(0, y), (S, y)], fill=c)
    return img


def add_glow(img, cx, cy, radius, color, strength=0.30):
    """中心から外へ弱まる発光。ピクセルごとだと遅いので同心円で近似する。"""
    d = ImageDraw.Draw(img, "RGBA")
    steps = 60
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        alpha = int(255 * strength * (1 - t) ** 2)
        if alpha <= 0:
            continue
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (alpha,))


def add_grid(img, spacing, color, alpha):
    d = ImageDraw.Draw(img, "RGBA")
    w = max(1, int(S * 0.0012))
    x = 0
    while x <= S:
        d.line([(x, 0), (x, S)], fill=color + (alpha,), width=w)
        x += spacing
    y = 0
    while y <= S:
        d.line([(0, y), (S, y)], fill=color + (alpha,), width=w)
        y += spacing


def draw_usomi(img):
    d = ImageDraw.Draw(img, "RGBA")

    # 顔は少し左に寄せて、右に鼻を伸ばす余白をつくる
    cx, cy = S * 0.40, S * 0.52
    r = S * 0.255

    # 角（体より先に描いて、根元を体で隠す）
    horn = S * 0.085
    for sign in (-1, 1):
        base_x = cx + sign * r * 0.62
        base_y = cy - r * 0.72
        tip_x = base_x + sign * horn * 0.55
        tip_y = base_y - horn * 1.5
        d.polygon(
            [(base_x - sign * horn * 0.42, base_y + horn * 0.30),
             (tip_x, tip_y),
             (base_x + sign * horn * 0.36, base_y + horn * 0.10)],
            fill=MAGENTA + (255,),
        )

    # 体
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BODY + (255,))
    d.ellipse([cx - r, cy - r, cx + r, cy + r],
              outline=MAGENTA + (255,), width=int(S * 0.011))

    # 目（鼻より上に置く。鼻とぶつからないよう高さを抑える）
    eye_dx = r * 0.40
    eye_dy = r * 0.34
    eye_w = r * 0.23
    eye_h = r * 0.27
    for sign in (-1, 1):
        ex = cx + sign * eye_dx
        ey = cy - eye_dy
        d.ellipse([ex - eye_w, ey - eye_h, ex + eye_w, ey + eye_h],
                  fill=(255, 255, 255, 245))
        pr = eye_w * 0.52
        d.ellipse([ex - pr, ey - pr + eye_h * 0.12,
                   ex + pr, ey + pr + eye_h * 0.12],
                  fill=(27, 20, 54, 255))

    # 鼻。顔の中心から始めて右へ突き抜ける（体の上に描く）
    nose_y0 = cy + r * 0.10
    nose_x0 = cx - r * 0.02
    nose_x1 = S * 0.950
    nose_y1 = nose_y0 + S * 0.040
    thickness = int(S * 0.055)
    d.line([(nose_x0, nose_y0), (nose_x1, nose_y1)],
           fill=AMBER + (255,), width=thickness)
    tip = thickness * 0.60
    d.ellipse([nose_x1 - tip, nose_y1 - tip, nose_x1 + tip, nose_y1 + tip],
              fill=AMBER + (255,))
    root = thickness * 0.52
    d.ellipse([nose_x0 - root, nose_y0 - root, nose_x0 + root, nose_y0 + root],
              fill=AMBER + (255,))

    # 口（への字＝嘘をついている顔）。鼻の下に置く
    mw = r * 0.34
    my = cy + r * 0.60
    d.arc([cx - mw, my - mw * 0.9, cx + mw, my + mw * 0.9],
          start=200, end=340, fill=MAGENTA_SOFT + (255,), width=int(S * 0.016))


def main():
    img = background()
    add_grid(img, spacing=int(S / 22), color=CYAN, alpha=12)
    add_glow(img, S * 0.40, S * 0.50, S * 0.62, MAGENTA, strength=0.34)
    draw_usomi(img)

    img = img.resize((OUT, OUT), Image.LANCZOS).convert("RGB")

    os.makedirs(ICON_DIR, exist_ok=True)
    path = os.path.join(ICON_DIR, "Icon-1024.png")
    img.save(path, "PNG")

    kb = os.path.getsize(path) / 1024
    print(f"生成: {path}")
    print(f"  {OUT}x{OUT}  {kb:.0f}KB  RGB（透明なし）")

    # 目視確認用の縮小版。Assets には入れない。
    preview_dir = os.path.join(ROOT, "mockups")
    os.makedirs(preview_dir, exist_ok=True)
    for size in (180, 120, 60):
        p = os.path.join(preview_dir, f"icon_preview_{size}.png")
        img.resize((size, size), Image.LANCZOS).save(p)
    print(f"確認用の縮小版: {preview_dir}/icon_preview_*.png")


if __name__ == "__main__":
    main()
