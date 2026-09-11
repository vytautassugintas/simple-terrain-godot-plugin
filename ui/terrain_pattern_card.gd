@tool
class_name TerrainPatternCard
extends Button

## Card item representing a brush pattern in the Pattern Library grid.

signal card_selected(card: TerrainPatternCard)
signal card_double_clicked(card: TerrainPatternCard)

var pattern_name: String = ""
var pattern_path: String = ""
var pattern_image: Image = null
var pattern_texture: Texture2D = null

@onready var thumbnail: TextureRect = %Thumbnail
@onready var title_label: Label = %TitleLabel
@onready var dim_label: Label = %DimLabel


const FALLBACK_ICON: Texture2D = preload("res://addons/simple_terrain/icons/pattern_library.svg")


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func setup(p_name: String, p_path: String, p_img: Image, p_tex: Texture2D) -> void:
	pattern_name = p_name
	pattern_path = p_path
	pattern_image = p_img
	pattern_texture = p_tex

	if is_node_ready():
		_update_display()


func _update_display() -> void:
	if thumbnail != null:
		if pattern_texture != null:
			thumbnail.texture = pattern_texture
			thumbnail.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			thumbnail.texture = FALLBACK_ICON
			thumbnail.modulate = Color(0.55, 0.68, 0.85, 0.6)

	if title_label != null:
		title_label.text = pattern_name
		title_label.tooltip_text = pattern_name

	var dims: String = ""
	if pattern_image != null and not pattern_image.is_empty():
		dims = "%dx%d" % [pattern_image.get_width(), pattern_image.get_height()]
	if dim_label != null:
		dim_label.text = dims
		dim_label.tooltip_text = dims

	tooltip_text = "%s\nPath: %s%s\n(Click to select brush pattern)" % [
		pattern_name,
		pattern_path,
		("\nSize: " + dims) if not dims.is_empty() else ""
	]



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			card_double_clicked.emit(self)


func _on_pressed() -> void:
	card_selected.emit(self)
