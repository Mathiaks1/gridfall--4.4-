"""Buduje art_src/blender/gridfall_template.blend od zera.

  blender -b --factory-startup --python art_src/blender/build_template.py

Zawartość: ustawienia renderu, świat bez światła otoczenia, kamera ortho CAM_Main,
słońce SUN_Key (lewa-góra-przód), puste kolekcje per kategoria.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(os.path.dirname(HERE), "tools")]

import bpy  # noqa: E402

import bl_common as bc  # noqa: E402
import config  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Gridfall"
bc.configure_render(scene, config.PORTRAIT)

world = bpy.data.worlds.new("World_NoAmbient")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
scene.world = world

rig = bpy.data.collections.new("Rig")
scene.collection.children.link(rig)

cam = bpy.data.objects.new("CAM_Main", bpy.data.cameras.new("CAM_Main"))
rig.objects.link(cam)
bc.frame_camera(cam, config.PORTRAIT, config.WORLD_PER_PX_PORTRAIT)
scene.camera = cam

sun_data = bpy.data.lights.new("SUN_Key", "SUN")
sun_data.energy = math.pi          # => Shader to RGB ~ cos(kąt padania)
sun_data.use_shadow = False        # czyste pasma toon; cienie rzucane rysujemy rampą
sun = bpy.data.objects.new("SUN_Key", sun_data)
rig.objects.link(sun)
sun.rotation_euler = bc.LIGHT_DIR.to_track_quat("-Z", "Y").to_euler()

for name in ("Monsters", "Hero", "NPC", "Items", "Resources", "Backgrounds"):
    scene.collection.children.link(bpy.data.collections.new(name))

os.makedirs(os.path.dirname(config.TEMPLATE_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=config.TEMPLATE_BLEND, compress=True)
print("TEMPLATE OK", config.TEMPLATE_BLEND)
