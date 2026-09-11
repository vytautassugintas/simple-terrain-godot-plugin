@tool
class_name TerrainPieMenu
extends Control

## Circular radial/pie menu for rapid mode and action selection in 3D viewport.

signal mode_selected(mode: int)
signal action_selected(action_id: String)
signal cancelled()

const RADIUS_INNER: float = 56.0
const RADIUS_OUTER: float = 165.0

const COLOR_BG: Color = Color(0.10, 0.11, 0.15, 0.94)
const COLOR_BORDER: Color = Color(0.32, 0.38, 0.52, 0.90)
const COLOR_HOVER: Color = Color(0.25, 0.48, 0.88, 0.52)
const COLOR_TEXT: Color = Color(0.95, 0.97, 1.0, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.72, 0.78, 0.88, 1.0)

const ICON_VIEW: Texture2D = preload("res://addons/simple_terrain/icons/mode_view.svg")
const ICON_SCULPT: Texture2D = preload("res://addons/simple_terrain/icons/mode_sculpt.svg")
const ICON_PAINT: Texture2D = preload("res://addons/simple_terrain/icons/mode_paint.svg")
const ICON_FOLIAGE: Texture2D = preload("res://addons/simple_terrain/icons/mode_foliage.svg")
const ICON_BRUSH_SHAPE: Texture2D = preload("res://addons/simple_terrain/icons/brush_shape.svg")
const ICON_SLOPE_LIMIT: Texture2D = preload("res://addons/simple_terrain/icons/slope_limit.svg")
const ICON_WIREFRAME: Texture2D = preload("res://addons/simple_terrain/icons/wireframe.svg")
const ICON_HUD: Texture2D = preload("res://addons/simple_terrain/icons/hud_info.svg")

class PieSlice:
	var id: String = ""
	var name: String = ""
	var shortcut: String = ""
	var mode_index: int = -1
	var icon: Texture2D = null
	var angle_start: float = 0.0
	var angle_end: float = 0.0

var _slices: Array[PieSlice] = []
var _hovered_slice_idx: int = -1
var _center: Vector2 = Vector2(180, 180)


func _ready() -> void:
	_setup_slices()
	set_process_input(true)


func _setup_slices() -> void:
	_slices.clear()
	# 8 Slices: 45 degrees each
	var slice_data: Array[Dictionary] = [
		{"id": "mode_view", "name": "View", "shortcut": "V", "mode": 0, "icon": ICON_VIEW, "ang_center": -90.0},
		{"id": "mode_sculpt", "name": "Sculpt", "shortcut": "B", "mode": 1, "icon": ICON_SCULPT, "ang_center": -45.0},
		{"id": "mode_paint", "name": "Paint", "shortcut": "P", "mode": 2, "icon": ICON_PAINT, "ang_center": 0.0},
		{"id": "mode_foliage", "name": "Foliage", "shortcut": "G", "mode": 3, "icon": ICON_FOLIAGE, "ang_center": 45.0},
		{"id": "brush_shape", "name": "Brush Shape", "shortcut": "Alt+B", "mode": -1, "icon": ICON_BRUSH_SHAPE, "ang_center": 90.0},
		{"id": "slope_filter", "name": "Slope Limit", "shortcut": "Alt+S", "mode": -1, "icon": ICON_SLOPE_LIMIT, "ang_center": 135.0},
		{"id": "wireframe", "name": "Wireframe", "shortcut": "Shift+W", "mode": -1, "icon": ICON_WIREFRAME, "ang_center": 180.0},
		{"id": "live_hud", "name": "Live HUD", "shortcut": "H", "mode": -1, "icon": ICON_HUD, "ang_center": 225.0},
	]

	var half_span: float = 22.5 * (PI / 180.0)
	for d: Dictionary in slice_data:
		var s: PieSlice = PieSlice.new()
		s.id = d["id"]
		s.name = d["name"]
		s.shortcut = d["shortcut"]
		s.mode_index = d["mode"]
		s.icon = d["icon"]
		var c_rad: float = float(d["ang_center"]) * (PI / 180.0)
		s.angle_start = c_rad - half_span
		s.angle_end = c_rad + half_span
		_slices.append(s)


func open_at(screen_pos: Vector2) -> void:
	var actual_sz: Vector2 = size
	if actual_sz.x < 360.0 or actual_sz.y < 360.0:
		actual_sz = Vector2(360.0, 360.0)
		size = actual_sz
	var half_sz: Vector2 = actual_sz * 0.5
	var win_sz: Vector2 = get_viewport_rect().size
	var final_pos: Vector2 = screen_pos - half_sz
	if win_sz.x > actual_sz.x and win_sz.y > actual_sz.y:
		final_pos.x = clampf(final_pos.x, 10.0, win_sz.x - actual_sz.x - 10.0)
		final_pos.y = clampf(final_pos.y, 10.0, win_sz.y - actual_sz.y - 10.0)
	global_position = final_pos
	_center = actual_sz * 0.5
	_hovered_slice_idx = -1
	show()
	grab_focus()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_hover(mm.position)
		accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_activate_hovered()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel()
			accept_event()
	elif event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and (ke.keycode == KEY_ESCAPE or ke.keycode == KEY_TAB or ke.keycode == KEY_QUOTELEFT):
			_cancel()
			accept_event()



func _update_hover(local_m: Vector2) -> void:
	var delta: Vector2 = local_m - _center
	var dist: float = delta.length()
	var new_hover: int = -1

	if dist >= RADIUS_INNER and dist <= RADIUS_OUTER + 25.0:
		var angle: float = atan2(delta.y, delta.x)
		for i: int in range(_slices.size()):
			var s: PieSlice = _slices[i]
			var a_start: float = s.angle_start
			var a_end: float = s.angle_end

			var norm_a: float = angle
			var norm_s: float = a_start
			var norm_e: float = a_end
			while norm_s < -PI:
				norm_s += TAU
				norm_e += TAU
			while norm_a < norm_s:
				norm_a += TAU

			if norm_a >= norm_s and norm_a <= norm_e:
				new_hover = i
				break

	if new_hover != _hovered_slice_idx:
		_hovered_slice_idx = new_hover
		queue_redraw()


func _activate_hovered() -> void:
	if _hovered_slice_idx >= 0 and _hovered_slice_idx < _slices.size():
		var s: PieSlice = _slices[_hovered_slice_idx]
		if s.mode_index >= 0:
			mode_selected.emit(s.mode_index)
		else:
			action_selected.emit(s.id)
	hide()


func _cancel() -> void:
	cancelled.emit()
	hide()


func _draw() -> void:
	if not visible:
		return

	# Outer subtle glow / border
	draw_circle(_center, RADIUS_OUTER + 4.0, COLOR_BORDER)
	draw_circle(_center, RADIUS_OUTER, COLOR_BG)

	var font: Font = ThemeDB.fallback_font

	# Draw each slice
	for i: int in range(_slices.size()):
		var s: PieSlice = _slices[i]
		var is_hover: bool = (i == _hovered_slice_idx)

		if is_hover:
			_draw_pie_slice(_center, RADIUS_INNER, RADIUS_OUTER, s.angle_start, s.angle_end, COLOR_HOVER)

		# Draw separator line at angle_start
		var dir_start: Vector2 = Vector2(cos(s.angle_start), sin(s.angle_start))
		draw_line(_center + dir_start * RADIUS_INNER, _center + dir_start * RADIUS_OUTER, COLOR_BORDER, 1.5)

		# Draw icon at slice midpoint
		var mid_angle: float = (s.angle_start + s.angle_end) * 0.5
		var icon_dist: float = 106.0
		var icon_pos: Vector2 = _center + Vector2(cos(mid_angle), sin(mid_angle)) * icon_dist

		if s.icon != null:
			var icon_sz: float = 34.0
			var icon_rect: Rect2 = Rect2(icon_pos - Vector2(icon_sz * 0.5, icon_sz * 0.5), Vector2(icon_sz, icon_sz))
			var col: Color = Color.WHITE if is_hover else COLOR_TEXT_MUTED
			draw_texture_rect(s.icon, icon_rect, false, col)

		# Draw label on slice
		var label_dist: float = 142.0
		var label_pos: Vector2 = _center + Vector2(cos(mid_angle), sin(mid_angle)) * label_dist
		var lbl_font_sz: int = 11
		var txt_size: Vector2 = font.get_string_size(s.name, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_font_sz)
		var txt_col: Color = COLOR_TEXT if is_hover else COLOR_TEXT_MUTED
		draw_string(font, label_pos + Vector2(-txt_size.x * 0.5, txt_size.y * 0.3), s.name, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_font_sz, txt_col)

	# Center inner circle
	draw_circle(_center, RADIUS_INNER, COLOR_BORDER)
	draw_circle(_center, RADIUS_INNER - 2.0, COLOR_BG)

	# Central text for currently hovered slice
	if _hovered_slice_idx >= 0 and _hovered_slice_idx < _slices.size():
		var sel: PieSlice = _slices[_hovered_slice_idx]
		var title_sz: int = 15
		var txt_size: Vector2 = font.get_string_size(sel.name, HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz)
		draw_string(font, _center + Vector2(-txt_size.x * 0.5, 0.0), sel.name, HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz, COLOR_TEXT)
		var sc_size: Vector2 = font.get_string_size(sel.shortcut, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		draw_string(font, _center + Vector2(-sc_size.x * 0.5, 16.0), sel.shortcut, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, COLOR_TEXT_MUTED)
	else:
		var title_sz: int = 13
		var txt_size: Vector2 = font.get_string_size("Select Tool", HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz)
		draw_string(font, _center + Vector2(-txt_size.x * 0.5, 5.0), "Select Tool", HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz, COLOR_TEXT_MUTED)


func _draw_pie_slice(c: Vector2, r_in: float, r_out: float, a1: float, a2: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 16
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var a: float = lerpf(a1, a2, t)
		pts.append(c + Vector2(cos(a), sin(a)) * r_out)
	for i: int in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		var a: float = lerpf(a1, a2, t)
		pts.append(c + Vector2(cos(a), sin(a)) * r_in)
	draw_colored_polygon(pts, col)
