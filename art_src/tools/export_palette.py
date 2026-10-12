"""Eksport palety: palette/gridfall_palette.png (1 px/kolor), .gpl (GIMP/Aseprite/Krita), .hex."""
import os

import config
import palette_def as pd
import pxlib as px

d = os.path.join(config.ART_SRC, "palette")
os.makedirs(d, exist_ok=True)
ents = pd.entries()
img = px.blank(len(ents), 1)
for i, (ch, *_r) in enumerate(ents):
    px.put(img, i, 0, ch)
px.save_png(img, os.path.join(d, "gridfall_palette.png"))
with open(os.path.join(d, "gridfall_palette.gpl"), "w", encoding="utf-8", newline="\n") as f:
    f.write("GIMP Palette\nName: Gridfall\nColumns: 8\n#\n")
    for ch, hx, name, ramp, pos in ents:
        r, g, b = pd.hex_to_rgb(hx)
        f.write(f"{r:3d} {g:3d} {b:3d}\t{ramp}_{pos}_{name} [{ch}]\n")
with open(os.path.join(d, "gridfall_palette.hex"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(hx for _, hx, *_r in ents) + "\n")
print("PALETTE OK", len(ents), "kolorów")
