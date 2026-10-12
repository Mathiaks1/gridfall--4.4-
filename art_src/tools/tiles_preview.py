"""Contact sheet partii „pola”: nakładki na właściwych podkładach + warianty kontrolne.

  python art_src/tools/tiles_preview.py
"""
import os

import config
import pxlib as px

A = config.OUT_ROOT
C = config.CELL


def L(rel):
    return px.load_png(os.path.join(A, rel + ".png"))


def comp(base, *overlays):
    t = base.copy()
    for o in overlays:
        px.blit(t, o, 0, 0)
    return t


H, R = L("tiles/tile_hidden"), L("tiles/tile_revealed")
rows = [
    [comp(R, L(f"tiles/tile_number_{n}")) for n in range(1, 9)],
    [comp(R, L("tiles/overlay_trap")), comp(L("tiles/tile_revealed_danger"), L("tiles/overlay_trap")),
     comp(R, L("tiles/overlay_trap_sprung")), comp(R, L("tiles/overlay_treasure")),
     comp(R, L("tiles/overlay_treasure_open")), comp(R, L("tiles/overlay_shop"), L("tiles/tile_number_small_2")),
     comp(R, L("tiles/overlay_blacksmith")), comp(R, L("tiles/overlay_exit"), L("tiles/tile_number_small_1"))],
    [comp(R, L("resources/resource_iron_ore")), comp(R, L("resources/resource_magic_crystal")),
     comp(R, L("resources/resource_dragon_scale"), L("tiles/tile_number_small_3")),
     comp(R, L("tiles/overlay_resource_depleted")), comp(R, L("tiles/overlay_monster_defeated")),
     comp(H, L("tiles/overlay_flag"), L("tiles/overlay_wrong_flag")), comp(H, L("tiles/overlay_hover")),
     comp(H, L("tiles/overlay_select"))],
]
anim = L("tiles/tile_reveal_anim")
rows.append([anim[:, i * C:(i + 1) * C] for i in range(anim.shape[1] // C)] + [R])

G = 4
W = G + max(len(r) for r in rows) * (C + G)
Hh = G + len(rows) * (C + G)
s = px.blank(W, Hh)
px.fill(s, 0, 0, W, Hh, "0")
for j, r in enumerate(rows):
    for i, t in enumerate(r):
        px.blit(s, t, G + i * (C + G), G + j * (C + G))
out = config.PREVIEW_DIR
px.save_png(px.upscale(s, 3), os.path.join(out, "contact_tiles_3x.png"))
px.save_png(px.upscale(s, 8), os.path.join(out, "contact_tiles_8x.png"))
px.save_png(px.upscale(px.grayscale(s), 3), os.path.join(out, "contact_tiles_3x_gray.png"))
px.save_png(px.upscale(px.deuteranopia(s), 3), os.path.join(out, "contact_tiles_3x_deuteranopia.png"))
print("TILES PREVIEW OK")
