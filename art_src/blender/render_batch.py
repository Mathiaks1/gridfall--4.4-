"""Batch ścieżki A. Otwiera szablon i renderuje assety z manifest_3d.py.

  blender -b art_src/blender/gridfall_template.blend --python art_src/blender/render_batch.py -- [nazwa ...]

Bez nazw = wszystkie assety z manifestu.
Per klatka: render beauty + render ID -> kwantyzacja do palety (OKLab, bez ditheringu)
-> progowanie alfy -> linie wewnętrzne między częściami -> selektywny kontur -> PNG/sheet + JSON.
"""
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(os.path.dirname(HERE), "tools")]

import bpy  # noqa: E402

import bl_common as bc  # noqa: E402
import config  # noqa: E402
import manifest_3d  # noqa: E402
import pxlib as px  # noqa: E402
import sheet  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
wanted = set(argv)
CACHE = os.path.join(config.ART_SRC, ".cache")
os.makedirs(CACHE, exist_ok=True)

scene = bpy.context.scene
cam = bpy.data.objects["CAM_Main"]
problems = []


def render_frame(col, size, palette, tag, allow_bottom_cut=False):
    beauty = os.path.join(CACHE, f"{tag}_beauty.png")
    ids = os.path.join(CACHE, f"{tag}_id.png")
    bc.render_to(scene, beauty)
    bc.render_id_pass(scene, col, ids)
    img = px.quantize(px.load_png(beauty), allowed=list(palette))
    img = px.inner_lines(img, px.load_png(ids), steps=1)
    img = px.selective_outline(img, lit_steps=1, shade_steps=2)
    if img[..., 3].max() == 0:
        problems.append(f"{tag}: pusta klatka")
    edge = img[0, :, 3].any() or img[:, 0, 3].any() or img[:, -1, 3].any()
    edge = edge or (img[-1, :, 3].any() and not allow_bottom_cut)
    if edge:
        problems.append(f"{tag}: sprite dotyka krawędzi kadru (możliwe przycięcie)")
    return img


for asset in manifest_3d.ASSETS:
    if wanted and asset["name"] not in wanted:
        continue
    mod = importlib.import_module("models." + asset["model"])
    col = bpy.data.collections[asset["collection"]]
    bc.clear_collection(col)
    parts = mod.build(col)
    out_dir = config.out_dir(asset["category"])

    for out in asset["outputs"]:
        size, wpp = out["size"], out["wpp"]
        bc.configure_render(scene, size)
        facing = out.get("facing_deg", mod.FACING_DEG)
        parts["root"].rotation_euler.z = math.radians(facing)
        mod.pose(parts, "rest", 0, wpp)
        _, top_px = bc.frame_camera(cam, size, wpp, out.get("margin_px", 4), list(col.all_objects),
                                    anchor_top=out.get("anchor") == "top")
        if top_px > size - 1:
            problems.append(f"{asset['name']} {out['kind']}: model wyższy niż kadr ({top_px:.0f} px > {size})")

        if out["kind"] == "battle":
            for anim in out["anims"]:
                spec = mod.ANIMATIONS[anim]
                frames = []
                for i in range(spec["frames"]):
                    mod.pose(parts, anim, i, wpp)
                    bpy.context.view_layer.update()
                    frames.append(render_frame(col, size, mod.PALETTE, f"{asset['name']}_{anim}_{i}"))
                path = os.path.join(out_dir, f"{asset['name']}_battle_{anim}.png")
                sheet.write_sheet(frames, path, anim, spec["fps"], spec.get("loop", True))
                print("WROTE", path)
        elif out["kind"] == "icon":
            mod.pose(parts, "rest", 0, wpp)
            bpy.context.view_layer.update()
            img = render_frame(col, size, mod.PALETTE, f"{asset['name']}_icon",
                               allow_bottom_cut=out.get("anchor") == "top")
            path = os.path.join(out_dir, f"{asset['name']}_icon.png")
            sheet.write_single(img, path)
            print("WROTE", path)

    bc.clear_collection(col)

for p in problems:
    print("PROBLEM", p)
print("BATCH DONE", len(problems), "problemów")
