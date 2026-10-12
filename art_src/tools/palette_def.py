"""Globalna paleta Gridfall — 32 kolory, rampy ciemny -> jasny.

Jedyne źródło prawdy dla palety. Zmiana tutaj + ponowne uruchomienie batcha
przebudowuje wszystkie assety.

Każda rampa ma swój znak (char) używany w mapach ASCII sprite'ów.
Cienie przesunięte w stronę niebiesko-fioletową, światła w stronę żółtą.
"""

# (char, hex, nazwa) — kolejność = indeks w palecie
RAMPS = {
    # Kamień / neutralne: fiolet-granat -> ciepła kość. Tło, pola, UI.
    "stone": [
        ("0", "0d0b14", "void"),
        ("1", "1b1926", "abyss"),
        ("2", "2a2738", "deep"),
        ("3", "3c3a4e", "slate"),
        ("4", "545266", "stone"),
        ("5", "767383", "ash"),
        ("6", "9e979b", "fog"),
        ("7", "cbc0b0", "bone"),
        ("8", "f2e8d2", "parchment"),
    ],
    # Brąz / skóra: drewno, skóra, ruda żelaza, cera.
    "earth": [
        ("T", "3d241f", "umber"),
        ("U", "6b4030", "leather"),
        ("V", "a0684a", "clay"),
        ("W", "e0a77c", "flesh"),
    ],
    # Czerwienie: HP, krew, flaga, ogień.
    "blood": [
        ("A", "3b0f1e", "gore"),
        ("B", "74182a", "wine"),
        ("C", "b82e35", "blood"),
        ("D", "f0583f", "ember"),
    ],
    # Złoto / pomarańcz: złoto, skarb, krytyk, awans.
    "gold": [
        ("E", "7a3a12", "rust"),
        ("F", "c06a1c", "amber"),
        ("G", "f0a630", "gold"),
        ("H", "ffe17a", "shine"),
    ],
    # Zielenie: szlam, trucizna, leczenie, EXP.
    "moss": [
        ("I", "0f2e2b", "bog"),
        ("J", "1c5a3d", "moss"),
        ("K", "3f9346", "leaf"),
        ("L", "9ad660", "lime"),
    ],
    # Błękity: wyjście, magiczny kryształ, zwoje.
    "frost": [
        ("M", "132447", "night"),
        ("N", "1d4f8f", "sea"),
        ("O", "3b94d6", "sky"),
        ("P", "8ee0f2", "ice"),
    ],
    # Fiolety: magia, rzadkość, smocza łuska (akcent).
    "arcane": [
        ("Q", "3a1d55", "plum"),
        ("R", "6e3a96", "violet"),
        ("S", "b56ad6", "orchid"),
    ],
}

TRANSPARENT = "."


def entries():
    """Lista (char, hex, name, ramp_name, pos_in_ramp) w kolejności indeksów."""
    out = []
    for ramp_name, ramp in RAMPS.items():
        for pos, (ch, hx, name) in enumerate(ramp):
            out.append((ch, hx, name, ramp_name, pos))
    return out


def hex_to_rgb(hx):
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def char_map():
    """char -> (r, g, b)"""
    return {ch: hex_to_rgb(hx) for ch, hx, *_ in entries()}


def darker(ch, steps=1):
    """Ciemniejszy odcień w tej samej rampie (dla selektywnego konturu)."""
    for ramp in RAMPS.values():
        chars = [c for c, *_ in ramp]
        if ch in chars:
            i = max(0, chars.index(ch) - steps)
            return chars[i]
    return ch


assert len(entries()) == 32, len(entries())
assert len({c for c, *_ in entries()}) == 32
