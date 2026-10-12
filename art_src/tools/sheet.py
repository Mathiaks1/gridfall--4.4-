"""Sprite sheety: klatki w poziomym pasku o jednakowej komórce + JSON z metadanymi."""
import json
import os

import numpy as np

import pxlib as px


def write_sheet(frames, path_png, anim_name, fps, loop=True):
    """frames: lista obrazów RGBA o identycznym rozmiarze. Zapisuje PNG i JSON obok."""
    h, w = frames[0].shape[:2]
    for f in frames:
        assert f.shape[:2] == (h, w), "klatki muszą mieć jednakowy rozmiar"
    sheet = np.concatenate(frames, axis=1)
    assert px.check_alpha_binary(sheet) and px.check_in_palette(sheet), path_png
    px.save_png(sheet, path_png)
    meta = {
        "name": os.path.splitext(os.path.basename(path_png))[0],
        "animation": anim_name,
        "frame_width": w,
        "frame_height": h,
        "frames": len(frames),
        "fps": fps,
        "loop": loop,
        "layout": "horizontal",
    }
    with open(os.path.splitext(path_png)[0] + ".json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    return sheet


def write_single(img, path_png):
    assert px.check_alpha_binary(img) and px.check_in_palette(img), path_png
    px.save_png(img, path_png)
