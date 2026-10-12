"""Minimalna biblioteka pixel-art: mapy ASCII -> RGBA, PNG I/O, kwantyzacja, kontur.

Zależności: numpy (jest w Pythonie Blendera). Bez Pillow.
Obrazy to numpy uint8 o kształcie (H, W, 4), alfa zawsze 0 albo 255.
"""
import struct
import zlib

import numpy as np

import palette_def as pd

CMAP = pd.char_map()
PAL_RGB = np.array([pd.hex_to_rgb(hx) for _, hx, *_ in pd.entries()], dtype=np.int32)
PAL_CHARS = [ch for ch, *_ in pd.entries()]


# --- tworzenie ---------------------------------------------------------------

def blank(w, h):
    return np.zeros((h, w, 4), dtype=np.uint8)


def from_ascii(text):
    """Mapa ASCII (znak = kolor z palety, '.' = przezroczysty) -> RGBA."""
    rows = [r for r in text.strip("\n").split("\n")]
    rows = [r.strip() for r in rows if r.strip()]
    w = max(len(r) for r in rows)
    img = blank(w, len(rows))
    for y, row in enumerate(rows):
        if len(row) != w:
            raise ValueError(f"wiersz {y} ma {len(row)} zamiast {w}: {row!r}")
        for x, ch in enumerate(row):
            if ch == pd.TRANSPARENT:
                continue
            r, g, b = CMAP[ch]
            img[y, x] = (r, g, b, 255)
    return img


def fill(img, x, y, w, h, ch):
    r, g, b = CMAP[ch]
    img[y:y + h, x:x + w] = (r, g, b, 255)


def put(img, x, y, ch):
    r, g, b = CMAP[ch]
    img[y, x] = (r, g, b, 255)


def blit(dst, src, x, y):
    """Nakłada src na dst (alfa binarna)."""
    h, w = src.shape[:2]
    region = dst[y:y + h, x:x + w]
    mask = src[..., 3] == 255
    region[mask] = src[mask]


def recolor(img, mapping):
    """Zamiana kolorów: {'C': 'K', ...} (podmiana rampy dla wariantów)."""
    out = img.copy()
    for a, b in mapping.items():
        ra = np.array(CMAP[a])
        m = (img[..., 3] == 255) & np.all(img[..., :3] == ra, axis=-1)
        out[m, :3] = CMAP[b]
    return out


# --- kwantyzacja / alfa / kontur ----------------------------------------------

def _srgb_to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _to_oklab(rgb):
    lin = _srgb_to_linear(rgb.astype(np.float64))
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(lin @ m1.T)
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ m2.T


_PAL_LAB = _to_oklab(PAL_RGB)


def quantize(img, allowed=None, alpha_threshold=128):
    """Najbliższy kolor palety w OKLab (bez ditheringu) + progowanie alfy.

    allowed: opcjonalna lista znaków palety (ogranicza wybór, np. do ramp potwora).
    """
    h, w = img.shape[:2]
    idx = np.arange(len(PAL_CHARS)) if allowed is None else np.array([PAL_CHARS.index(c) for c in allowed])
    lab = _to_oklab(img[..., :3].reshape(-1, 3).astype(np.int32))
    d = ((lab[:, None, :] - _PAL_LAB[idx][None, :, :]) ** 2).sum(-1)
    best = idx[d.argmin(1)]
    out = blank(w, h)
    out[..., :3] = PAL_RGB[best].reshape(h, w, 3)
    out[..., 3] = np.where(img[..., 3] >= alpha_threshold, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def char_at(img, x, y):
    if img[y, x, 3] == 0:
        return None
    rgb = img[y, x, :3].astype(np.int32)
    i = int(np.argmin(((PAL_RGB - rgb) ** 2).sum(1)))
    return PAL_CHARS[i]


def selective_outline(img, lit_steps=1, shade_steps=2):
    """Kontur wewnętrzny 1 px: piksele brzegowe przyciemnione w obrębie własnej rampy.

    Światło z lewej-góry: brzeg od strony lewej/górnej o lit_steps ciemniej,
    pozostałe o shade_steps ciemniej. Nie zmienia sylwetki ani rozmiaru.
    """
    h, w = img.shape[:2]
    a = img[..., 3] == 255
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if not a[y, x]:
                continue
            def empty(dx, dy):
                nx, ny = x + dx, y + dy
                return nx < 0 or ny < 0 or nx >= w or ny >= h or not a[ny, nx]
            lit = empty(-1, 0) or empty(0, -1)
            shade = empty(1, 0) or empty(0, 1)
            if not (lit or shade):
                continue
            ch = char_at(img, x, y)
            put(out, x, y, pd.darker(ch, shade_steps if shade else lit_steps))
    return out


def inner_lines(img, id_img, steps=1):
    """Linie wewnętrzne 1 px między częściami modelu (różne kolory w renderze ID).

    Przyciemniany jest piksel po lewej/u góry granicy, czyli strona cienia części
    znajdującej się wyżej/lewiej. Kolor = ciemniejszy odcień własnej rampy.
    """
    h, w = img.shape[:2]
    a = img[..., 3] == 255
    ids = id_img[..., :3].astype(np.int32)
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if not a[y, x]:
                continue
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if nx < w and ny < h and a[ny, nx] and id_img[ny, nx, 3] and id_img[y, x, 3]                         and np.abs(ids[ny, nx] - ids[y, x]).sum() > 24:
                    put(out, x, y, pd.darker(char_at(img, x, y), steps))
                    break
    return out


# --- podglądy ----------------------------------------------------------------

def upscale(img, k):
    return img.repeat(k, axis=0).repeat(k, axis=1)


def flatten_on(img, bg_char):
    out = blank(img.shape[1], img.shape[0])
    fill(out, 0, 0, img.shape[1], img.shape[0], bg_char)
    blit(out, img, 0, 0)
    return out


def grayscale(img):
    out = img.copy()
    lin = _srgb_to_linear(img[..., :3].astype(np.float64))
    y = lin @ np.array([0.2126, 0.7152, 0.0722])
    s = np.where(y <= 0.0031308, y * 12.92, 1.055 * y ** (1 / 2.4) - 0.055)
    out[..., :3] = np.clip(s * 255 + 0.5, 0, 255).astype(np.uint8)[..., None]
    return out


def deuteranopia(img):
    """Symulacja deuteranopii (Machado 2009, severity 1.0) w liniowym RGB."""
    m = np.array([[0.367322, 0.860646, -0.227968],
                  [0.280085, 0.672501, 0.047413],
                  [-0.011820, 0.042940, 0.968881]])
    lin = _srgb_to_linear(img[..., :3].astype(np.float64)) @ m.T
    lin = np.clip(lin, 0, 1)
    s = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)
    out = img.copy()
    out[..., :3] = np.clip(s * 255 + 0.5, 0, 255).astype(np.uint8)
    return out


# --- PNG I/O -----------------------------------------------------------------

def save_png(img, path):
    img = np.ascontiguousarray(img, dtype=np.uint8)
    h, w = img.shape[:2]
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def load_png(path):
    """Czyta 8-bit RGBA/RGB PNG bez przeplotu (wystarcza dla renderów Blendera i własnych plików)."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat = 8, b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and interlace == 0 and ctype in (2, 6), (depth, ctype, interlace)
        elif tag == b"IDAT":
            idat += body
        pos += 12 + ln
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * bpp
    out = np.zeros((h, stride), dtype=np.int32)
    prev = np.zeros(stride, dtype=np.int32)
    p = 0
    for y in range(h):
        ft = raw[p]; p += 1
        line = np.frombuffer(raw[p:p + stride], dtype=np.uint8).astype(np.int32); p += stride
        cur = np.zeros(stride, dtype=np.int32)
        for i in range(stride):
            a = cur[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            x = line[i]
            if ft == 0: v = x
            elif ft == 1: v = x + a
            elif ft == 2: v = x + b
            elif ft == 3: v = x + ((a + b) >> 1)
            else:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                v = x + pr
            cur[i] = v & 255
        out[y] = cur
        prev = cur
    img = out.reshape(h, w, bpp).astype(np.uint8)
    if bpp == 3:
        img = np.concatenate([img, np.full((h, w, 1), 255, np.uint8)], axis=2)
    return img


def check_alpha_binary(img):
    return bool(np.isin(img[..., 3], (0, 255)).all())


def check_in_palette(img):
    rgb = img[img[..., 3] == 255][:, :3].astype(np.int32)
    if len(rgb) == 0:
        return True
    d = ((rgb[:, None, :] - PAL_RGB[None]) ** 2).sum(-1).min(1)
    return bool((d == 0).all())
