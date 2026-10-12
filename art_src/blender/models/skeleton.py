"""Szkielet: kości z cylindrów, żebra z torusów, czerwone źrenice, zardzewiały miecz.

Model patrzy w -Y (+X = jego lewa strona). Idle: grzechotanie — tułów opada o 1 px,
czaszka podskakuje osobno o 1 px z przesunięciem fazy, miecz kołysze się o 1 px.
"""
import math

import bl_common as bc

RAMPS = {
    "bone": [(0.0, "4"), (0.15, "6"), (0.50, "7"), (0.85, "8")],
    "iron": [(0.0, "4"), (0.20, "5"), (0.55, "6"), (0.85, "7")],
    "rust": [(0.0, "T"), (0.25, "E"), (0.65, "F")],
}
PALETTE = "345678TEF0D"
FACING_DEG = bc.FACING_MONSTER_DEG

IDLE_BODY_PX = [0, -1, -1, 0]
IDLE_SKULL_PX = [0, 0, -1, 1]     # względem tułowia
IDLE_SWORD_PX = [0, -1, 0, 0]     # względem tułowia
SKULL_Z = 1.70
SKULL_R = 0.20


def build(col):
    m = {k: bc.toon_material(f"skel_{k}", v) for k, v in RAMPS.items()}
    socket = bc.flat_material("skel_socket", "0")
    pupil = bc.flat_material("skel_pupil", "D")

    root = bc.empty(col, "SkelRoot")
    upper = bc.empty(col, "SkelUpper", root)

    # Nogi
    for sx in (-1, 1):
        g = "legR" if sx < 0 else "legL"
        bc.part("cube", col, f"Foot{sx}", m["bone"], root, loc=(0.13 * sx, -0.06, 0.035),
                scale=(0.055, 0.10, 0.035), smooth=False, id_group=g)
        bc.limb(col, f"Tibia{sx}", m["bone"], root, (0.13 * sx, 0, 0.06), (0.12 * sx, 0.03, 0.45), 0.045, id_group=g)
        bc.part("uv_sphere", col, f"Knee{sx}", m["bone"], root, loc=(0.12 * sx, 0.02, 0.45),
                scale=(0.06, 0.06, 0.06), segments=8, ring_count=4, id_group=g)
        bc.limb(col, f"Femur{sx}", m["bone"], root, (0.12 * sx, 0.03, 0.45), (0.11 * sx, 0, 0.82), 0.05, id_group=g)

    bc.part("uv_sphere", col, "Pelvis", m["bone"], root, loc=(0, 0, 0.86), scale=(0.17, 0.11, 0.08),
            segments=12, ring_count=6, id_group="pelvis")

    # Kręgosłup, żebra, obojczyki
    bc.limb(col, "Spine", m["bone"], upper, (0, 0.04, 0.86), (0, 0.04, 1.45), 0.04, id_group="spine")
    for i, (z, r) in enumerate([(1.12, 0.15), (1.22, 0.18), (1.32, 0.19)]):
        bc.part("torus", col, f"Rib{i}", m["bone"], upper, loc=(0, 0.0, z), scale=(1.0, 0.72, 1.0),
                major_radius=r, minor_radius=0.028, major_segments=16, minor_segments=4, id_group=f"rib{i}")
    bc.limb(col, "Clavicle", m["bone"], upper, (-0.25, 0.01, 1.43), (0.25, 0.01, 1.43), 0.035, id_group="clavicle")
    bc.limb(col, "Neck", m["bone"], upper, (0, 0.03, 1.43), (0, 0.02, 1.56), 0.035, id_group="spine")

    # Ręka z mieczem (prawa, -X), wysunięta do przodu
    bc.limb(col, "UpperArmR", m["bone"], upper, (-0.25, 0, 1.42), (-0.32, -0.06, 1.13), 0.04, id_group="armR")
    bc.limb(col, "ForeArmR", m["bone"], upper, (-0.32, -0.06, 1.13), (-0.33, -0.24, 0.98), 0.035, id_group="armR")
    bc.part("uv_sphere", col, "HandR", m["bone"], upper, loc=(-0.33, -0.26, 0.97), scale=(0.05, 0.05, 0.05),
            segments=8, ring_count=4, id_group="armR")
    sword = bc.empty(col, "SkelSword", upper)
    hand = (-0.33, -0.26, 0.97)
    bc.limb(col, "Grip", m["rust"], sword, (hand[0], hand[1], hand[2] - 0.08), (hand[0], hand[1], hand[2] + 0.04),
            0.025, vertices=6, id_group="hilt")
    bc.limb(col, "Crossguard", m["rust"], sword, (hand[0] - 0.10, hand[1], hand[2] + 0.06),
            (hand[0] + 0.10, hand[1], hand[2] + 0.06), 0.025, vertices=4, id_group="hilt")
    # Ostrze jako płaski klocek (szeroki na 3 px) — cienki stożek znikał w 64 px.
    bc.part("cube", col, "Blade", m["iron"], sword, loc=(hand[0], hand[1], hand[2] + 0.42),
            scale=(0.055, 0.015, 0.34), smooth=False, id_group="blade")
    bc.part("cube", col, "BladeNotch", m["rust"], sword, loc=(hand[0] + 0.045, hand[1] - 0.01, hand[2] + 0.50),
            scale=(0.02, 0.02, 0.05), smooth=False, id_group="blade")

    # Ręka zwisająca (lewa, +X)
    bc.limb(col, "UpperArmL", m["bone"], upper, (0.25, 0, 1.42), (0.30, 0.03, 1.12), 0.04, id_group="armL")
    bc.limb(col, "ForeArmL", m["bone"], upper, (0.30, 0.03, 1.12), (0.31, -0.03, 0.86), 0.035, id_group="armL")
    bc.part("uv_sphere", col, "HandL", m["bone"], upper, loc=(0.31, -0.04, 0.83), scale=(0.05, 0.05, 0.06),
            segments=8, ring_count=4, id_group="armL")

    # Czaszka: oczodoły + czerwone źrenice + otwór nosowy + żuchwa
    skull = bc.empty(col, "SkullPivot", upper)
    bc.part("uv_sphere", col, "Skull", m["bone"], skull, loc=(0, -0.02, SKULL_Z), scale=(SKULL_R, 0.19, SKULL_R),
            segments=16, ring_count=8, id_group="skull")
    bc.part("cube", col, "Jaw", m["bone"], skull, loc=(0, -0.08, SKULL_Z - 0.19), scale=(0.12, 0.09, 0.04),
            smooth=False, id_group="jaw")
    for sx in (-1, 1):
        bc.part("uv_sphere", col, f"Socket{sx}", socket, skull, loc=(0.075 * sx, -0.185, SKULL_Z + 0.01),
                scale=(0.058, 0.025, 0.065), segments=8, ring_count=4, id_group="skull")
        bc.part("uv_sphere", col, f"Pupil{sx}", pupil, skull, loc=(0.075 * sx, -0.215, SKULL_Z + 0.005),
                scale=(0.026, 0.012, 0.028), segments=6, ring_count=3, id_group="skull")
    bc.part("uv_sphere", col, "NoseHole", socket, skull, loc=(0, -0.195, SKULL_Z - 0.08),
            scale=(0.022, 0.012, 0.028), segments=6, ring_count=3, id_group="skull")

    # Miecz obracamy po podpięciu części (pivot w dłoni): ostrze do przodu-w górę.
    pivot = bc.empty(col, "SwordPivot", upper, loc=hand)
    bc.parent_keep(sword, pivot)
    pivot.rotation_euler = (math.radians(10), math.radians(-30), 0)   # na zewnątrz i w górę

    root.rotation_euler = (0, 0, math.radians(FACING_DEG))
    return {"root": root, "upper": upper, "skull": skull, "sword_pivot": pivot}


def pose(parts, anim, i, world_per_px):
    idle = anim == "idle"
    parts["upper"].location.z = bc.px_z(IDLE_BODY_PX[i] if idle else 0, world_per_px)
    parts["skull"].location.z = bc.px_z(IDLE_SKULL_PX[i] if idle else 0, world_per_px)
    parts["sword_pivot"].location.z = 0.97 + bc.px_z(IDLE_SWORD_PX[i] if idle else 0, world_per_px)


ANIMATIONS = {"idle": {"frames": len(IDLE_BODY_PX), "fps": 6, "loop": True}}
