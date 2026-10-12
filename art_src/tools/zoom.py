"""Podgląd: python zoom.py in.png out.png [skala] [tło] — nearest-neighbor na ciemnym tle."""
import sys
import pxlib as px
src, dst = sys.argv[1], sys.argv[2]
k = int(sys.argv[3]) if len(sys.argv) > 3 else 8
bg = sys.argv[4] if len(sys.argv) > 4 else "1"
px.save_png(px.upscale(px.flatten_on(px.load_png(src), bg), k), dst)
