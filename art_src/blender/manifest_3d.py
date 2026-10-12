"""Lista assetów ścieżki A (render 3D -> pixel art).

Każdy wpis: model (moduł w models/), kategoria wyjściowa, kolekcja w szablonie i lista wyjść.
Wyjście „battle” = sprite sheety animacji, „icon” = pojedyncza klatka (ikona na polu/w UI).
"""
import config

ASSETS = [
    {
        "name": "monster_slime",
        "model": "slime",
        "category": "monsters",
        "collection": "Monsters",
        "outputs": [
            {"kind": "battle", "size": config.PORTRAIT, "wpp": config.WORLD_PER_PX_PORTRAIT,
             "margin_px": 4, "anims": ["idle"]},
            {"kind": "icon", "size": config.ICON, "wpp": 0.062, "margin_px": 4, "facing_deg": 0},
        ],
    },
    {
        "name": "monster_skeleton",
        "model": "skeleton",
        "category": "monsters",
        "collection": "Monsters",
        "outputs": [
            {"kind": "battle", "size": config.PORTRAIT, "wpp": config.WORLD_PER_PX_PORTRAIT,
             "margin_px": 3, "anims": ["idle"]},
            # Popiersie (kadr od czubka głowy): pełna postać w 32 px gubi cienkie kości.
            {"kind": "icon", "size": config.ICON, "wpp": 0.024, "margin_px": 2, "facing_deg": 0,
             "anchor": "top"},
        ],
    },
    {
        "name": "monster_ghoul",
        "model": "ghoul",
        "category": "monsters",
        "collection": "Monsters",
        "outputs": [
            {"kind": "battle", "size": config.PORTRAIT, "wpp": config.WORLD_PER_PX_PORTRAIT,
             "margin_px": 3, "anims": ["idle"]},
            {"kind": "icon", "size": config.ICON, "wpp": 0.032, "margin_px": 2, "facing_deg": 0,
             "anchor": "top"},
        ],
    },
    {
        "name": "hero",
        "model": "hero",
        "category": "hero",
        "collection": "Hero",
        "outputs": [
            {"kind": "battle", "size": config.PORTRAIT, "wpp": config.WORLD_PER_PX_PORTRAIT,
             "margin_px": 3, "anims": ["idle"]},
        ],
    },
]
