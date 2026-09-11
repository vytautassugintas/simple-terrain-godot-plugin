@tool
class_name TerrainActiveLayerRow
extends PanelContainer

## List row representing an active foliage layer on the current terrain.

signal selected(layer_index: int)
signal visibility_toggled(layer_index: int, is_visible: bool)
signal delete_requested(layer_index: int)

const ICON_VIS_ON: Texture2D = preload("res://addons/simple_terrain/icons/visibility_visible.svg")
const ICON_VIS_OFF: Texture2D = preload("res://addons/simple_terrain/icons/visibility_hidden.svg")
const ICON_DELETE: Texture2D = preload("res://addons/simple_terrain/icons/foliage_clear.svg")

var layer_index: int = -1
var is_active: bool = false:
	set(val):
		is_active = val
		_update_active_style()

@onready var select_btn: Button = %SelectBtn
@onready var count_label: Label = %CountLabel
@onready var vis_btn: Button = %VisBtn
@onready var delete_btn: Button = %DeleteBtn


func _ready() -> void:
	if select_btn != null:
		select_btn.pressed.connect(_on_select_pressed)
	if vis_btn != null:
		vis_btn.pressed.connect(_on_vis_pressed)
	if delete_btn != null:
		delete_btn.icon = ICON_DELETE
		delete_btn.pressed.connect(_on_delete_pressed)
	_update_active_style()


func setup(idx: int, layer_name: String, instance_count: int, layer_visible: bool, active: bool) -> void:
	layer_index = idx
	is_active = active
	if is_node_ready():
		select_btn.text = " %d. %s" % [idx + 1, layer_name]
		count_label.text = str(instance_count)
		vis_btn.text = ""
		vis_btn.icon = ICON_VIS_ON if layer_visible else ICON_VIS_OFF
		vis_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if layer_visible else Color(0.6, 0.6, 0.6, 0.6)
		delete_btn.text = ""
		delete_btn.icon = ICON_DELETE
		_update_active_style()


@export var normal_style: StyleBox = null
@export var active_style: StyleBox = null


func _update_active_style() -> void:
	if select_btn == null:
		return
	if is_active:
		if active_style != null:
			add_theme_stylebox_override("panel", active_style)
		select_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		if normal_style != null:
			add_theme_stylebox_override("panel", normal_style)
		select_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94, 0.9))


func _on_select_pressed() -> void:
	selected.emit(layer_index)


func _on_vis_pressed() -> void:
	var currently_vis: bool = (vis_btn.icon == ICON_VIS_ON)
	var new_vis: bool = not currently_vis
	vis_btn.icon = ICON_VIS_ON if new_vis else ICON_VIS_OFF
	vis_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if new_vis else Color(0.6, 0.6, 0.6, 0.6)
	visibility_toggled.emit(layer_index, new_vis)


func _on_delete_pressed() -> void:
	delete_requested.emit(layer_index)

