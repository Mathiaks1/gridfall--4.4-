"""Batch ścieżki B: generuje wszystkie assety z pixel_assets.py do assets/art/<kategoria>/.

  python art_src/pixel/build_pixel.py [nazwa ...]     (Python z numpy, np. Blendera)
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(os.path.dirname(HERE), "tools")]

import config  # noqa: E402
import pixel_assets  # noqa: E402
import assets_tiles  # noqa: E402,F401  (rejestruje assety partii „pola”)
import sheet  # noqa: E402

wanted = set(sys.argv[1:])
for a in pixel_assets.ASSETS:
    if wanted and a["name"] not in wanted:
        continue
    out = a["fn"]()
    path = os.path.join(config.out_dir(a["category"]), a["name"] + ".png")
    meta = dict(a["meta"])
    if "sheet" in meta:
        spec = meta.pop("sheet")
        img = sheet.write_sheet(out, path, spec["animation"], spec["fps"], spec.get("loop", True))
    else:
        img = out
        sheet.write_single(img, path)
    if meta:
        with open(os.path.splitext(path)[0] + ".json", "w", encoding="utf-8", newline="\n") as f:
            json.dump({"name": a["name"], **meta}, f, indent=2)
            f.write("\n")
    print("WROTE", os.path.relpath(path, config.PROJECT), img.shape[1], "x", img.shape[0])
