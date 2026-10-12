class_name BattleSprite
extends TextureRect
## Animowany sprite bojowy z poziomego sprite sheetu (klatki o jednakowej szerokości).
## Skala całkowita (pixel_scale), filtr Nearest — pixel art bez rozmycia.

@export var pixel_scale: int = 2

var _sheet: Texture2D
var _frames: int = 1
var _fps: float = 6.0
var _time: float = 0.0
var _atlas := AtlasTexture.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture = _atlas


func play(sheet: Texture2D, frames: int, fps: float) -> void:
	_sheet = sheet
	_frames = maxi(frames, 1)
	_fps = fps
	_time = 0.0
	visible = sheet != null
	if sheet == null:
		set_process(false)
		return
	var w := sheet.get_width() / _frames
	_atlas.atlas = sheet
	_atlas.region = Rect2(0, 0, w, sheet.get_height())
	custom_minimum_size = Vector2(w, sheet.get_height()) * pixel_scale
	set_process(_frames > 1)


func _process(delta: float) -> void:
	_time += delta
	var frame := int(_time * _fps) % _frames
	var w := _atlas.region.size.x
	_atlas.region.position.x = w * frame
