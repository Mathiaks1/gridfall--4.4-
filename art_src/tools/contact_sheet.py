"""Contact sheet kategorii: każdy sheet animacji (wszystkie klatki) + ikony na polu odkrytym.

  python art_src/tools/contact_sheet.py monsters [hero ...]
Zapis: art_src/previews/contact_<kategoria>_{1x,3x,3x_gray}.png
"""
import json
import os
import sys

import config
import pxlib as px

G = 4


def build(category):
    d = os.path.join(config.OUT_ROOT, category)
    rev_path = os.path.join(config.OUT_ROOT, "tiles", "tile_revealed.png")
    revealed = px.load_png(rev_path) if os.path.exists(rev_path) else None
    rows, icons = [], []
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        img = px.load_png(os.path.join(d, f))
        meta_path = os.path.join(d, f[:-4] + ".json")
        meta = json.load(open(meta_path, encoding="utf-8")) if os.path.exists(meta_path) else {}
        if "frame_width" in meta:
            w = meta["frame_width"]
            rows.append([img[:, i * w:(i + 1) * w] for i in range(meta["frames"])])
        else:
            if revealed is not None and img.shape[:2] == revealed.shape[:2]:
                t = revealed.copy()
                px.blit(t, img, 0, 0)
                img = t
            icons.append(img)
    width = max([sum(f.shape[1] + G for f in r) for r in rows] + [sum(i.shape[1] + G for i in icons), 0]) + G
    height = G + sum(r[0].shape[0] + G for r in rows) + (max((i.shape[0] for i in icons), default=0) + G)
    sheet = px.blank(width, height)
    px.fill(sheet, 0, 0, width, height, "0")
    y = G
    for r in rows:
        x = G
        for f in r:
            px.blit(sheet, f, x, y)
            x += f.shape[1] + G
        y += r[0].shape[0] + G
    x = G
    for i in icons:
        px.blit(sheet, i, x, y)
        x += i.shape[1] + G
    out = config.PREVIEW_DIR
    px.save_png(sheet, os.path.join(out, f"contact_{category}_1x.png"))
    px.save_png(px.upscale(sheet, 3), os.path.join(out, f"contact_{category}_3x.png"))
    px.save_png(px.upscale(px.grayscale(sheet), 3), os.path.join(out, f"contact_{category}_3x_gray.png"))
    print("CONTACT OK", category, f"{len(rows)} animacji, {len(icons)} pojedynczych")


for c in sys.argv[1:]:
    build(c)
