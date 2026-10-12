"""Krok 3, partia 1 — pola: nakładki pól specjalnych, stany rozpatrzone, podświetlenia,
małe cyfry narożne, animacja odkrycia. Nakładki 32x32 rysowane na tile_revealed / tile_hidden.
"""
import numpy as np

import config
import palette_def as pd
import pxlib as px
from pixel_assets import C, NUMBER_COLORS, asset, fill_mask, poly_mask, shade_disc, stamp, tile_hidden, tile_revealed


def outlined(text):
    return px.selective_outline(px.from_ascii(text), 1, 2)


# --- pola bazowe: wariant „wybuch” -------------------------------------------------

@asset("tiles", "tile_revealed_danger")
def tile_revealed_danger():
    """Odkryte pole zagrożenia, które właśnie zadziałało (wklęsłe, krwista posadzka)."""
    img = px.blank(C, C)
    px.fill(img, 0, 0, C, C, "A")
    px.fill(img, 0, 0, C, 2, "0")
    px.fill(img, 0, 0, 2, C, "0")
    px.fill(img, 1, C - 1, C - 1, 1, "B")
    px.fill(img, C - 1, 1, 1, C - 1, "B")
    px.put(img, C - 1, 0, "A")
    px.put(img, 0, C - 1, "A")
    return img


# --- małe cyfry narożne (pola specjalne też pokazują liczbę zagrożeń) ---------------

SMALL = {
    1: [".X.", "XX.", ".X.", ".X.", "XXX"],
    2: ["XX.", "..X", ".X.", "X..", "XXX"],
    3: ["XX.", "..X", ".X.", "..X", "XX."],
    4: ["X.X", "X.X", "XXX", "..X", "..X"],
    5: ["XXX", "X..", "XX.", "..X", "XX."],
    6: [".XX", "X..", "XXX", "X.X", "XXX"],
    7: ["XXX", "..X", ".X.", ".X.", ".X."],
    8: ["XXX", "X.X", "XXX", "X.X", "XXX"],
}


def small_number(n):
    img = px.blank(C, C)
    px.fill(img, 25, 23, 6, 8, "0")          # ciemna podkładka pod cyfrę
    for y, row in enumerate(SMALL[n]):
        for x, c in enumerate(row):
            if c == "X":
                px.put(img, 27 + x, 25 + y, NUMBER_COLORS[n])
    return img


for _n in SMALL:
    asset("tiles", f"tile_number_small_{_n}")(lambda n=_n: small_number(n))


# --- pułapka ---------------------------------------------------------------------

SPIKE = """
..8..
..7..
.775.
.765.
77654
"""


def _trap_plate(img):
    px.fill(img, 5, 16, 22, 10, "3")
    px.fill(img, 5, 16, 22, 1, "4")
    px.fill(img, 5, 16, 1, 10, "4")
    px.fill(img, 5, 25, 22, 1, "2")
    px.fill(img, 26, 16, 1, 10, "2")
    for x, y in [(7, 18), (24, 18), (7, 23), (24, 23)]:
        px.put(img, x, y, "5")


@asset("tiles", "overlay_trap")
def overlay_trap():
    img = px.blank(C, C)
    _trap_plate(img)
    spike = px.from_ascii(SPIKE)
    for x, y in [(7, 12), (13, 11), (19, 12), (10, 17), (16, 17)]:
        px.blit(img, spike, x, y)
    for x, y in [(9, 12), (15, 11), (21, 12)]:   # zakrwawione czubki
        px.put(img, x, y, "D")
    return px.selective_outline(img, 1, 1)


@asset("tiles", "overlay_trap_sprung")
def overlay_trap_sprung():
    """Rozpatrzona: kolce schowane, otwory i plama — przygaszona, nie przyciąga wzroku."""
    img = px.blank(C, C)
    _trap_plate(img)
    for x, y in [(9, 18), (15, 18), (21, 18), (12, 22), (18, 22)]:
        stamp(img, x, y, "00\n01")
    stamp(img, 13, 20, ".B.\nBAB\n.A.")
    return px.selective_outline(img, 1, 1)


# --- skarb -----------------------------------------------------------------------

def _chest_body(img):
    px.fill(img, 6, 15, 20, 12, "U")
    for y in (18, 22):
        px.fill(img, 6, y, 20, 1, "T")                       # deski
    px.fill(img, 6, 15, 20, 1, "V")
    px.fill(img, 9, 15, 2, 12, "F")                          # okucia
    px.fill(img, 21, 15, 2, 12, "F")
    px.fill(img, 9, 15, 1, 12, "G")
    px.fill(img, 21, 15, 1, 12, "G")


@asset("tiles", "overlay_treasure")
def overlay_treasure():
    img = px.blank(C, C)
    stamp(img, 6, 8, """
..VVVVVVVVVVVVVVVV..
.VWVVVVVVVVVVVVVVVU.
VVVVVVVVVVVVVVVVVVUU
UUUUUUUUUUUUUUUUUUUU
UUUUUUUUUUUUUUUUUUUU
UUUUUUUUUUUUUUUUUUUU
UUUUUUUUUUUUUUUUUUUU
""")
    px.fill(img, 9, 9, 2, 6, "F")
    px.fill(img, 21, 9, 2, 6, "F")
    px.fill(img, 9, 9, 1, 6, "G")
    px.fill(img, 21, 9, 1, 6, "G")
    _chest_body(img)
    stamp(img, 14, 13, "GHHG\nGG0G\nFG0F\n.FF.")             # zamek z dziurką
    return px.selective_outline(img, 1, 2)


@asset("tiles", "overlay_treasure_open")
def overlay_treasure_open():
    img = px.blank(C, C)
    stamp(img, 6, 5, """
.TUUUUUUUUUUUUUUUUT.
TUUUUUUUUUUUUUUUUUUT
TUUUUUUUUUUUUUUUUUUT
TTTTTTTTTTTTTTTTTTTT
""")                                                         # wieko odchylone do tyłu
    px.fill(img, 6, 11, 20, 4, "0")                          # puste wnętrze
    px.fill(img, 6, 11, 20, 1, "T")
    _chest_body(img)
    return px.selective_outline(img, 1, 2)


# --- sklep, kowal, wyjście ----------------------------------------------------------

@asset("tiles", "overlay_shop")
def overlay_shop():
    """Stragan: markiza w pasy, lada, stos monet."""
    img = px.blank(C, C)
    for i in range(8):
        px.fill(img, 4 + i * 3, 5, 3, 7, "C" if i % 2 == 0 else "7")
        px.fill(img, 4 + i * 3, 5, 3, 1, "D" if i % 2 == 0 else "8")
        px.put(img, 5 + i * 3, 12, "C" if i % 2 == 0 else "7")   # ząbki markizy
    px.fill(img, 6, 13, 2, 14, "U")                          # słupki
    px.fill(img, 24, 13, 2, 14, "U")
    px.fill(img, 4, 20, 24, 7, "U")                          # lada
    px.fill(img, 4, 20, 24, 1, "W")
    px.fill(img, 4, 21, 24, 1, "V")
    px.fill(img, 4, 25, 24, 2, "T")
    stamp(img, 12, 14, """
..HHGG..
.EGGGGE.
.HHGGGG.
EGGGGGGE
""")
    stamp(img, 21, 16, ".SS\nSRS\nRRQ")                      # fiolka z miksturą magiczną
    return px.selective_outline(img, 1, 2)


@asset("tiles", "overlay_blacksmith")
def overlay_blacksmith():
    """Kowadło z rozżarzoną sztabą i iskrami."""
    img = px.blank(C, C)
    stamp(img, 3, 13, """
...6666666666666666666.
.6666666666666666666665
65555555555555555555554
..445555555555555555544
""")
    px.fill(img, 11, 17, 10, 5, "4")
    px.fill(img, 11, 17, 2, 5, "5")
    px.fill(img, 8, 22, 16, 4, "4")
    px.fill(img, 8, 22, 16, 1, "5")
    px.fill(img, 8, 25, 16, 1, "3")
    stamp(img, 12, 10, """
.FGGHHGF.
EFGGGGGFE
.EEFFFEE.
""")                                                         # rozżarzona sztaba
    out = px.selective_outline(img, 1, 2)
    for x, y, ch in [(10, 6, "H"), (8, 8, "G"), (13, 5, "G"), (21, 6, "H"), (23, 8, "G"), (19, 4, "F")]:
        px.put(out, x, y, ch)                                # iskry
    return out


@asset("tiles", "overlay_exit")
def overlay_exit():
    """Schody w dół do ciemności, krawędzie stopni podświetlone na niebiesko (rola koloru: wyjście)."""
    img = px.blank(C, C)
    # kamienna obudowa otworu: faza 2 px (jaśniej góra/lewo)
    px.fill(img, 3, 3, 26, 26, "3")
    px.fill(img, 3, 3, 26, 2, "5")
    px.fill(img, 3, 3, 2, 26, "5")
    px.fill(img, 5, 27, 24, 2, "2")
    px.fill(img, 27, 5, 2, 24, "2")
    px.fill(img, 6, 6, 20, 20, "0")
    # schody zwężające się w głąb, krawędzie stopni coraz ciemniej niebieskie
    for i, (edge, face) in enumerate([("P", "4"), ("O", "3"), ("N", "2"), ("M", "1")]):
        w = 20 - i * 4
        x0 = 6 + i * 2
        y = 6 + i * 5
        px.fill(img, x0, y, w, 1, edge)
        px.fill(img, x0, y + 1, w, 3, face)
        px.fill(img, x0, y + 1, 1, 3, pd.darker(face, 1))
    return img


# --- rozpatrzone / znaczniki ---------------------------------------------------------

@asset("tiles", "overlay_monster_defeated")
def overlay_monster_defeated():
    """Ogólny znak pokonanego potwora: kości, przygaszone (nie konkuruje z cyframi)."""
    return outlined("""
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
............555555..............
...........56666665.............
...........56006005.............
...........56006005.............
...........55665655.............
............565655..............
............5.5.5...............
.......55..............55.......
.......565............565.......
........5665........5665........
..........5665....5665..........
............56655665............
.............566665.............
............56655665............
..........5665....5665..........
........5665........5665........
.......565............565.......
.......55..............55.......
................................
................................
................................
""")


@asset("tiles", "overlay_resource_depleted")
def overlay_resource_depleted():
    """Wyeksploatowane złoże: kilka okruchów skały."""
    return outlined("""
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
.............44.................
............4554......44........
............4444.....4554.......
.......44.............44........
......4554.........44...........
.......44.........4554..........
...................44...........
................................
................................
................................
................................
................................
................................
................................
................................
""")


@asset("tiles", "overlay_wrong_flag")
def overlay_wrong_flag():
    """Po porażce: flaga na bezpiecznym polu — czerwony krzyżyk na wierzch flagi."""
    img = px.blank(C, C)
    for i in range(18):
        for d in range(3):
            px.put(img, 7 + i + d, 7 + i, "D")
            px.put(img, 24 - i - d, 7 + i, "D")
    return px.selective_outline(img, 1, 2)


@asset("tiles", "overlay_hover")
def overlay_hover():
    """Wskazanie kursorem: cienka ramka 1 px w kolorze kości."""
    img = px.blank(C, C)
    px.fill(img, 1, 1, C - 2, 1, "7")
    px.fill(img, 1, C - 2, C - 2, 1, "7")
    px.fill(img, 1, 1, 1, C - 2, "7")
    px.fill(img, C - 2, 1, 1, C - 2, "7")
    return img


@asset("tiles", "overlay_select")
def overlay_select():
    """Zaznaczenie / tryb celowania: złote narożniki 2 px."""
    img = px.blank(C, C)
    L = 8
    for (x, y, dx, dy) in [(0, 0, 1, 1), (C - 1, 0, -1, 1), (0, C - 1, 1, -1), (C - 1, C - 1, -1, -1)]:
        for i in range(L):
            for t in range(2):
                px.put(img, x + dx * i, y + dy * t, "G" if t == 0 else "F")
                px.put(img, x + dx * t, y + dy * i, "G" if t == 0 else "F")
    return img


# --- animacja odkrycia: kamienny blok rozpada się i opada w ciemność ------------------

def _shrink(chunk, f):
    h, w = chunk.shape[:2]
    nh, nw = max(1, round(h * f)), max(1, round(w * f))
    ys = (np.arange(nh) * h / nh).astype(int)
    xs = (np.arange(nw) * w / nw).astype(int)
    return chunk[np.ix_(ys, xs)]


def _darken(img, steps):
    out = img.copy()
    for y in range(img.shape[0]):
        for x in range(img.shape[1]):
            ch = px.char_at(img, x, y)
            if ch:
                px.put(out, x, y, pd.darker(ch, steps))
    return out


def reveal_frames():
    hid, rev = tile_hidden(), tile_revealed()
    half = C // 2
    frames = []
    # klatka 0: pęknięcia na bloku
    f0 = hid.copy()
    for i in range(C):
        px.put(f0, half, i, "1")
        px.put(f0, i, half, "1")
    frames.append(f0)
    for k, (scale, drop, dark) in enumerate([(0.75, 1, 0), (0.5, 3, 1), (0.25, 5, 1)]):
        f = rev.copy()
        for qx in (0, 1):
            for qy in (0, 1):
                chunk = _darken(_shrink(hid[qy * half:(qy + 1) * half, qx * half:(qx + 1) * half], scale), dark)
                ch, cw = chunk.shape[:2]
                cx = qx * half + (half - cw) // 2 + (1 if qx else -1) * k
                cy = qy * half + (half - ch) // 2 + drop
                cy = min(cy, C - ch)
                px.blit(f, chunk, max(cx, 0), cy)
        frames.append(f)
    return frames


asset("tiles", "tile_reveal_anim", sheet={"animation": "reveal", "fps": 20, "loop": False})(reveal_frames)


# --- ikony surowców (też nakładki pól surowców) ---------------------------------------

@asset("resources", "resource_iron_ore")
def resource_iron_ore():
    """Pospolity: bryła skały z rdzawymi żyłkami. Matowa, bez iskier."""
    s = config.ICON
    img = px.blank(s, s)
    for cx, cy, r in [(12, 20, 8.0), (21, 19, 7.0), (16, 12, 6.5)]:
        shade_disc(img, cx, cy, r, ["2", "3", "4", "5"], [-0.3, 0.1, 0.55])
    img = px.selective_outline(img, 1, 2)
    for x, y, ch in [(10, 16, "F"), (11, 16, "V"), (11, 17, "E"), (17, 10, "F"), (18, 11, "E"),
                     (20, 16, "V"), (21, 16, "F"), (21, 17, "E"), (13, 22, "E"), (14, 21, "V"),
                     (15, 11, "7"), (9, 18, "6"), (19, 15, "6")]:
        px.put(img, x, y, ch)
    return img


@asset("resources", "resource_dragon_scale")
def resource_dragon_scale():
    """Epicki: trzy zachodzące łuski (krwiste, złote krawędzie, opalizujący połysk) + trzy iskry.

    Prawy-dolny róg (x>=24, y>=22) zostaje wolny na cyfrę narożną.
    """
    s = config.ICON
    img = px.blank(s, s)
    ys, xs = np.mgrid[0:s, 0:s]
    for cx, cy in [(11, 11), (21, 11), (16, 18)]:          # dolna łuska rysowana na wierzchu
        layer = px.blank(s, s)
        m = shade_disc(layer, cx, cy, 7.5, ["A", "B", "C", "D"], [-0.25, 0.15, 0.6])
        m &= ys >= cy - 6                                    # spłaszczony wierzch (chowa się pod sąsiednią)
        edge = m & ~((((xs + 0.5 - cx) ** 2 + (ys + 0.5 - cy) ** 2) <= 6.0 ** 2)) & (ys >= cy)
        fill_mask(layer, edge & (xs < cx + 2), "G")
        fill_mask(layer, edge & (xs >= cx + 2), "F")
        for x, y in [(cx - 3, cy - 3), (cx - 2, cy - 4), (cx - 4, cy - 2)]:
            px.put(layer, x, y, "S")
        img[m] = layer[m]
    img = px.selective_outline(img, 1, 2)
    for (x, y) in [(4, 4), (27, 6), (5, 24)]:
        stamp(img, x - 2, y - 2, "..H..\n..G..\nHG8GH\n..G..\n..H..")
    return img
