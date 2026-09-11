@tool
class_name TerrainScrubber
extends PanelContainer

## Draggable scrubber control (Slider-SpinBox hybrid) for numeric editor adjustments.
## Supports smooth horizontal mouse drag scrubbing, fine adjustment with Shift,
## and click-to-type input.

signal value_changed(new_value: float)

@export var prefix: String = "":
	set(val):
		prefix = val
		_update_display()

@export var suffix: String = "":
	set(val):
		suffix = val
		_update_display()

@export var min_value: float = 0.0:
	set(val):
		min_value = val
		if value < min_value:
			value = min_value
		_update_display()

@export var max_value: float = 100.0:
	set(val):
		max_value = val
		if value > max_value:
			value = max_value
		_update_display()

@export var step: float = 0.1:
	set(val):
		step = maxf(val, 0.0001)
		_update_display()

@export var value: float = 0.0:
	set(val):
		var clamped: float = clampf(val, min_value, max_value)
		if absf(clamped - value) > 0.00001:
			value = clamped
			_update_display()
			value_changed.emit(value)
		else:
			value = clamped
			_update_display()

@export var drag_speed: float = 0.5
@export var decimals: int = 1:
	set(val):
		decimals = maxi(val, 0)
		_update_display()

var _mouse_down: bool = false
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_val: float = 0.0
var _is_editing: bool = false

@onready var display_label: Label = %DisplayLabel
@onready var value_edit: LineEdit = %ValueEdit


func _ready() -> void:
	custom_minimum_size = Vector2(80, 38)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_display()
	if value_edit != null:
		value_edit.visible = false
		value_edit.text_submitted.connect(_on_text_submitted)
		value_edit.focus_exited.connect(_on_edit_focus_exited)
		value_edit.gui_input.connect(_on_value_edit_gui_input)


func set_value_no_signal(new_val: float) -> void:
	var clamped: float = clampf(new_val, min_value, max_value)
	value = clamped
	_update_display()


func _gui_input(event: InputEvent) -> void:
	if _is_editing:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if value_edit != null and value_edit.has_focus():
					value_edit.release_focus()
				_mouse_down = true
				_is_dragging = false
				_drag_start_pos = mb.global_position
				_drag_start_val = value
				accept_event()
			else:
				if _mouse_down:
					_mouse_down = false
					if not _is_dragging:
						_start_editing()
					_is_dragging = false
					accept_event()

	elif event is InputEventMouseMotion and _mouse_down:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var delta_x: float = mm.global_position.x - _drag_start_pos.x
		if not _is_dragging and absf(delta_x) >= 3.0:
			_is_dragging = true

		if _is_dragging:
			var speed_mod: float = 0.1 if mm.shift_pressed else 1.0
			var step_val: float = step if step > 0.0 else 0.1
			var raw_val: float = _drag_start_val + (delta_x * drag_speed * step_val * speed_mod)
			if mm.ctrl_pressed and step > 0.0:
				raw_val = snappedf(raw_val, step)
			value = clampf(raw_val, min_value, max_value)
			accept_event()


func _start_editing() -> void:
	if value_edit == null or display_label == null:
		return
	_is_editing = true
	display_label.visible = false
	value_edit.visible = true
	var fmt_str: String = "%.*f" % [decimals, value]
	value_edit.text = fmt_str
	value_edit.grab_focus()
	value_edit.select_all()


func _commit_edit() -> void:
	if not _is_editing:
		return
	_is_editing = false
	if value_edit != null and display_label != null:
		var text: String = value_edit.text.strip_edges()
		if text.is_valid_float():
			var parsed: float = text.to_float()
			value = clampf(parsed, min_value, max_value)
		value_edit.visible = false
		value_edit.release_focus()
		display_label.visible = true
		_update_display()


func _cancel_edit() -> void:
	if not _is_editing:
		return
	_is_editing = false
	if value_edit != null and display_label != null:
		value_edit.visible = false
		value_edit.release_focus()
		display_label.visible = true
		_update_display()


func _on_value_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_ESCAPE:
			_cancel_edit()
			accept_event()


func _on_text_submitted(_text: String) -> void:
	_commit_edit()


func _on_edit_focus_exited() -> void:
	_commit_edit()


func _update_display() -> void:
	if display_label == null or not is_instance_valid(display_label):
		return
	var fmt_val: String = "%.*f" % [decimals, value]
	var full_text: String = ""
	if not prefix.is_empty():
		full_text += prefix
	full_text += fmt_val
	if not suffix.is_empty():
		full_text += suffix
	display_label.text = full_text
