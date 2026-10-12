"""Parametry globalne pipeline'u. Zmiana tutaj + ponowny batch = przebudowa wszystkiego."""
import os

ART_SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.dirname(ART_SRC)
OUT_ROOT = os.path.join(PROJECT, "assets", "art")
PREVIEW_DIR = os.path.join(ART_SRC, "previews")
TEMPLATE_BLEND = os.path.join(ART_SRC, "blender", "gridfall_template.blend")

# Rozmiary bazowe (px). Logiczna rozdzielczość gry: 640x360, skala całkowita.
CELL = 32          # pole siatki i nakładki
ICON = 32          # przedmioty, surowce, ikony potworów/NPC
PORTRAIT = 64      # sprite'y bojowe i portrety

# Gęstość pikseli renderów 3D: jednostki świata na 1 px. Wspólna dla wszystkich
# portretów, więc wielkości potworów są względem siebie spójne.
WORLD_PER_PX_PORTRAIT = 0.04   # 64 px = 2.56 j.
WORLD_PER_PX_ICON = 0.08       # 32 px = 2.56 j. (ten sam kadr, połowa rozdzielczości)

CATEGORIES = ("tiles", "monsters", "hero", "npc", "items", "resources", "ui", "vfx", "backgrounds")


def out_dir(category):
    assert category in CATEGORIES, category
    d = os.path.join(OUT_ROOT, category)
    os.makedirs(d, exist_ok=True)
    return d
