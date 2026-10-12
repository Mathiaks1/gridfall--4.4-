"""Szlam: kropla z oczami. Idle = przysiad/rozciągnięcie (squash & stretch)."""
import math

import bmesh
import bpy

import bl_common as bc

RAMPS = {
    "slime": [(0.0, "I"), (0.10, "J"), (0.40, "K"), (0.88, "L")],
}
PALETTE = "IJKL08"
FACING_DEG = bc.FACING_MONSTER_DEG

# Skala Z kolejnych klatek idle; X/Y kompensują objętość.
IDLE_SQUASH = [1.00, 0.95, 0.91, 0.95]


def build(col):
    body_mat = bc.toon_material("slime_body", RAMPS["slime"])
    eye_mat = bc.flat_material("slime_eye", "0")
    glint_mat = bc.flat_material("slime_glint", "8")

    body = bc.new_mesh_object("uv_sphere", col, "SlimeBody", body_mat, loc=(0, 0, 0),
                              segments=24, ring_count=12, id_group="body")
    # Kształt w lokalnych współrzędnych: płaski spód na z=0, lekko spiczasty czubek.
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for v in bm.verts:
        x, y, z = v.co
        z = max(z, -0.35)
        z = z + 0.35
        if z > 0.95:
            z += (z - 0.95) * 0.9
        v.co = (x * 0.95, y * 0.85, z * 0.72)
    bm.to_mesh(body.data)
    bm.free()

    root = bpy.data.objects.new("SlimeRoot", None)
    col.objects.link(root)
    bc.parent_keep(body, root)
    parts = {"body": body, "root": root, "eyes": []}
    for sx in (-1, 1):
        eye = bc.new_mesh_object("uv_sphere", col, f"SlimeEye{sx}", eye_mat,
                                 loc=(0.27 * sx, -0.74, 0.60), scale=(0.11, 0.07, 0.16),
                                 segments=12, ring_count=6, id_group="body")
        glint = bc.new_mesh_object("uv_sphere", col, f"SlimeGlint{sx}", glint_mat,
                                   loc=(0.27 * sx - 0.035, -0.80, 0.66), scale=(0.045, 0.03, 0.05),
                                   segments=8, ring_count=4, id_group="body")
        # Oczy tylko się przesuwają razem z czubkiem (bez skalowania) — stały kształt w każdej klatce.
        for ob in (eye, glint):
            bc.parent_keep(ob, root)
            parts["eyes"].append((ob, ob.location.z))

    root.rotation_euler = (0, 0, math.radians(FACING_DEG))
    return parts


def pose(parts, anim, i, world_per_px):
    sz = IDLE_SQUASH[i] if anim == "idle" else 1.0
    sxy = 1.0 / math.sqrt(sz)
    parts["body"].scale = (sxy, sxy, sz)
    for ob, z0 in parts["eyes"]:
        # przesunięcie zaokrąglone do pełnych pikseli ekranu
        dz = z0 * sz - z0
        n = round(dz / bc.px_z(1, world_per_px))
        ob.location.z = z0 + bc.px_z(n, world_per_px)


ANIMATIONS = {"idle": {"frames": len(IDLE_SQUASH), "fps": 6, "loop": True}}
