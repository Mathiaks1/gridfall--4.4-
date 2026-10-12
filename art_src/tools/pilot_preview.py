"""Podglądy pilotażu (Krok 2): contact sheet 1x/3x/8x, siatka 8x8, makieta ekranu 640x360.

  python art_src/tools/pilot_preview.py
"""
import json
import os

import numpy as np

import config
import pxlib as px

A = config.OUT_ROOT
OUT = config.PREVIEW_DIR
C = config.CELL


def load(rel):
    return px.load_png(os.path.join(A, rel + ".png"))


def frames(rel):
    img = load(rel)
    with open(os.path.join(A, rel + ".json"), encoding="utf-8") as f:
        meta = json.load(f)
    w = meta["frame_width"]
    return [img[:, i * w:(i + 1) * w] for i in range(meta["frames"])]


def comp(base, *overlays):
    t = base.copy()
    for o in overlays:
        px.blit(t, o, (t.shape[1] - o.shape[1]) // 2, (t.shape[0] - o.shape[0]) // 2)
    return t


def nine_slice(src, m, w, h):
    """Rozciąga 9-slice przez powielanie środkowego wiersza/kolumny (krawędzie są jednolite)."""
    sh, sw = src.shape[:2]
    ys = [y if y < m else (sh - (h - y) if y >= h - m else m) for y in range(h)]
    xs = [x if x < m else (sw - (w - x) if x >= w - m else m) for x in range(w)]
    return src[np.ix_(ys, xs)]


hidden, revealed = load("tiles/tile_hidden"), load("tiles/tile_revealed")
nums = {n: load(f"tiles/tile_number_{n}") for n in (1, 2, 3)}
flag = load("tiles/overlay_flag")
slime_icon = load("monsters/monster_slime_icon")
potion = load("items/item_potion_health")
crystal = load("resources/resource_magic_crystal")
panel = load("ui/ui_panel")
slime_idle = frames("monsters/monster_slime_battle_idle")
hero_idle = frames("hero/hero_battle_idle")

# --- contact sheet --------------------------------------------------------------
items = [hidden, revealed, comp(revealed, nums[1]), comp(revealed, nums[2]), comp(revealed, nums[3]),
         flag, comp(hidden, flag), comp(revealed, slime_icon), potion, crystal, panel]
row2 = hero_idle + slime_idle
G = 4
W = max(sum(i.shape[1] + G for i in items), sum(f.shape[1] + G for f in row2)) + G
H = G + C + G + 64 + G
sheet = px.blank(W, H)
px.fill(sheet, 0, 0, W, H, "0")
x = G
for i in items:
    px.blit(sheet, i, x, G)
    x += i.shape[1] + G
x = G
for f in row2:
    px.blit(sheet, f, x, G + C + G)
    x += f.shape[1] + G
for k in (1, 3, 8):
    px.save_png(px.upscale(sheet, k), os.path.join(OUT, f"pilot_contact_{k}x.png"))

# --- siatka 8x8 (prawdziwy układ Sapera, cyfry tylko 1-3) -------------------------
N = 8
mines = {(1, 1), (6, 1), (3, 4), (7, 5), (0, 6), (4, 7), (5, 7), (6, 7)}
flags = {(3, 4), (0, 6)}
monster = (1, 1)


def count(x, y):
    return sum((x + dx, y + dy) in mines for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)


rev, stack = set(), [(4, 1)]
while stack:
    c = stack.pop()
    if c in rev or c in mines or not (0 <= c[0] < N and 0 <= c[1] < N):
        continue
    rev.add(c)
    if count(*c) == 0:
        stack += [(c[0] + dx, c[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
board = px.blank(N * C, N * C)
for y in range(N):
    for x in range(N):
        if (x, y) == monster:
            t = comp(revealed, slime_icon)
        elif (x, y) in rev:
            n = count(x, y)
            assert n <= 3, (x, y, n)
            t = comp(revealed, nums[n]) if n else revealed
        elif (x, y) in flags:
            t = comp(hidden, flag)
        else:
            t = hidden
        px.blit(board, t, x * C, y * C)
for k in (1, 3):
    px.save_png(px.upscale(board, k), os.path.join(OUT, f"pilot_grid8_{k}x.png"))
px.save_png(px.upscale(px.grayscale(board), 3), os.path.join(OUT, "pilot_grid8_3x_gray.png"))
px.save_png(px.upscale(px.deuteranopia(board), 3), os.path.join(OUT, "pilot_grid8_3x_deuteranopia.png"))

# --- makieta ekranu 640x360 (logiczna rozdzielczość gry) -------------------------
S = px.blank(640, 360)
px.fill(S, 0, 0, 640, 360, "0")
bx, by = 24, (360 - N * C) // 2
px.blit(S, nine_slice(panel, 6, N * C + 16, N * C + 16), bx - 8, by - 8)
px.blit(S, board, bx, by)
px.blit(S, nine_slice(panel, 6, 336, 120), 288, 52)
px.blit(S, hero_idle[0], 320, 80)
px.blit(S, slime_idle[0], 520, 80)
px.blit(S, nine_slice(panel, 6, 336, 72), 288, 188)
for i, ic in enumerate([potion, potion, crystal]):
    px.blit(S, comp(revealed, ic), 304 + i * 40, 208)
assert px.check_alpha_binary(S) and px.check_in_palette(S)
for k in (1, 3):
    px.save_png(px.upscale(S, k), os.path.join(OUT, f"pilot_screen_640x360_{k}x.png"))
print("PREVIEWS OK")
