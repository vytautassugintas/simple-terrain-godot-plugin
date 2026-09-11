@tool
class_name TerrainBrushCard
extends Button

## Visual card representing a brush shape / tip (Circle, Square, Patch, Dots, Cross, Custom).

signal card_selected(card: TerrainBrushCard)
signal card_double_clicked(card: TerrainBrushCard)

var brush_id: String = ""
var brush_name: String = ""
var brush_path: String = ""
var brush_image: Image = null
var brush_texture: Texture2D = null

@onready var thumbnail: TextureRect = %Thumbnail
@onready var title_label: Label = %TitleLabel
@onready var dim_label: Label = %DimLabel

const FALLBACK_ICON: Texture2D = preload("res://addons/simple_terrain/icons/brush_shape.svg")


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func setup(p_id: String, p_name: String, p_path: String, p_img: Image, p_tex: Texture2D) -> void:
	brush_id = p_id
	brush_name = p_name
	brush_path = p_path
	brush_image = p_img
	brush_texture = p_tex

	if is_node_ready():
		_update_display()


func _update_display() -> void:
	if thumbnail != null:
		if brush_texture != null:
			thumbnail.texture = brush_texture
			thumbnail.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			thumbnail.texture = FALLBACK_ICON
			thumbnail.modulate = Color(0.7, 0.8, 0.95, 0.8)

	if title_label != null:
		title_label.text = brush_name
		title_label.tooltip_text = brush_name

	var dims: String = ""
	if brush_image != null and not brush_image.is_empty():
		dims = "%dx%d" % [brush_image.get_width(), brush_image.get_height()]
	if dim_label != null:
		dim_label.text = dims
		dim_label.tooltip_text = dims

	tooltip_text = "%s\nPath: %s%s\n(Click to select brush shape)" % [
		brush_name,
		brush_path,
		("\nSize: " + dims) if not dims.is_empty() else ""
	]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			card_double_clicked.emit(self)


func _on_pressed() -> void:
	card_selected.emit(self)
