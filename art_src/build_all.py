"""Pełna przebudowa grafiki: szablon .blend -> render 3D -> piksele -> podglądy -> kontrola.

  E:\\Blender\\3.5\\python\\bin\\python.exe art_src\\build_all.py [--skip-3d]

Ścieżka do Blendera: zmienna środowiskowa BLENDER (domyślnie E:\\Blender\\blender.exe).
Po zmianie palety (tools/palette_def.py) lub rozmiarów (tools/config.py) wystarczy uruchomić ponownie.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "tools"))
import config  # noqa: E402
import pxlib as px  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ENV = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
BLENDER = os.environ.get("BLENDER", r"E:\Blender\blender.exe")
PY = sys.executable


def run(args):
    print(">", " ".join(os.path.basename(a) if os.path.isabs(a) else a for a in args))
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace",
                       env=ENV)
    out = r.stdout + r.stderr
    for line in out.splitlines():
        if any(k in line for k in ("WROTE", "PROBLEM", "DONE", "OK", "Error", "Traceback")):
            print("   ", line)
    if r.returncode != 0 or "Traceback" in out:
        sys.exit(f"BŁĄD w kroku: {args[-1]}")


run([PY, os.path.join(HERE, "tools", "export_palette.py")])
if "--skip-3d" not in sys.argv:
    run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(HERE, "blender", "build_template.py")])
    run([BLENDER, "-b", config.TEMPLATE_BLEND, "--python", os.path.join(HERE, "blender", "render_batch.py")])
run([PY, os.path.join(HERE, "pixel", "build_pixel.py")])
run([PY, os.path.join(HERE, "tools", "pilot_preview.py")])
run([PY, os.path.join(HERE, "tools", "contact_sheet.py"), "monsters", "hero"])
run([PY, os.path.join(HERE, "tools", "tiles_preview.py")])

# Kontrola końcowa: każdy PNG w assets/art ma alfę 0/255 i kolory wyłącznie z palety.
bad = 0
for root, _, files in os.walk(config.OUT_ROOT):
    for f in files:
        if f.endswith(".png"):
            img = px.load_png(os.path.join(root, f))
            if not (px.check_alpha_binary(img) and px.check_in_palette(img)):
                print("NIEZGODNY:", os.path.join(root, f))
                bad += 1
print("KONTROLA:", "OK" if not bad else f"{bad} plików niezgodnych")
