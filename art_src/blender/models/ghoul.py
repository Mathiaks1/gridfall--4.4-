"""Ghul: przygarbiony trupożerca — długie ręce z pazurami, szpiczaste uszy, żółte oczy.

Skóra blada, fioletowo-szara (cień z rampy arcane, światła z kamienia), żeby odróżniała się
od kości szkieleta (ciepła biel) i od zielonego szlamu.
Model patrzy w -Y. Idle: ciężki oddech — tułów i głowa opadają o 1 px, ręce kołyszą się
z opóźnieniem fazy.
"""
import math

import bl_common as bc

RAMPS = {
    "skin":  [(0.0, "Q"), (0.12, "4"), (0.45, "5"), (0.85, "6")],
    "cloth": [(0.0, "T"), (0.45, "U")],
    "claw":  [(0.0, "5"), (0.35, "7"), (0.75, "8")],
}
PALETTE = "Q45678TUBH0"
FACING_DEG = bc.FACING_MONSTER_DEG

IDLE_BODY_PX = [0, -1, -1, 0]
IDLE_ARMS_PX = [0, 0, -1, -1]     # względem tułowia (opóźnione)


def build(col):
    m = {k: bc.toon_material(f"ghoul_{k}", v) for k, v in RAMPS.items()}
    mouth = bc.flat_material("ghoul_mouth", "B")
    eye = bc.flat_material("ghoul_eye", "H")
    fang = bc.flat_material("ghoul_fang", "8")

    root = bc.empty(col, "GhoulRoot")
    upper = bc.empty(col, "GhoulUpper", root)
    arms = bc.empty(col, "GhoulArms", upper)

    # Nogi w przysiadzie: kolana do przodu
    for sx in (-1, 1):
        g = "legR" if sx < 0 else "legL"
        bc.part("cube", col, f"Foot{sx}", m["skin"], root, loc=(0.19 * sx, -0.13, 0.04),
                scale=(0.08, 0.13, 0.04), smooth=False, id_group=g)
        bc.limb(col, f"Shin{sx}", m["skin"], root, (0.19 * sx, -0.06, 0.06), (0.21 * sx, -0.20, 0.42), 0.065, id_group=g)
        bc.limb(col, f"Thigh{sx}", m["skin"], root, (0.21 * sx, -0.20, 0.42), (0.14 * sx, 0.04, 0.63), 0.085, id_group=g)

    bc.part("uv_sphere", col, "Hips", m["skin"], root, loc=(0, 0.05, 0.66), scale=(0.21, 0.16, 0.13),
            segments=12, ring_count=6, id_group="torso")
    bc.part("cube", col, "Loincloth", m["cloth"], root, loc=(0, -0.10, 0.58), scale=(0.12, 0.03, 0.10),
            rot=(math.radians(-10), 0, 0), smooth=False, id_group="cloth")

    # Tułów pochylony do przodu, garb
    bc.part("uv_sphere", col, "Torso", m["skin"], upper, loc=(0, -0.04, 0.95), scale=(0.26, 0.20, 0.33),
            rot=(math.radians(32), 0, 0), segments=14, ring_count=7, id_group="torso")
    bc.part("uv_sphere", col, "Hump", m["skin"], upper, loc=(0, 0.10, 1.12), scale=(0.17, 0.14, 0.14),
            segments=10, ring_count=5, id_group="torso")

    # Głowa nisko, wysunięta; otwarta paszcza, żółte oczy, szpiczaste uszy
    bc.part("uv_sphere", col, "Head", m["skin"], upper, loc=(0, -0.36, 1.26), scale=(0.21, 0.21, 0.19),
            segments=14, ring_count=7, id_group="head")
    bc.part("uv_sphere", col, "Mouth", mouth, upper, loc=(0, -0.55, 1.16), scale=(0.10, 0.04, 0.06),
            segments=8, ring_count=4, id_group="head")
    for sx in (-1, 1):   # kły z górnej szczęki
        bc.limb(col, f"Fang{sx}", fang, upper, (0.045 * sx, -0.585, 1.205), (0.045 * sx, -0.59, 1.12),
                0.02, vertices=4, id_group="head", cone_tip=0.0)
    for sx in (-1, 1):
        bc.part("uv_sphere", col, f"Eye{sx}", eye, upper, loc=(0.085 * sx, -0.545, 1.29),
                scale=(0.042, 0.02, 0.034), segments=6, ring_count=3, id_group="head")
        bc.limb(col, f"Ear{sx}", m["skin"], upper, (0.17 * sx, -0.30, 1.30), (0.42 * sx, -0.16, 1.38),
                0.075, vertices=6, id_group="head", cone_tip=0.0)

    # Długie ręce zwisające prawie do ziemi + 3 pazury
    for sx in (-1, 1):
        g = "armR" if sx < 0 else "armL"
        sh, el, ha = (0.29 * sx, -0.12, 1.12), (0.38 * sx, -0.26, 0.80), (0.33 * sx, -0.38, 0.46)
        bc.limb(col, f"UpperArm{sx}", m["skin"], arms, sh, el, 0.06, id_group=g)
        bc.limb(col, f"ForeArm{sx}", m["skin"], arms, el, ha, 0.05, id_group=g)
        bc.part("uv_sphere", col, f"Hand{sx}", m["skin"], arms, loc=ha, scale=(0.065, 0.06, 0.06),
                segments=8, ring_count=4, id_group=g)
        for k, dx in enumerate((-0.04, 0.0, 0.04)):
            tip = (ha[0] + dx * 1.3, ha[1] - 0.07, ha[2] - 0.17)
            bc.limb(col, f"Claw{sx}_{k}", m["claw"], arms, (ha[0] + dx, ha[1] - 0.02, ha[2] - 0.03), tip,
                    0.018, vertices=4, id_group=f"claw{sx}", cone_tip=0.0)

    root.rotation_euler = (0, 0, math.radians(FACING_DEG))
    return {"root": root, "upper": upper, "arms": arms}


def pose(parts, anim, i, world_per_px):
    idle = anim == "idle"
    parts["upper"].location.z = bc.px_z(IDLE_BODY_PX[i] if idle else 0, world_per_px)
    parts["arms"].location.z = bc.px_z(IDLE_ARMS_PX[i] if idle else 0, world_per_px)


ANIMATIONS = {"idle": {"frames": len(IDLE_BODY_PX), "fps": 5, "loop": True}}
