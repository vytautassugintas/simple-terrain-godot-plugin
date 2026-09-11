@tool
class_name TerrainFoliageCard
extends Button

## Card item representing a foliage preset in the Foliage Library grid.

signal card_selected(card: TerrainFoliageCard)
signal card_double_clicked(card: TerrainFoliageCard)

var foliage_layer: SimpleTerrainFoliageLayer = null
var preview_texture: Texture2D = null

@onready var thumbnail: TextureRect = %Thumbnail
@onready var title_label: Label = %TitleLabel
@onready var sub_label: Label = %SubLabel


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func setup(p_layer: SimpleTerrainFoliageLayer, p_preview: Texture2D = null) -> void:
	foliage_layer = p_layer
	preview_texture = p_preview
	if is_node_ready():
		_update_display()


const FALLBACK_ICON: Texture2D = preload("res://addons/simple_terrain/icons/foliage_library.svg")


func _update_display() -> void:
	if foliage_layer == null:
		return
	var mesh_name: String = "QuadMesh"
	if not foliage_layer.source_scene_path.is_empty():
		mesh_name = foliage_layer.source_scene_path.get_file()
	elif foliage_layer.mesh != null and not foliage_layer.mesh.resource_path.is_empty():
		mesh_name = foliage_layer.mesh.resource_path.get_file()
	elif foliage_layer.mesh != null:
		mesh_name = foliage_layer.mesh.get_class()

	if title_label != null:
		title_label.text = foliage_layer.name
		title_label.tooltip_text = foliage_layer.name
	if sub_label != null:
		sub_label.text = mesh_name
		sub_label.tooltip_text = mesh_name

	tooltip_text = "%s\nMesh: %s\nDensity: %.1f | Spacing: %.2fm\n(Click to select, Double-click to add to terrain)" % [
		foliage_layer.name,
		mesh_name,
		foliage_layer.density,
		foliage_layer.min_spacing
	]

	if thumbnail != null:
		if preview_texture != null:
			thumbnail.texture = preview_texture
			thumbnail.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			thumbnail.texture = FALLBACK_ICON
			thumbnail.modulate = Color(0.55, 0.68, 0.85, 0.6)



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			card_double_clicked.emit(self)


func _on_pressed() -> void:
	card_selected.emit(self)
