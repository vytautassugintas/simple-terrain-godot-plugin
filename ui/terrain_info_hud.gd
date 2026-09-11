@tool
class_name TerrainInfoHud
extends PanelContainer

## Live overlay HUD for 3D viewport displaying real-time cursor elevation, slope, and tool info.

signal close_requested()
signal panel_moved(new_position: Vector2)

var _is_dragging_panel: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@onready var title_bar: HBoxContainer = %TitleBar
@onready var close_btn: Button = %CloseBtn
@onready var coord_val: Label = %CoordVal
@onready var height_val: Label = %HeightVal
@onready var slope_val: Label = %SlopeVal
@onready var tool_val: Label = %ToolVal
@onready var axis_lock_val: Label = %AxisLockVal


func _ready() -> void:
	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)
	if title_bar != null:
		title_bar.gui_input.connect(_on_title_bar_gui_input)


func update_info(local_pos: Vector3, normal: Vector3, tool_str: String, axis_lock_str: String, has_hit: bool) -> void:
	if not has_hit:
		coord_val.text = "--, --"
		height_val.text = "--"
		slope_val.text = "--"
		tool_val.text = tool_str
		axis_lock_val.text = axis_lock_str
		return

	coord_val.text = "X: %+.1fm, Z: %+.1fm" % [local_pos.x, local_pos.z]
	height_val.text = "%+.2f m" % local_pos.y

	# Calculate slope angle against UP vector
	var norm: Vector3 = normal.normalized()
	var dot_up: float = clampf(norm.dot(Vector3.UP), -1.0, 1.0)
	var slope_deg: float = rad_to_deg(acos(dot_up))
	slope_val.text = "%.1f°" % slope_deg

	tool_val.text = tool_str
	axis_lock_val.text = axis_lock_str

	if axis_lock_str != "None":
		axis_lock_val.modulate = Color(1.0, 0.85, 0.3)
	else:
		axis_lock_val.modulate = Color(0.7, 0.7, 0.75)


func _on_close_pressed() -> void:
	close_requested.emit()
	hide()


func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging_panel = true
				_drag_offset = mb.global_position - global_position
			else:
				_is_dragging_panel = false
	elif event is InputEventMouseMotion and _is_dragging_panel:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var new_pos: Vector2 = mm.global_position - _drag_offset
		var vp_sz: Vector2 = get_viewport_rect().size
		new_pos.x = clampf(new_pos.x, 10.0, maxf(10.0, vp_sz.x - size.x - 10.0))
		new_pos.y = clampf(new_pos.y, 10.0, maxf(10.0, vp_sz.y - size.y - 10.0))
		global_position = new_pos
		panel_moved.emit(new_pos)
