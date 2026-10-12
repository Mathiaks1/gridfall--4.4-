"""Bohater: poszukiwacz przygód w hełmie, niebieska tunika, czerwona peleryna, miecz i tarcza.

Proporcje „chibi” (duża głowa) dla czytelności w 64 px. Model patrzy w -Y; obrót całości
o FACING_DEG ustawia go w 3/4 w prawo ekranu.
Idle: oddech — górna połowa ciała opada o 1 px w klatkach 1-2, miecz kołysze się o 1 px.
"""
import math

import bpy

import bl_common as bc

RAMPS = {
    "skin":    [(0.0, "U"), (0.10, "V"), (0.40, "W")],
    "pants":   [(0.0, "2"), (0.20, "3"), (0.60, "4")],
    "tunic":   [(0.0, "M"), (0.15, "N"), (0.55, "O")],
    "cape":    [(0.0, "A"), (0.15, "B"), (0.55, "C")],
    "leather": [(0.0, "T"), (0.20, "U"), (0.60, "V")],
    "iron":    [(0.0, "3"), (0.15, "4"), (0.50, "6"), (0.85, "7")],
    "steel":   [(0.0, "5"), (0.25, "6"), (0.55, "7"), (0.85, "8")],
    "gold":    [(0.0, "E"), (0.20, "F"), (0.60, "G"), (0.90, "H")],
    "wood":    [(0.0, "T"), (0.15, "U"), (0.55, "V")],
}
PALETTE = "UVWMNOABCT2345678EFGH0"
FACING_DEG = bc.FACING_HERO_DEG

IDLE_BREATH_PX = [0, -1, -1, 0]
IDLE_SWORD_PX = [0, 0, -1, -1]


def build(col):
    m = {k: bc.toon_material(f"hero_{k}", v) for k, v in RAMPS.items()}
    eye = bc.flat_material("hero_eye", "0")

    root = bpy.data.objects.new("HeroRoot", None)
    col.objects.link(root)
    upper = bpy.data.objects.new("HeroUpper", None)   # wszystko, co „oddycha”
    col.objects.link(upper)
    upper.parent = root

    def add(op, name, mat, parent, **kw):
        ob = bc.new_mesh_object(op, col, name, mat, **kw)
        bc.parent_keep(ob, parent)
        return ob

    # Nogi i buty
    for sx, side in ((-1, "R"), (1, "L")):
        add("cylinder", f"Leg{side}", m["pants"], root, loc=(0.13 * sx, 0, 0.30),
            scale=(0.10, 0.10, 0.22), vertices=10, id_group="legs")
        add("cube", f"Boot{side}", m["leather"], root, loc=(0.13 * sx, -0.04, 0.06),
            scale=(0.11, 0.15, 0.07), smooth=False, id_group="boots")

    # Tułów: tunika (stożek ścięty), pas
    add("cone", "Torso", m["tunic"], upper, loc=(0, 0, 0.78), scale=(0.30, 0.22, 0.30),
        vertices=12, radius1=1.0, radius2=0.78, depth=2.0, id_group="torso")
    add("cylinder", "Belt", m["leather"], upper, loc=(0, 0, 0.58), scale=(0.30, 0.23, 0.04),
        vertices=12, id_group="belt")
    add("cube", "Buckle", m["gold"], upper, loc=(0, -0.235, 0.58), scale=(0.05, 0.02, 0.04),
        smooth=False, id_group="belt")

    # Peleryna za plecami
    add("cube", "Cape", m["cape"], upper, loc=(0, 0.26, 0.70), scale=(0.34, 0.04, 0.44),
        rot=(math.radians(-14), 0, 0), smooth=False, id_group="cape")

    # Głowa, oczy, czasza hełmu z grzebieniem
    head = add("uv_sphere", "Head", m["skin"], upper, loc=(0, 0, 1.38), scale=(0.27, 0.25, 0.27),
               segments=16, ring_count=8, id_group="head")
    for sx in (-1, 1):
        add("cube", f"Eye{sx}", eye, upper, loc=(0.09 * sx, -0.245, 1.34), scale=(0.03, 0.012, 0.06),
            smooth=False, id_group="head")
    add("uv_sphere", "Helmet", m["iron"], upper, loc=(0, 0.02, 1.50), scale=(0.29, 0.28, 0.22),
        segments=16, ring_count=8, id_group="helmet")
    add("cylinder", "HelmetRim", m["iron"], upper, loc=(0, 0.02, 1.48), scale=(0.30, 0.29, 0.03),
        vertices=16, id_group="helmet")
    add("uv_sphere", "Crest", m["cape"], upper, loc=(0, 0.04, 1.74), scale=(0.05, 0.17, 0.06),
        segments=8, ring_count=4, id_group="crest")

    # Ramię z mieczem (prawe, -X) — ostrze odchylone na zewnątrz sylwetki, nie zasłania twarzy
    add("cylinder", "ArmR", m["tunic"], upper, loc=(-0.34, -0.02, 0.86), scale=(0.08, 0.08, 0.18),
        rot=(0, math.radians(-12), 0), vertices=8, id_group="armR")
    add("uv_sphere", "HandR", m["skin"], upper, loc=(-0.40, -0.14, 0.70), scale=(0.08, 0.08, 0.08),
        segments=8, ring_count=4, id_group="armR")
    sword = bpy.data.objects.new("Sword", None)
    col.objects.link(sword)
    sword.location = (-0.40, -0.14, 0.70)
    sword.parent = upper
    add("cube", "Blade", m["steel"], sword, loc=(-0.40, -0.14, 1.16), scale=(0.04, 0.012, 0.40),
        smooth=False, id_group="blade")
    add("cube", "Guard", m["gold"], sword, loc=(-0.40, -0.14, 0.76), scale=(0.12, 0.03, 0.025),
        smooth=False, id_group="hilt")
    add("cube", "Pommel", m["gold"], sword, loc=(-0.40, -0.14, 0.62), scale=(0.035, 0.035, 0.035),
        smooth=False, id_group="hilt")
    # Obrót dopiero po podpięciu części (parent_keep zachowuje pozycję w świecie).
    sword.rotation_euler = (math.radians(-10), math.radians(-22), 0)   # ostrze na zewnątrz i w górę

    # Ramię z tarczą (lewe, +X)
    add("cylinder", "ArmL", m["tunic"], upper, loc=(0.34, -0.02, 0.86), scale=(0.08, 0.08, 0.18),
        rot=(0, math.radians(12), 0), vertices=8, id_group="armL")
    add("cylinder", "Shield", m["wood"], upper, loc=(0.30, -0.24, 0.80), scale=(0.25, 0.25, 0.03),
        rot=(math.radians(90), 0, math.radians(-10)), vertices=16, id_group="shield")
    add("torus", "ShieldRim", m["iron"], upper, loc=(0.30, -0.25, 0.80), scale=(0.25, 0.25, 0.25),
        rot=(math.radians(90), 0, math.radians(-10)), major_radius=1.0, minor_radius=0.08,
        major_segments=16, minor_segments=4, id_group="shieldrim")
    add("uv_sphere", "ShieldBoss", m["gold"], upper, loc=(0.29, -0.31, 0.80), scale=(0.06, 0.06, 0.06),
        segments=8, ring_count=4, id_group="shieldboss")

    root.rotation_euler = (0, 0, math.radians(FACING_DEG))
    return {"root": root, "upper": upper, "sword": sword, "head": head}


def pose(parts, anim, i, world_per_px):
    breath = IDLE_BREATH_PX[i] if anim == "idle" else 0
    sword = IDLE_SWORD_PX[i] if anim == "idle" else 0
    parts["upper"].location.z = bc.px_z(breath, world_per_px)
    parts["sword"].location.z = 0.70 + bc.px_z(sword - breath, world_per_px)


ANIMATIONS = {"idle": {"frames": len(IDLE_BREATH_PX), "fps": 5, "loop": True}}
