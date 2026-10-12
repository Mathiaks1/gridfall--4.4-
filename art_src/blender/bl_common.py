"""Wspólne funkcje Blendera (testowane na 3.5.0, EEVEE legacy).

Model oświetlenia:
  - słońce o mocy pi, bez otoczenia => Shader to RGB daje ~cos(kąt) w zakresie 0..1,
  - progi rampy materiału (interpolacja CONSTANT) mapują to na znaki palety,
  - emisja => kolory wychodzą dokładnie z palety (kwantyzacja tylko je potwierdza).
"""
import math

import bpy
from mathutils import Vector

import config
import palette_def as pd

HEX = {ch: hx for ch, hx, *_ in pd.entries()}

CAMERA_ELEVATION_DEG = 25.0      # kąt patrzenia z góry, wspólny dla wszystkich renderów
LIGHT_DIR = Vector((1.0, 0.8, -1.2))  # kierunek promieni: światło z lewej-góry-przodu
FACING_HERO_DEG = 35.0           # obrót modelu: bohater patrzy w prawo ekranu
FACING_MONSTER_DEG = -35.0       # potwory patrzą w lewo


def lin(ch):
    """Znak palety -> liniowy RGBA (wejścia węzłów są w przestrzeni liniowej)."""
    def f(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = pd.hex_to_rgb(HEX[ch])
    return (f(r), f(g), f(b), 1.0)


# --- materiały ----------------------------------------------------------------

def toon_material(name, stops):
    """stops: [(próg 0..1, znak palety), ...] rosnąco. Pierwszy próg zwykle 0."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position = stops[0][0]
    els[0].color = lin(stops[0][1])
    for pos, ch in stops[1:]:
        els.new(pos).color = lin(ch)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diff.outputs["BSDF"], s2rgb.inputs["Shader"])
    nt.links.new(s2rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    mat["palette_chars"] = "".join(ch for _, ch in stops)
    return mat


def flat_material(name, ch):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = lin(ch)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    mat["palette_chars"] = ch
    return mat


def _id_material(i):
    name = f"__id_{i}"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    # Kolory ID: siatka 6x6x6, wystarczająco różne po zapisie 8-bit.
    r, g, b = (i % 6) / 5.0, ((i // 6) % 6) / 5.0, ((i // 36) % 6) / 5.0
    emit.inputs["Color"].default_value = (r, g, b, 1.0)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return mat


# --- obiekty ------------------------------------------------------------------

def link(ob, col):
    for c in ob.users_collection:
        c.objects.unlink(ob)
    col.objects.link(ob)
    return ob


def new_mesh_object(op, col, name, mat, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0),
                    smooth=True, id_group=None, **kw):
    """Tworzy prymityw operatorem bpy.ops.mesh.primitive_<op>_add i przenosi do kolekcji."""
    getattr(bpy.ops.mesh, f"primitive_{op}_add")(location=loc, rotation=rot, **kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    if smooth:
        bpy.ops.object.shade_smooth()
    ob["id_group"] = id_group or name
    return link(ob, col)


def parent_keep(child, parent):
    bpy.context.view_layer.update()   # matrix_world rodzica musi być aktualna
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def part(op, col, name, mat, parent, **kw):
    """Prymityw podpięty do rodzica z zachowaniem pozycji w świecie."""
    ob = new_mesh_object(op, col, name, mat, **kw)
    parent_keep(ob, parent)
    return ob


def limb(col, name, mat, parent, p1, p2, radius, vertices=8, id_group=None, cone_tip=None):
    """Cylinder (lub stożek, gdy cone_tip podane) od punktu p1 do p2 — kości, kończyny, pazury."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    rot = d.to_track_quat("Z", "Y").to_euler()
    if cone_tip is None:
        ob = new_mesh_object("cylinder", col, name, mat, loc=(p1 + p2) / 2, rot=rot,
                             scale=(radius, radius, d.length), vertices=vertices, radius=1.0, depth=1.0,
                             id_group=id_group)
    else:
        ob = new_mesh_object("cone", col, name, mat, loc=(p1 + p2) / 2, rot=rot,
                             scale=(radius, radius, d.length), vertices=vertices, radius1=1.0,
                             radius2=cone_tip, depth=1.0, id_group=id_group)
    parent_keep(ob, parent)
    return ob


def empty(col, name, parent=None, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    col.objects.link(ob)
    ob.location = loc
    if parent is not None:
        ob.parent = parent
    return ob


def clear_collection(col):
    for ob in list(col.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def px_z(n, world_per_px):
    """Przesunięcie w osi Z równe dokładnie n pikselom ekranu (kamera patrzy z góry pod kątem)."""
    return n * world_per_px / math.cos(math.radians(CAMERA_ELEVATION_DEG))


# --- scena / kamera / render ---------------------------------------------------

def configure_render(scene, size):
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.filter_size = 0.0          # Film > Filter Size = 0 px
    scene.render.film_transparent = True
    scene.eevee.taa_render_samples = 1      # 1 próbka = brak antyaliasingu
    scene.eevee.use_soft_shadows = False
    scene.eevee.use_gtao = False
    scene.eevee.use_bloom = False
    scene.eevee.use_ssr = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"


def frame_camera(cam, size, world_per_px, ground_margin_px=4, objects=None, anchor_top=False):
    """Kamera ortho o stałej elewacji, wyśrodkowana w poziomie na x=0.

    Pionowo: najniższy rzutowany wierzchołek obiektów (poza spoczynkowa) ląduje
    ground_margin_px nad dolną krawędzią. Liczone raz na wyjście => wspólna linia gruntu
    dla wszystkich klatek animacji. anchor_top (popiersie na ikonę): czubek modelu
    ground_margin_px pod górną krawędzią, dół kadru ucina resztę. Zwraca (dół_px, góra_px) zajętości kadru.
    """
    e = math.radians(CAMERA_ELEVATION_DEG)
    extent = size * world_per_px
    direction = Vector((0, math.cos(e), -math.sin(e)))   # patrzy w +Y i w dół
    up = Vector((0, math.sin(e), math.cos(e)))
    lo, hi = 0.0, 0.0
    if objects:
        bpy.context.view_layer.update()
        vals = [(ob.matrix_world @ v.co).dot(up) for ob in objects if ob.type == "MESH" for v in ob.data.vertices]
        lo, hi = min(vals), max(vals)
    # środek kadru w jednostkach „up”, wyrównany do siatki pikseli
    if anchor_top:
        center_up = hi - extent / 2 + ground_margin_px * world_per_px
    else:
        center_up = lo + extent / 2 - ground_margin_px * world_per_px
    center_up = round(center_up / world_per_px) * world_per_px
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = extent
    cam.location = up * center_up - direction * 20.0
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_start = 0.1
    cam.data.clip_end = 100.0
    top_px = (hi - (center_up - extent / 2)) / world_per_px
    return ground_margin_px, top_px


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_id_pass(scene, col, path):
    """Render pomocniczy: każda grupa id_group w jednolitym kolorze (do linii wewnętrznych)."""
    groups = {}
    saved = []
    for ob in col.all_objects:
        if ob.type != "MESH":
            continue
        gid = groups.setdefault(ob.get("id_group", ob.name), len(groups))
        saved.append((ob, [s.material for s in ob.material_slots]))
        for s in ob.material_slots:
            s.material = _id_material(gid)
    try:
        render_to(scene, path)
    finally:
        for ob, mats in saved:
            for s, m in zip(ob.material_slots, mats):
                s.material = m
