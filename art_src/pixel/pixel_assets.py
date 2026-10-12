"""Ścieżka B: assety rysowane/generowane piksel po pikselu.

Każdy asset to funkcja zarejestrowana dekoratorem @asset(kategoria, nazwa_pliku).
Zwraca obraz RGBA (lub (obraz, meta) dla 9-slice). Kolory wyłącznie przez znaki palety,
więc zmiana palety w palette_def.py przebudowuje wszystko.
Rozmiary: config.CELL / config.ICON.
"""
import math

import numpy as np

import config
import palette_def as pd
import pxlib as px

ASSETS = []
C = config.CELL


def asset(category, name, **meta):
    def deco(fn):
        ASSETS.append({"category": category, "name": name, "fn": fn, "meta": meta})
        return fn
    return deco


# --- prymitywy rysunkowe -------------------------------------------------------

def stamp(img, x, y, text):
    """Nakłada mapę ASCII w punkcie (x, y); '.' nie zmienia piksela."""
    px.blit(img, px.from_ascii(text), x, y)


def poly_mask(w, h, pts):
    """Maska wielokąta (test środka piksela, reguła parzystości)."""
    ys, xs = np.mgrid[0:h, 0:w]
    cx, cy = xs + 0.5, ys + 0.5
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        cond = (y1 > cy) != (y2 > cy)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = (x2 - x1) * (cy - y1) / (y2 - y1) + x1
        inside ^= cond & (cx < xint)
    return inside


def fill_mask(img, mask, ch):
    r, g, b = px.CMAP[ch]
    img[mask] = (r, g, b, 255)


LIGHT = np.array([-0.55, -0.6, 0.58])   # z lewej-góry, lekko od widza
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def shade_disc(img, cx, cy, r, ramp, thresholds, clip=None):
    """Kula w 2D: jasność = N·L, progi -> znaki rampy (ciemny -> jasny)."""
    h, w = img.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    dx, dy = (xs + 0.5 - cx) / r, (ys + 0.5 - cy) / r
    d2 = dx * dx + dy * dy
    mask = d2 <= 1.0
    if clip is not None:
        mask &= clip
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    lum = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
    for i, ch in enumerate(ramp):
        lo = thresholds[i - 1] if i else -9
        fill_mask(img, mask & (lum >= lo), ch)
    return mask


# --- pola ----------------------------------------------------------------------

def _bevel(img, outer_lit, inner_lit, inner_shade, outer_shade, corner_lit, corner_mid):
    s = img.shape[0]
    px.fill(img, 0, 0, s, 1, outer_lit)
    px.fill(img, 0, 0, 1, s, outer_lit)
    px.fill(img, 1, 1, s - 2, 1, inner_lit)
    px.fill(img, 1, 1, 1, s - 2, inner_lit)
    px.fill(img, 2, s - 2, s - 3, 1, inner_shade)
    px.fill(img, s - 2, 2, 1, s - 3, inner_shade)
    px.fill(img, 1, s - 1, s - 1, 1, outer_shade)
    px.fill(img, s - 1, 1, 1, s - 1, outer_shade)
    px.put(img, 0, 0, corner_lit)
    px.put(img, s - 1, 0, corner_mid)
    px.put(img, 0, s - 1, corner_mid)


@asset("tiles", "tile_hidden")
def tile_hidden():
    """Wypukły blok kamienia. Jeden sprite dla każdego zakrytego pola (zero przecieków)."""
    img = px.blank(C, C)
    px.fill(img, 0, 0, C, C, "3")
    _bevel(img, "5", "4", "2", "1", "6", "3")
    # Drobne ubytki (cień u góry-lewej, odblask u dołu-prawej). Bez rys: ten sam sprite
    # powtarza się na całej planszy, więc każdy wyraźny kształt tworzyłby wzór.
    for x, y in [(8, 9), (22, 14), (12, 23)]:
        stamp(img, x, y, "22\n.4")
    return img


@asset("tiles", "tile_revealed")
def tile_revealed():
    """Wklęsła posadzka: cień 2 px u góry/lewej, jasny brzeg 1 px u dołu/prawej."""
    img = px.blank(C, C)
    px.fill(img, 0, 0, C, C, "1")
    px.fill(img, 0, 0, C, 2, "0")
    px.fill(img, 0, 0, 2, C, "0")
    px.fill(img, 1, C - 1, C - 1, 1, "2")
    px.fill(img, C - 1, 1, 1, C - 1, "2")
    px.put(img, C - 1, 0, "1")
    px.put(img, 0, C - 1, "1")
    for x, y in [(26, 6), (6, 25)]:
        px.put(img, x, y, "2")
    return img


GLYPHS = {
    1: """
....XXX...
...XXXX...
..XXXXX...
.XXXXXX...
.XX.XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
.XXXXXXXX.
.XXXXXXXX.
""",
    2: """
.XXXXXXXX.
XXXXXXXXXX
XXXXXXXXXX
XXX....XXX
.......XXX
......XXXX
.....XXXX.
....XXXX..
...XXXX...
..XXXX....
.XXXX.....
XXXX......
XXX.......
XXX.......
XXX.......
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
""",
    3: """
.XXXXXXXX.
XXXXXXXXXX
XXXXXXXXXX
XXX....XXX
.......XXX
.......XXX
....XXXXXX
...XXXXXX.
....XXXXXX
.......XXX
.......XXX
.......XXX
.......XXX
.......XXX
XXX....XXX
XXXXXXXXXX
XXXXXXXXXX
.XXXXXXXX.
""",
    4: """
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXX...XXX.
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
......XXX.
......XXX.
......XXX.
......XXX.
......XXX.
""",
    5: """
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXX.......
XXX.......
XXX.......
XXXXXXXXX.
XXXXXXXXXX
.......XXX
.......XXX
.......XXX
.......XXX
.......XXX
.......XXX
XXX....XXX
XXXXXXXXXX
XXXXXXXXXX
.XXXXXXXX.
""",
    6: """
.XXXXXXXX.
XXXXXXXXXX
XXXXXXXXXX
XXX....XXX
XXX.......
XXX.......
XXXXXXXXX.
XXXXXXXXXX
XXXXXXXXXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXXXXXXXXX
XXXXXXXXXX
.XXXXXXXX.
""",
    7: """
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
.......XXX
.......XXX
......XXX.
......XXX.
.....XXX..
.....XXX..
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
....XXX...
""",
    8: """
.XXXXXXXX.
XXXXXXXXXX
XXXXXXXXXX
XXX....XXX
XXX....XXX
XXX....XXX
XXXXXXXXXX
.XXXXXXXX.
XXXXXXXXXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXX....XXX
XXXXXXXXXX
XXXXXXXXXX
.XXXXXXXX.
""",
}
# Kolor cyfry -> kolor obrysu cienia (ciemniejszy w tej samej rampie, nigdy czerń).
NUMBER_COLORS = {1: "O", 2: "L", 3: "D", 4: "S", 5: "G", 6: "P", 7: "8", 8: "6"}


def number_overlay(n):
    rows = [r.strip() for r in GLYPHS[n].strip().split("\n")]
    gh, gw = len(rows), len(rows[0])
    ox, oy = (C - gw) // 2 + 1, (C - gh) // 2
    col = NUMBER_COLORS[n]
    shade = pd.darker(col, 2)
    img = px.blank(C, C)
    on = {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "X"}
    for x, y in on:   # obrys cienia w prawo-dół (światło z lewej-góry)
        for dx, dy in ((1, 0), (0, 1), (1, 1)):
            if (x + dx, y + dy) not in on:
                px.put(img, ox + x + dx, oy + y + dy, shade)
    for x, y in on:
        px.put(img, ox + x, oy + y, col)
    return img


for _n in GLYPHS:
    asset("tiles", f"tile_number_{_n}")(lambda n=_n: number_overlay(n))


@asset("tiles", "overlay_flag")
def overlay_flag():
    img = px.blank(C, C)
    cloth = px.from_ascii("""
DDDD.........
DDDDDDD......
DDDDDDDDDD...
DDDDDDDDDDDD.
DDDDDDDDDDDDD
CDDDDDDDDDDD.
CCDDDDDDDD...
CCCDDDDD.....
CCCCDD.......
CCCC.........
CC...........
""")
    px.blit(img, px.selective_outline(cloth, 1, 2), 13, 6)
    # drzewce 2 px: strona oświetlona / w cieniu
    for y in range(6, 25):
        px.put(img, 11, y, "7")
        px.put(img, 12, y, "5")
    stamp(img, 10, 3, ".GH.\nGGHG\n.EF.")   # złota gałka
    stamp(img, 8, 23, """
..5665..
.455554.
24444442
.222222.
""")
    return img


# --- przedmioty i surowce ------------------------------------------------------

@asset("items", "item_potion_health")
def item_potion_health():
    s = config.ICON
    img = px.blank(s, s)
    cx, cy, r = 16, 20.5, 9.0
    ys, xs = np.mgrid[0:s, 0:s]
    inside = ((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2) <= r * r
    # pusta część szkła (nad cieczą)
    fill_mask(img, inside & (ys < 15), "2")
    # ciecz: kula cieniowana rampą krwi
    shade_disc(img, cx, cy, r, ["A", "B", "C", "D"], [-0.25, 0.15, 0.55], clip=ys >= 15)
    px.fill(img, 9, 15, 15, 1, "D")                       # menisk
    # szyjka + kołnierz
    px.fill(img, 13, 7, 6, 6, "2")
    px.fill(img, 12, 6, 8, 2, "6")
    px.fill(img, 12, 7, 8, 1, "5")
    # korek
    stamp(img, 13, 2, "UVVVUT\nUVWVUT\nTUVUTT\nTTUTT.")
    img = px.selective_outline(img, 1, 2)
    # szkło: obrys + odblask (po konturze, żeby został jasny)
    ring = inside & ~(((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2) <= (r - 1) ** 2)
    lit = ring & ((xs + ys) < (cx + cy))
    fill_mask(img, ring & ~lit, "4")
    fill_mask(img, lit, "5")
    for x, y in [(11, 15), (11, 16), (10, 17), (10, 18), (10, 19), (12, 13)]:
        px.put(img, x, y, "8" if y < 17 else "7")
    for y in range(7, 13):
        px.put(img, 13, y, "6")
        px.put(img, 18, y, "4")
    return img


@asset("resources", "resource_magic_crystal")
def resource_magic_crystal():
    """Rzadki surowiec: fasetowany kryształ + iskry (wyraźnie „cenniejszy” od rudy)."""
    s = config.ICON
    img = px.blank(s, s)
    T, L, R, B, M = (16, 3), (5, 15), (27, 15), (16, 29), (14, 16)
    fill_mask(img, poly_mask(s, s, [T, L, M]), "P")
    fill_mask(img, poly_mask(s, s, [T, M, R]), "O")
    fill_mask(img, poly_mask(s, s, [L, B, M]), "N")
    fill_mask(img, poly_mask(s, s, [M, B, R]), "R")
    fill_mask(img, poly_mask(s, s, [(16, 5), (10, 12), (14, 12)]), "8")   # odblask fasety
    img = px.selective_outline(img, 1, 2)
    for (x, y) in [(6, 5), (26, 15)]:   # iskry (prawy-dolny róg wolny na cyfrę narożną)
        stamp(img, x - 2, y - 2, "..P..\n..P..\nPP8PP\n..P..\n..P..")
    return img


# --- UI ------------------------------------------------------------------------

@asset("ui", "ui_panel", patch_margin=6)
def ui_panel():
    """Ramka panelu 9-slice 32x32, marginesy 6 px (NinePatchRect.patch_margin_*)."""
    w = h = 32
    img = px.blank(w, h)
    px.fill(img, 0, 0, w, h, "0")
    px.fill(img, 1, 1, w - 2, h - 2, "3")
    px.fill(img, 1, 1, w - 2, 1, "5")
    px.fill(img, 1, 1, 1, h - 2, "5")
    px.fill(img, 1, h - 2, w - 2, 1, "2")
    px.fill(img, w - 2, 1, 1, h - 2, "2")
    px.put(img, 1, 1, "6")
    px.fill(img, 4, 4, w - 8, h - 8, "2")
    px.fill(img, 4, 4, w - 8, 1, "1")
    px.fill(img, 4, 4, 1, h - 8, "1")
    px.fill(img, 5, h - 5, w - 9, 1, "3")
    px.fill(img, w - 5, 5, 1, h - 9, "3")
    for x, y in [(2, 2), (w - 4, 2), (2, h - 4), (w - 4, h - 4)]:
        stamp(img, x, y, "HG\nGE")
    return img
