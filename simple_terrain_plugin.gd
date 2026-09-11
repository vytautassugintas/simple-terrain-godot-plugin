@tool
class_name SimpleTerrainPlugin
extends EditorPlugin

## Editor plugin for SimpleTerrain3D: handles 3D viewport sculpting, painting, shortcuts, and toolbar integration.

const TOOLBAR_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_editor_toolbar.tscn")
const HUD_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_info_hud.tscn")
const PIE_MENU_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_pie_menu.tscn")
const ASSET_DOCK_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_asset_dock.tscn")
const ICON_TEXTURE: Texture2D = preload("res://addons/simple_terrain/icon.svg")

enum AxisLockMode { NONE = 0, X = 1, Z = 2 }

var _toolbar: TerrainEditorToolbar
var _current_terrain: SimpleTerrain3D
var _toolbar_added_to_menu: bool = false
var _hud: TerrainInfoHud = null
var _pie_menu: TerrainPieMenu = null
var _hud_visible: bool = true
var _hud_custom_positioned: bool = false

var _asset_dock: TerrainAssetDock = null
var _asset_dock_btn: Button = null

var _axis_lock_mode: AxisLockMode = AxisLockMode.NONE
var _axis_lock_origin: Vector3 = Vector3.ZERO
var _axis_lock_origin_local: Vector3 = Vector3.ZERO
var _axis_lock_mesh: MeshInstance3D = null
var _axis_lock_mat: StandardMaterial3D = null

var _brush_indicator: MeshInstance3D
var _brush_material: StandardMaterial3D
var _brush_inner_indicator: MeshInstance3D
var _brush_inner_material: StandardMaterial3D
var _brush_decal: Decal = null
var _syncing_brush_state: bool = false
var _syncing_slope_limits: bool = false

var _current_mode: int = TerrainEditorToolbar.ToolMode.VIEW
var _is_mouse_dragging: bool = false
var _has_valid_hit: bool = false
var _last_hit_pos: Vector3 = Vector3.ZERO
var _last_hit_normal: Vector3 = Vector3.UP
var _flatten_target_height: float = 0.0
var _last_action_msec: int = 0
var _last_painted_pos: Vector3 = Vector3.ZERO
var _last_paint_msec: int = 0
var _last_sculpt_pos: Vector3 = Vector3.ZERO
var _last_sculpt_msec: int = 0

var _ramp_has_point_a: bool = false
var _ramp_point_a_local: Vector3 = Vector3.ZERO
var _ramp_point_a_world: Vector3 = Vector3.ZERO
var _ramp_has_point_b: bool = false
var _ramp_point_b_local: Vector3 = Vector3.ZERO
var _ramp_point_b_world: Vector3 = Vector3.ZERO
var _ramp_guide_mesh: MeshInstance3D = null
var _ramp_guide_mat: StandardMaterial3D = null

var _drag_start_heights: PackedFloat32Array = PackedFloat32Array()
var _drag_start_image_data: PackedByteArray = PackedByteArray()
var _drag_start_foliage_transforms: Array[Transform3D] = []
var _drag_start_foliage_layer_idx: int = -1

var _selected_foliage_layer_idx: int = -1
var _selected_foliage_instance_idx: int = -1
var _hovered_foliage_layer_idx: int = -1
var _hovered_foliage_instance_idx: int = -1
var _is_dragging_foliage_instance: bool = false
var _drag_start_foliage_instance_transform: Transform3D = Transform3D.IDENTITY
var _is_brush_gesture_active: bool = false
var _brush_gesture_is_strength: bool = false
var _is_rmb_down: bool = false
var _is_mmb_down: bool = false

var _foliage_select_indicator: Node3D = null
var _foliage_select_ring: MeshInstance3D = null
var _foliage_select_box: MeshInstance3D = null
var _foliage_hover_indicator: MeshInstance3D = null


func _enter_tree() -> void:
	_setup_toolbar()
	_setup_asset_dock()
	add_custom_type(
		"SimpleTerrain3D",
		"Node3D",
		preload("res://addons/simple_terrain/simple_terrain_3d.gd"),
		ICON_TEXTURE
	)


func _exit_tree() -> void:
	_is_rmb_down = false
	_is_mmb_down = false
	if _current_terrain != null and is_instance_valid(_current_terrain):
		if _current_terrain.foliage_modified.is_connected(_on_terrain_foliage_modified):
			_current_terrain.foliage_modified.disconnect(_on_terrain_foliage_modified)
	_cleanup_toolbar()
	_cleanup_asset_dock()
	_cleanup_hud()
	_cleanup_pie_menu()
	_cleanup_brush_indicator()
	_cleanup_axis_guide()
	_cleanup_ramp_guide()
	_cleanup_foliage_indicators()
	remove_custom_type("SimpleTerrain3D")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_is_rmb_down = false
		_is_mmb_down = false
		_is_brush_gesture_active = false
		_is_mouse_dragging = false


func _handles(object: Object) -> bool:
	return object is SimpleTerrain3D


func _edit(object: Object) -> void:
	_is_rmb_down = false
	_is_mmb_down = false
	_clear_ramp()
	if _current_terrain != null and is_instance_valid(_current_terrain):
		if _current_terrain.foliage_modified.is_connected(_on_terrain_foliage_modified):
			_current_terrain.foliage_modified.disconnect(_on_terrain_foliage_modified)

	if object is SimpleTerrain3D:
		_current_terrain = object as SimpleTerrain3D
		if not _current_terrain.foliage_modified.is_connected(_on_terrain_foliage_modified):
			_current_terrain.foliage_modified.connect(_on_terrain_foliage_modified)
		if _toolbar != null:
			if _toolbar.has_method("set_terrain"):
				_toolbar.set_terrain(_current_terrain)
			if _toolbar.has_method("set_wireframe_active"):
				_toolbar.set_wireframe_active(_current_terrain.show_wireframe)
			if _toolbar.has_method("set_hud_active"):
				_toolbar.set_hud_active(_hud_visible)
			if _toolbar.has_method("set_axis_lock_state"):
				_toolbar.set_axis_lock_state("None")
			if _toolbar.has_method("set_current_terrain_info"):
				_toolbar.set_current_terrain_info(_current_terrain.get_terrain_size(), _current_terrain.get_resolution())
			if _toolbar.has_method("set_embedded_warning"):
				_toolbar.set_embedded_warning(_current_terrain.is_data_embedded())
			if _toolbar.has_method("set_auto_slope_sculpt_active"):
				_toolbar.set_auto_slope_sculpt_active(_current_terrain.auto_slope_on_sculpt)
			if _toolbar.has_method("update_foliage_layers") and _current_terrain.data != null:
				_toolbar.update_foliage_layers(_current_terrain.data.foliage_layers)
		if _asset_dock != null:
			_asset_dock.set_terrain(_current_terrain)
		if _asset_dock_btn != null:
			_asset_dock_btn.show()
		if _asset_dock != null and is_instance_valid(_asset_dock) and _asset_dock.is_visible_in_tree():
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
				_asset_dock.select_tab(0)
			elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
				_asset_dock.select_tab(1)
		if _hud != null and _hud_visible:
			_position_hud_default()
			_hud.show()
			_update_hud()
	else:
		_current_terrain = null
		_hide_brush_indicator()
		_hide_axis_guide()
		if _hud != null:
			_hud.hide()
		if _pie_menu != null:
			_pie_menu.hide()
		if _toolbar != null:
			if _toolbar.has_method("set_terrain"):
				_toolbar.set_terrain(null)
			if _toolbar.has_method("set_embedded_warning"):
				_toolbar.set_embedded_warning(false)
		if _asset_dock != null:
			_asset_dock.set_terrain(null)
		if _asset_dock_btn != null:
			_asset_dock_btn.hide()
		if _asset_dock != null and is_instance_valid(_asset_dock) and _asset_dock.is_visible_in_tree():
			hide_bottom_panel()


func _make_visible(visible: bool) -> void:
	_is_rmb_down = false
	_is_mmb_down = false
	if _toolbar != null:
		_toolbar.visible = visible
	if _hud != null:
		if visible and _hud_visible:
			_position_hud_default()
		_hud.visible = visible and _hud_visible
	if _pie_menu != null:
		_pie_menu.hide()
	if _asset_dock_btn != null:
		_asset_dock_btn.visible = visible
	if not visible:
		_hide_brush_indicator()
		_hide_axis_guide()
		if _asset_dock != null and is_instance_valid(_asset_dock) and _asset_dock.is_visible_in_tree():
			hide_bottom_panel()
	elif _current_terrain != null:
		if _asset_dock != null and is_instance_valid(_asset_dock) and _asset_dock.is_visible_in_tree():
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
				_asset_dock.select_tab(0)
			elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
				_asset_dock.select_tab(1)



func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if _current_terrain == null or not is_instance_valid(_current_terrain) or not _current_terrain.is_inside_tree():
		_hide_brush_indicator()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Track mouse buttons for viewport navigation (freelook, orbit, pan)
	if event is InputEventMouseButton:
		var mb_nav: InputEventMouseButton = event as InputEventMouseButton
		if mb_nav.button_index == MOUSE_BUTTON_RIGHT:
			_is_rmb_down = mb_nav.pressed
			if not mb_nav.pressed:
				_is_brush_gesture_active = false
				return EditorPlugin.AFTER_GUI_INPUT_PASS
		elif mb_nav.button_index == MOUSE_BUTTON_MIDDLE:
			_is_mmb_down = mb_nav.pressed
			if not mb_nav.pressed:
				_is_brush_gesture_active = false
				return EditorPlugin.AFTER_GUI_INPUT_PASS
		elif mb_nav.button_index == MOUSE_BUTTON_LEFT and mb_nav.pressed:
			_is_rmb_down = false
			_is_mmb_down = false
	elif event is InputEventMouseMotion:
		var mm_nav: InputEventMouseMotion = event as InputEventMouseMotion
		_is_rmb_down = (mm_nav.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		_is_mmb_down = (mm_nav.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_is_rmb_down = true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_is_mmb_down = true

	# If the user is navigating the 3D editor camera with mouse buttons (freelook, orbit, pan),
	# bypass terrain input handling completely so freelook WASD/QE/Shift camera navigation works unimpeded.
	if _is_rmb_down or _is_mmb_down:
		_is_brush_gesture_active = false
		_is_mouse_dragging = false
		_hide_brush_indicator()
		_hide_foliage_indicators()
		_hide_axis_guide()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if _pie_menu != null and _pie_menu.visible:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_pie_menu.hide()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey

		# Never intercept ANY keyboard events when user is navigating with mouse buttons (freelook/orbit)
		if _is_rmb_down or _is_mmb_down:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if not ke.pressed:
			if ke.keycode == KEY_R:
				_is_brush_gesture_active = false
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if ke.echo:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		# Escape key cancels current transient operations without needing Alt
		if ke.keycode == KEY_ESCAPE and not ke.alt_pressed and not ke.ctrl_pressed and not ke.shift_pressed:
			if _pie_menu != null and _pie_menu.visible:
				_pie_menu.hide()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if _axis_lock_mode != AxisLockMode.NONE:
				_set_axis_lock(AxisLockMode.NONE)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if _ramp_has_point_a:
				_clear_ramp()
				_update_hud()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _selected_foliage_instance_idx >= 0:
				_deselect_foliage_instance()
				return EditorPlugin.AFTER_GUI_INPUT_STOP

		# ALL terrain editor keybinds STRICTLY require Alt (Option on macOS) held down.
		# If Alt is not pressed, NEVER consume or intercept any key (WASD, QE, R, V, B, P, G, H, X, Z, C, 1-7, etc.)
		if not ke.alt_pressed:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		# --- Alt-held keybinds below ---
		if ke.keycode == KEY_R and not ke.ctrl_pressed:
			if _current_mode != TerrainEditorToolbar.ToolMode.VIEW:
				_is_brush_gesture_active = true
				_brush_gesture_is_strength = ke.shift_pressed
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif ke.keycode == KEY_BRACKETLEFT:
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _toolbar.get_foliage_submode() == SimpleTerrain3D.FoliageBrushMode.SELECT and _selected_foliage_instance_idx >= 0:
				_rotate_selected_foliage_instance(-15.0)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if ke.shift_pressed:
				_toolbar.adjust_brush_strength(-0.1)
			else:
				_toolbar.adjust_brush_radius(-0.5)
			if _has_valid_hit:
				_update_brush_indicator(_last_hit_pos, _last_hit_normal, ke.shift_pressed, ke.ctrl_pressed)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif ke.keycode == KEY_BRACKETRIGHT:
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _toolbar.get_foliage_submode() == SimpleTerrain3D.FoliageBrushMode.SELECT and _selected_foliage_instance_idx >= 0:
				_rotate_selected_foliage_instance(15.0)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if ke.shift_pressed:
				_toolbar.adjust_brush_strength(0.1)
			else:
				_toolbar.adjust_brush_radius(0.5)
			if _has_valid_hit:
				_update_brush_indicator(_last_hit_pos, _last_hit_normal, ke.shift_pressed, ke.ctrl_pressed)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif (ke.keycode == KEY_DELETE or ke.keycode == KEY_BACKSPACE) and not ke.ctrl_pressed:
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _selected_foliage_instance_idx >= 0:
				_on_foliage_instance_delete_requested(_selected_foliage_layer_idx, _selected_foliage_instance_idx)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif (ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER) and not ke.ctrl_pressed:
			if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT and _toolbar.get_sculpt_submode() == SimpleTerrain3D.SculptMode.RAMP:
				_on_ramp_apply_requested()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("toggle_hud", ke) or (ke.keycode == KEY_H and not ke.shift_pressed and not ke.ctrl_pressed):
			_toggle_hud()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("axis_lock_x", ke) or (ke.keycode == KEY_X and not ke.shift_pressed and not ke.ctrl_pressed):
			if _axis_lock_mode == AxisLockMode.X:
				_set_axis_lock(AxisLockMode.NONE)
			else:
				_set_axis_lock(AxisLockMode.X)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("axis_lock_z", ke) or (ke.keycode == KEY_Z and not ke.shift_pressed and not ke.ctrl_pressed):
			if _axis_lock_mode == AxisLockMode.Z:
				_set_axis_lock(AxisLockMode.NONE)
			else:
				_set_axis_lock(AxisLockMode.Z)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("axis_lock_clear", ke) or (ke.keycode == KEY_C and not ke.shift_pressed and not ke.ctrl_pressed):
			if _axis_lock_mode != AxisLockMode.NONE:
				_set_axis_lock(AxisLockMode.NONE)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("toggle_pie_menu", ke) or ((ke.keycode == KEY_TAB or ke.keycode == KEY_QUOTELEFT) and not ke.ctrl_pressed):
			if _pie_menu != null:
				if _pie_menu.visible:
					_pie_menu.hide()
				else:
					var target_mouse: Vector2 = Vector2.ZERO
					var vp: Viewport = viewport_camera.get_viewport()
					if vp != null and vp.get_parent() is Control:
						var vpc: Control = vp.get_parent() as Control
						target_mouse = vpc.global_position + vp.get_mouse_position()
					elif _pie_menu.get_parent() is Control:
						target_mouse = (_pie_menu.get_parent() as Control).get_global_mouse_position()
					else:
						target_mouse = _pie_menu.get_global_mouse_position()
					_pie_menu.open_at(target_mouse)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("mode_view", ke) or (ke.keycode == KEY_V and not ke.shift_pressed and not ke.ctrl_pressed):
			if _current_mode != TerrainEditorToolbar.ToolMode.VIEW:
				_toolbar.set_mode(TerrainEditorToolbar.ToolMode.VIEW)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("mode_sculpt", ke) or (ke.keycode == KEY_B and not ke.shift_pressed and not ke.ctrl_pressed):
			_toolbar.set_mode(TerrainEditorToolbar.ToolMode.SCULPT)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("mode_paint", ke) or (ke.keycode == KEY_P and not ke.shift_pressed and not ke.ctrl_pressed):
			_toolbar.set_mode(TerrainEditorToolbar.ToolMode.PAINT)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("mode_foliage", ke) or (ke.keycode == KEY_G and not ke.shift_pressed and not ke.ctrl_pressed):
			_toolbar.set_mode(TerrainEditorToolbar.ToolMode.FOLIAGE)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif SimpleTerrainSettings.matches_shortcut("toggle_wireframe", ke) or (ke.keycode == KEY_W and not ke.shift_pressed and not ke.ctrl_pressed):
			if _current_terrain != null:
				var new_state: bool = not _current_terrain.show_wireframe
				_current_terrain.show_wireframe = new_state
				if _toolbar != null:
					_toolbar.set_wireframe_active(new_state)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif _current_mode != TerrainEditorToolbar.ToolMode.VIEW and ke.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7] and not ke.ctrl_pressed:
			var num: int = ke.keycode - KEY_1
			if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
				_toolbar.set_sculpt_submode(num)
				if _has_valid_hit:
					_update_brush_indicator(_last_hit_pos, _last_hit_normal, ke.shift_pressed, ke.ctrl_pressed)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT and num < 2:
				_toolbar.set_paint_submode(num)
				if _has_valid_hit:
					_update_brush_indicator(_last_hit_pos, _last_hit_normal, ke.shift_pressed, ke.ctrl_pressed)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and num < 3:
				_toolbar.set_foliage_submode(num)
				if num == SimpleTerrain3D.FoliageBrushMode.SELECT:
					_hide_brush_indicator()
				elif _has_valid_hit:
					_hide_foliage_hover_indicator()
					_update_brush_indicator(_last_hit_pos, _last_hit_normal, ke.shift_pressed, ke.ctrl_pressed)
				return EditorPlugin.AFTER_GUI_INPUT_STOP

	if _current_mode == TerrainEditorToolbar.ToolMode.VIEW:
		_hide_brush_indicator()
		_hide_foliage_indicators()
		_hide_axis_guide()
		if event is InputEventMouseMotion:
			_update_raycast(viewport_camera, (event as InputEventMouseMotion).position)
			_update_hud()
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion

		# Cancel brush gesture if Alt or R is no longer pressed
		if _is_brush_gesture_active:
			if not mm.alt_pressed or not Input.is_key_pressed(KEY_R):
				_is_brush_gesture_active = false

		if _is_brush_gesture_active and _current_mode != TerrainEditorToolbar.ToolMode.VIEW:
			var delta_x: float = mm.relative.x
			var is_strength: bool = _brush_gesture_is_strength or mm.shift_pressed
			if is_strength:
				_toolbar.adjust_brush_strength(delta_x * 0.01)
			else:
				_toolbar.adjust_brush_radius(delta_x * 0.05)
			if _has_valid_hit:
				_update_brush_indicator(_last_hit_pos, _last_hit_normal, mm.shift_pressed, mm.ctrl_pressed)
			_update_hud()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		# Safety: If LMB is no longer pressed, cancel any drag state that may have been lost outside the viewport
		if _is_mouse_dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_is_mouse_dragging = false
			_commit_undo_action()
			if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
				_current_terrain.update_collision()

		if _is_dragging_foliage_instance and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_is_dragging_foliage_instance = false

		var mouse_pos: Vector2 = mm.position

		if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _toolbar.get_foliage_submode() == SimpleTerrain3D.FoliageBrushMode.SELECT:
			_hide_brush_indicator()
			if _is_dragging_foliage_instance and _selected_foliage_instance_idx >= 0:
				_update_raycast(viewport_camera, mouse_pos)
				if _has_valid_hit:
					var local_pos: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
					var old_xform: Transform3D = _current_terrain.get_foliage_instance_transform(_selected_foliage_layer_idx, _selected_foliage_instance_idx)
					var new_xform: Transform3D = old_xform
					new_xform.origin = local_pos
					if not event.shift_pressed and _selected_foliage_layer_idx < _current_terrain.data.foliage_layers.size():
						var lyr: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[_selected_foliage_layer_idx]
						new_xform.origin.y = _current_terrain.get_height_at_local(local_pos) + (lyr.height_offset if lyr != null else 0.0)
					_current_terrain.set_foliage_instance_transform(_selected_foliage_layer_idx, _selected_foliage_instance_idx, new_xform)
					_update_foliage_selection_indicator()
					var lyr_name: String = _current_terrain.data.foliage_layers[_selected_foliage_layer_idx].name
					_toolbar.set_selected_foliage_instance(_selected_foliage_layer_idx, _selected_foliage_instance_idx, new_xform, lyr_name)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				var ray_orig: Vector3 = viewport_camera.project_ray_origin(mouse_pos)
				var ray_d: Vector3 = viewport_camera.project_ray_normal(mouse_pos)
				var pick: Dictionary = _current_terrain.find_closest_foliage_instance(_toolbar.get_foliage_layer_index(), ray_orig, ray_d)
				if pick["instance_index"] >= 0:
					_update_foliage_hover_indicator(pick["layer_index"], pick["instance_index"])
				else:
					_hide_foliage_hover_indicator()
				return EditorPlugin.AFTER_GUI_INPUT_PASS

		_hide_foliage_hover_indicator()
		_update_raycast(viewport_camera, mouse_pos)

		if _has_valid_hit:
			if _axis_lock_mode != AxisLockMode.NONE and _current_terrain != null:
				var loc: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
				if _axis_lock_mode == AxisLockMode.X:
					loc.z = _axis_lock_origin_local.z
				elif _axis_lock_mode == AxisLockMode.Z:
					loc.x = _axis_lock_origin_local.x
				loc.y = _current_terrain.get_height_at_local(loc)
				_last_hit_pos = _current_terrain.global_transform * loc
				_last_hit_normal = _current_terrain.get_normal_at_local(loc.x, loc.z)

			_update_brush_indicator(_last_hit_pos, _last_hit_normal, event.shift_pressed, event.ctrl_pressed)
			_update_axis_guide()
			if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT and _toolbar.get_sculpt_submode() == SimpleTerrain3D.SculptMode.RAMP:
				if _ramp_has_point_a and not _ramp_has_point_b:
					_update_ramp_guide(_last_hit_pos)

		_update_hud()

		if _is_mouse_dragging and _has_valid_hit:
			_apply_action(event.shift_pressed, event.ctrl_pressed, false)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _current_mode != TerrainEditorToolbar.ToolMode.VIEW and mb.alt_pressed:
				if mb.shift_pressed:
					var delta_str: float = 0.05 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.05
					_toolbar.adjust_brush_strength(delta_str)
					if _has_valid_hit:
						_update_brush_indicator(_last_hit_pos, _last_hit_normal, mb.shift_pressed, mb.ctrl_pressed)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
				else:
					var delta_rad: float = 0.5 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -0.5
					_toolbar.adjust_brush_radius(delta_rad)
					if _has_valid_hit:
						_update_brush_indicator(_last_hit_pos, _last_hit_normal, mb.shift_pressed, mb.ctrl_pressed)
					return EditorPlugin.AFTER_GUI_INPUT_STOP

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _toolbar.get_foliage_submode() == SimpleTerrain3D.FoliageBrushMode.SELECT:
				if mb.pressed:
					var ray_orig: Vector3 = viewport_camera.project_ray_origin(mb.position)
					var ray_d: Vector3 = viewport_camera.project_ray_normal(mb.position)
					var pick: Dictionary = _current_terrain.find_closest_foliage_instance(_toolbar.get_foliage_layer_index(), ray_orig, ray_d)
					if pick["instance_index"] >= 0:
						_select_foliage_instance(pick["layer_index"], pick["instance_index"])
						_is_dragging_foliage_instance = true
						_drag_start_foliage_instance_transform = _current_terrain.get_foliage_instance_transform(pick["layer_index"], pick["instance_index"])
						return EditorPlugin.AFTER_GUI_INPUT_STOP
					else:
						_deselect_foliage_instance()
						return EditorPlugin.AFTER_GUI_INPUT_PASS
				else:
					if _is_dragging_foliage_instance:
						_is_dragging_foliage_instance = false
						if _selected_foliage_instance_idx >= 0:
							var cur_xform: Transform3D = _current_terrain.get_foliage_instance_transform(_selected_foliage_layer_idx, _selected_foliage_instance_idx)
							if cur_xform != _drag_start_foliage_instance_transform:
								var undo_redo: EditorUndoRedoManager = get_undo_redo()
								undo_redo.create_action("Move Foliage Instance")
								undo_redo.add_do_method(_current_terrain, "set_foliage_instance_transform", _selected_foliage_layer_idx, _selected_foliage_instance_idx, cur_xform)
								undo_redo.add_undo_method(_current_terrain, "set_foliage_instance_transform", _selected_foliage_layer_idx, _selected_foliage_instance_idx, _drag_start_foliage_instance_transform)
								undo_redo.commit_action(false)
						return EditorPlugin.AFTER_GUI_INPUT_STOP

			if mb.pressed:
				var mouse_pos: Vector2 = mb.position
				_update_raycast(viewport_camera, mouse_pos)
				if _has_valid_hit:
					if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT and _toolbar.get_sculpt_submode() == SimpleTerrain3D.SculptMode.RAMP:
						if not _ramp_has_point_a:
							_ramp_has_point_a = true
							_ramp_point_a_world = _last_hit_pos
							_ramp_point_a_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
							_ramp_has_point_b = false
							_update_ramp_guide(_last_hit_pos)
							_update_hud()
							return EditorPlugin.AFTER_GUI_INPUT_STOP
						elif not _ramp_has_point_b:
							_ramp_has_point_b = true
							_ramp_point_b_world = _last_hit_pos
							_ramp_point_b_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
							_update_ramp_guide(_ramp_point_b_world)
							_update_hud()
							return EditorPlugin.AFTER_GUI_INPUT_STOP
						else:
							_ramp_has_point_a = true
							_ramp_point_a_world = _last_hit_pos
							_ramp_point_a_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
							_ramp_has_point_b = false
							_update_ramp_guide(_last_hit_pos)
							_update_hud()
							return EditorPlugin.AFTER_GUI_INPUT_STOP

					var is_flatten: bool = _current_mode == TerrainEditorToolbar.ToolMode.SCULPT and _toolbar.get_sculpt_submode() == SimpleTerrain3D.SculptMode.FLATTEN
					if _toolbar.is_picking_height or (is_flatten and mb.alt_pressed):
						var local_pos: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
						var h: float = _current_terrain.get_height_at_local(local_pos)
						_toolbar.set_flatten_target_height(h)
						print("[SimpleTerrain] Sampled height: %.2f m" % h)
						return EditorPlugin.AFTER_GUI_INPUT_STOP

					_is_mouse_dragging = true
					_snapshot_undo_state()
					_on_drag_start()
					_apply_action(mb.shift_pressed, mb.ctrl_pressed, true)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				if _is_mouse_dragging:
					_is_mouse_dragging = false
					_commit_undo_action()
					if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
						_current_terrain.update_collision()
					return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _setup_toolbar() -> void:
	if _toolbar == null:
		_toolbar = TOOLBAR_SCENE.instantiate() as TerrainEditorToolbar
		var node_3d_editor: Control = _get_node_3d_editor()
		if node_3d_editor != null:
			node_3d_editor.add_child(_toolbar)
			# Place on its own dedicated row directly beneath Godot's top 3D toolbar (child 0: toolbar_margin)
			node_3d_editor.move_child(_toolbar, 1)
			_toolbar_added_to_menu = false
		else:
			add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
			_toolbar_added_to_menu = true
		_toolbar.hide()

		_toolbar.mode_changed.connect(_on_mode_changed)
		_toolbar.create_terrain_requested.connect(_on_create_terrain_requested)
		_toolbar.resize_terrain_requested.connect(_on_resize_terrain_requested)
		_toolbar.generate_noise_requested.connect(_on_generate_noise_requested)
		_toolbar.flatten_all_requested.connect(_on_flatten_all_requested)
		_toolbar.clear_texture_requested.connect(_on_clear_texture_requested)
		_toolbar.save_mesh_requested.connect(_on_save_mesh_requested)
		_toolbar.export_gltf_requested.connect(_on_export_gltf_requested)
		_toolbar.save_texture_requested.connect(_on_save_texture_requested)
		_toolbar.save_data_requested.connect(_on_save_data_requested)
		_toolbar.wireframe_toggled.connect(_on_wireframe_toggled)
		_toolbar.auto_slope_sculpt_toggled.connect(_on_auto_slope_sculpt_toggled)
		_toolbar.apply_slope_requested.connect(_on_apply_slope_requested)
		_toolbar.foliage_add_layer_requested.connect(_on_foliage_add_layer_requested)
		_toolbar.foliage_delete_layer_requested.connect(_on_foliage_delete_layer_requested)
		_toolbar.foliage_clear_layer_requested.connect(_on_foliage_clear_layer_requested)
		_toolbar.foliage_instance_transform_changed.connect(_on_foliage_instance_transform_changed)
		_toolbar.foliage_instance_align_requested.connect(_on_foliage_instance_align_requested)
		_toolbar.foliage_instance_delete_requested.connect(_on_foliage_instance_delete_requested)
		_toolbar.foliage_instance_deselect_requested.connect(_deselect_foliage_instance)
		_toolbar.foliage_settings_changed.connect(_on_toolbar_foliage_settings_changed)
		_toolbar.hud_toggled.connect(_on_hud_toggled)
		_toolbar.axis_lock_cycle_requested.connect(_cycle_axis_lock)
		_toolbar.ramp_apply_requested.connect(_on_ramp_apply_requested)
		_toolbar.ramp_clear_requested.connect(_on_ramp_clear_requested)
		_toolbar.brush_shape_changed.connect(_on_toolbar_brush_shape_changed)
		_toolbar.slope_limits_changed.connect(_on_toolbar_slope_limits_changed)
		_toolbar.open_asset_dock_requested.connect(_on_open_asset_dock_requested)
		_toolbar.close_asset_dock_requested.connect(_on_dock_close_requested)

		if node_3d_editor != null:
			if _hud == null:
				_hud = HUD_SCENE.instantiate() as TerrainInfoHud
				_hud.top_level = true
				node_3d_editor.add_child(_hud)
				_hud.close_requested.connect(_on_hud_close_requested)
				if _hud.has_signal("panel_moved"):
					_hud.panel_moved.connect(_on_hud_panel_moved)
				_position_hud_default()
				_hud.hide()

			if _pie_menu == null:
				_pie_menu = PIE_MENU_SCENE.instantiate() as TerrainPieMenu
				_pie_menu.top_level = true
				node_3d_editor.add_child(_pie_menu)
				_pie_menu.mode_selected.connect(_on_pie_menu_mode_selected)
				_pie_menu.action_selected.connect(_on_pie_menu_action_selected)
				_pie_menu.hide()


func _cleanup_toolbar() -> void:
	if _toolbar != null:
		if _toolbar_added_to_menu:
			remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
		elif _toolbar.get_parent() != null:
			_toolbar.get_parent().remove_child(_toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _get_node_3d_editor() -> Control:
	var main_screen: Control = EditorInterface.get_editor_main_screen()
	if main_screen != null:
		for child in main_screen.get_children():
			if child.is_class("Node3DEditor"):
				return child as Control

	var vp: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if vp != null:
		var curr: Node = vp
		while curr != null:
			if curr.is_class("Node3DEditor"):
				return curr as Control
			curr = curr.get_parent()

	return null


func _cleanup_hud() -> void:
	if _hud != null:
		if _hud.get_parent() != null:
			_hud.get_parent().remove_child(_hud)
		_hud.queue_free()
		_hud = null


func _cleanup_pie_menu() -> void:
	if _pie_menu != null:
		if _pie_menu.get_parent() != null:
			_pie_menu.get_parent().remove_child(_pie_menu)
		_pie_menu.queue_free()
		_pie_menu = null


func _setup_asset_dock() -> void:
	if _asset_dock == null:
		_asset_dock = ASSET_DOCK_SCENE.instantiate() as TerrainAssetDock
		_asset_dock_btn = add_control_to_bottom_panel(_asset_dock, "Terrain Palette")
		if _asset_dock_btn != null:
			_asset_dock_btn.hide()
		_asset_dock.foliage_layer_selected.connect(_on_dock_foliage_layer_selected)
		_asset_dock.foliage_layer_add_requested.connect(_on_foliage_add_layer_requested)
		_asset_dock.foliage_layer_delete_requested.connect(_on_foliage_delete_layer_requested)
		_asset_dock.foliage_layer_clear_requested.connect(_on_foliage_clear_layer_requested)
		_asset_dock.foliage_layer_visibility_changed.connect(_on_dock_foliage_visibility_changed)
		_asset_dock.foliage_settings_changed.connect(_on_dock_foliage_settings_changed)
		_asset_dock.pattern_selected.connect(_on_dock_pattern_selected)
		_asset_dock.pattern_settings_changed.connect(_on_dock_pattern_settings_changed)
		_asset_dock.brush_shape_selected.connect(_on_dock_brush_shape_selected)
		_asset_dock.slope_limits_changed.connect(_on_dock_slope_limits_changed)
		_asset_dock.dock_close_requested.connect(_on_dock_close_requested)
		_asset_dock.visibility_changed.connect(_on_asset_dock_visibility_changed)


func _cleanup_asset_dock() -> void:
	if _asset_dock != null:
		remove_control_from_bottom_panel(_asset_dock)
		_asset_dock.queue_free()
		_asset_dock = null
		_asset_dock_btn = null


func _on_open_asset_dock_requested(tab_idx: int) -> void:
	if _asset_dock != null and is_instance_valid(_asset_dock):
		if _asset_dock_btn != null and is_instance_valid(_asset_dock_btn) and not _asset_dock_btn.visible:
			_asset_dock_btn.show()
		_asset_dock.select_tab(tab_idx)
		make_bottom_panel_item_visible(_asset_dock)
		if _toolbar != null and _toolbar.has_method("set_asset_dock_active"):
			_toolbar.set_asset_dock_active(true)


func _on_asset_dock_visibility_changed() -> void:
	if _toolbar != null and _toolbar.has_method("set_asset_dock_active") and _asset_dock != null and is_instance_valid(_asset_dock):
		_toolbar.set_asset_dock_active(_asset_dock.is_visible_in_tree())


func _on_dock_foliage_layer_selected(idx: int) -> void:
	if _toolbar != null:
		_toolbar.set_mode(TerrainEditorToolbar.ToolMode.FOLIAGE)
		_toolbar.set_foliage_submode(SimpleTerrain3D.FoliageBrushMode.PAINT)
		_toolbar.set_foliage_layer_index(idx)


func _on_toolbar_foliage_settings_changed(
	_submode: int,
	layer_idx: int,
	_radius: float,
	_density: float,
	_min_spacing: float,
	_min_scale: float,
	_max_scale: float,
	_align_norm: float,
	_max_slope: float,
	_height_off: float,
	_rand_yaw: bool,
	_rand_tilt: float
) -> void:
	if _asset_dock != null and _current_terrain != null and layer_idx >= 0:
		if _asset_dock.selected_foliage_layer_idx != layer_idx:
			_asset_dock.select_active_layer(layer_idx)
		else:
			_asset_dock._update_layer_inspector()


func _on_dock_foliage_visibility_changed(idx: int, is_vis: bool) -> void:
	if _current_terrain != null:
		_current_terrain.set_foliage_layer_visible(idx, is_vis)


func _on_dock_foliage_settings_changed(idx: int, _layer: SimpleTerrainFoliageLayer) -> void:
	if _toolbar != null and _current_terrain != null and _current_terrain.data != null:
		if _toolbar.get_foliage_layer_index() == idx:
			_toolbar.update_foliage_layers(_current_terrain.data.foliage_layers, idx)


func _on_dock_pattern_selected(img: Image, p_name: String, path: String) -> void:
	if _toolbar != null:
		_toolbar.set_mode(TerrainEditorToolbar.ToolMode.PAINT)
		_toolbar.set_paint_submode(SimpleTerrain3D.PaintMode.TEXTURE)
		_toolbar.set_active_pattern(img, p_name, path)


func _on_dock_pattern_settings_changed(tiling: float, angle: float) -> void:
	if _toolbar != null:
		_toolbar.set_pattern_settings(tiling, angle)


func _on_dock_brush_shape_selected(_img: Image, angle_rad: float, brush_id: String) -> void:
	if _syncing_brush_state:
		return
	_syncing_brush_state = true
	if _toolbar != null:
		_toolbar.select_brush_shape(brush_id, false)
		_toolbar.set_brush_angle(rad_to_deg(angle_rad), false)
	_syncing_brush_state = false


func _on_dock_slope_limits_changed(min_deg: float, max_deg: float) -> void:
	if _syncing_slope_limits:
		return
	_syncing_slope_limits = true
	if _toolbar != null:
		_toolbar.set_slope_limits(min_deg, max_deg, false)
	_syncing_slope_limits = false


func _on_toolbar_brush_shape_changed(_img: Image, _angle_rad: float, brush_id: String) -> void:
	if _syncing_brush_state:
		return
	_syncing_brush_state = true
	if _asset_dock != null and is_instance_valid(_asset_dock):
		_asset_dock.select_brush_by_id(brush_id, false)
	_syncing_brush_state = false


func _on_toolbar_slope_limits_changed(min_deg: float, max_deg: float) -> void:
	if _syncing_slope_limits:
		return
	_syncing_slope_limits = true
	if _asset_dock != null and is_instance_valid(_asset_dock):
		_asset_dock.set_dock_slope_limits(min_deg, max_deg, false)
	_syncing_slope_limits = false


func _on_dock_close_requested() -> void:
	if _asset_dock != null:
		hide_bottom_panel()
		if _toolbar != null and _toolbar.has_method("set_asset_dock_active"):
			_toolbar.set_asset_dock_active(false)


func _on_hud_panel_moved(_new_pos: Vector2) -> void:
	_hud_custom_positioned = true


func _position_hud_default(force: bool = false) -> void:
	if _hud == null:
		return
	if _hud_custom_positioned and not force:
		return
	var vp: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if vp != null and vp.get_parent() is Control:
		var vpc: Control = vp.get_parent() as Control
		var vpc_rect: Rect2 = vpc.get_global_rect()
		var hud_w: float = maxf(_hud.size.x, 320.0)
		if vpc_rect.size.x > 100.0 and vpc_rect.size.y > 100.0:
			_hud.global_position = Vector2(vpc_rect.position.x + vpc_rect.size.x - hud_w - 24.0, vpc_rect.position.y + 36.0)
		else:
			_hud.global_position = Vector2(400.0, 120.0)
	else:
		_hud.global_position = Vector2(400.0, 120.0)


func _toggle_hud() -> void:
	_hud_visible = not _hud_visible
	if _hud != null:
		if _hud_visible:
			_position_hud_default()
		_hud.visible = _hud_visible
	if _toolbar != null:
		_toolbar.set_hud_active(_hud_visible)


func _on_hud_toggled(active: bool) -> void:
	_hud_visible = active
	if _hud != null:
		if _hud_visible:
			_position_hud_default()
		_hud.visible = _hud_visible


func _on_hud_close_requested() -> void:
	_hud_visible = false
	if _toolbar != null:
		_toolbar.set_hud_active(false)


func _update_hud() -> void:
	if _hud == null or not _hud.visible or _current_terrain == null:
		return

	var tool_name: String = _get_current_tool_display_name()
	var lock_name: String = "None"
	if _axis_lock_mode == AxisLockMode.X:
		lock_name = "X-Axis [Locked]"
	elif _axis_lock_mode == AxisLockMode.Z:
		lock_name = "Z-Axis [Locked]"

	if _has_valid_hit:
		var local_pos: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
		_hud.update_info(local_pos, _last_hit_normal, tool_name, lock_name, true)
	else:
		_hud.update_info(Vector3.ZERO, Vector3.UP, tool_name, lock_name, false)


func _get_current_tool_display_name() -> String:
	match _current_mode:
		TerrainEditorToolbar.ToolMode.VIEW:
			return "View (Inspect)"
		TerrainEditorToolbar.ToolMode.SCULPT:
			var sub: int = _toolbar.get_sculpt_submode()
			match sub:
				SimpleTerrain3D.SculptMode.RAISE:
					return "Sculpt: Raise (1)"
				SimpleTerrain3D.SculptMode.LOWER:
					return "Sculpt: Lower (2)"
				SimpleTerrain3D.SculptMode.SMOOTH:
					return "Sculpt: Smooth (3)"
				SimpleTerrain3D.SculptMode.FLATTEN:
					return "Sculpt: Flatten (4) [H: %.1fm]" % _flatten_target_height
				SimpleTerrain3D.SculptMode.NOISE:
					return "Sculpt: Noise (5)"
				SimpleTerrain3D.SculptMode.TERRACE:
					return "Sculpt: Terrace (6) [Step: %.1fm]" % _toolbar.get_terrace_step()
				SimpleTerrain3D.SculptMode.RAMP:
					if _ramp_has_point_a and _ramp_has_point_b:
						return "Sculpt: Ramp (7) [Ready - Enter/Apply]"
					elif _ramp_has_point_a:
						return "Sculpt: Ramp (7) [Click Point B]"
					else:
						return "Sculpt: Ramp (7) [Click Point A]"
				_:
					return "Sculpt"
		TerrainEditorToolbar.ToolMode.PAINT:
			var sub: int = _toolbar.get_paint_submode()
			if sub == SimpleTerrain3D.PaintMode.COLOR:
				return "Paint: Color"
			else:
				return "Paint: Stamp Pattern"
		TerrainEditorToolbar.ToolMode.FOLIAGE:
			var sub: int = _toolbar.get_foliage_submode()
			var l_idx: int = _toolbar.get_foliage_layer_index()
			var l_name: String = "Layer %d" % l_idx
			if _current_terrain != null and _current_terrain.data != null and l_idx >= 0 and l_idx < _current_terrain.data.foliage_layers.size():
				l_name = _current_terrain.data.foliage_layers[l_idx].name
			match sub:
				SimpleTerrain3D.FoliageBrushMode.PAINT:
					return "Foliage: Paint [%s]" % l_name
				SimpleTerrain3D.FoliageBrushMode.ERASE:
					return "Foliage: Erase [%s]" % l_name
				SimpleTerrain3D.FoliageBrushMode.SELECT:
					return "Foliage: Select / Move"
				_:
					return "Foliage"
		_:
			return "Unknown"


func _on_pie_menu_mode_selected(mode: int) -> void:
	if _toolbar != null:
		_toolbar.set_mode(mode as TerrainEditorToolbar.ToolMode)


func _on_pie_menu_action_selected(action_id: String) -> void:
	match action_id:
		"wireframe":
			if _current_terrain != null:
				var new_state: bool = not _current_terrain.show_wireframe
				_current_terrain.show_wireframe = new_state
				if _toolbar != null:
					_toolbar.set_wireframe_active(new_state)
		"live_hud":
			_toggle_hud()
		"brush_shape":
			if _toolbar != null:
				_toolbar._open_brush_flyout()
		"slope_filter":
			if _toolbar != null:
				_toolbar._open_slope_limit_popup(_toolbar.slope_limit_btn)


func _cycle_axis_lock() -> void:
	match _axis_lock_mode:
		AxisLockMode.NONE:
			_set_axis_lock(AxisLockMode.X)
		AxisLockMode.X:
			_set_axis_lock(AxisLockMode.Z)
		AxisLockMode.Z:
			_set_axis_lock(AxisLockMode.NONE)


func _set_axis_lock(mode: AxisLockMode) -> void:
	_axis_lock_mode = mode
	if _current_terrain != null and _has_valid_hit:
		_axis_lock_origin = _last_hit_pos
		_axis_lock_origin_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos

	var lock_str: String = "None"
	if _axis_lock_mode == AxisLockMode.X:
		lock_str = "X-Axis"
	elif _axis_lock_mode == AxisLockMode.Z:
		lock_str = "Z-Axis"

	if _toolbar != null:
		_toolbar.set_axis_lock_state(lock_str)

	_update_axis_guide()
	_update_hud()


func _ensure_axis_guide() -> void:
	if _axis_lock_mesh == null:
		_axis_lock_mesh = MeshInstance3D.new()
		_axis_lock_mesh.name = "TerrainAxisLockGuide"
		_axis_lock_mesh.top_level = true
		_axis_lock_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 1000.0
		_axis_lock_mesh.mesh = cyl

		_axis_lock_mat = StandardMaterial3D.new()
		_axis_lock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_axis_lock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_axis_lock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_axis_lock_mat.albedo_color = Color(1.0, 0.25, 0.25, 0.85)
		_axis_lock_mesh.material_override = _axis_lock_mat


func _cleanup_axis_guide() -> void:
	if _axis_lock_mesh != null:
		if _axis_lock_mesh.get_parent() != null:
			_axis_lock_mesh.get_parent().remove_child(_axis_lock_mesh)
		_axis_lock_mesh.queue_free()
		_axis_lock_mesh = null
		_axis_lock_mat = null


func _hide_axis_guide() -> void:
	if _axis_lock_mesh != null:
		_axis_lock_mesh.hide()


func _update_axis_guide() -> void:
	if _axis_lock_mode == AxisLockMode.NONE or _current_terrain == null:
		_hide_axis_guide()
		return

	_ensure_axis_guide()
	if _axis_lock_mesh == null:
		return

	if _axis_lock_mesh.get_parent() != _current_terrain:
		if _axis_lock_mesh.get_parent() != null:
			_axis_lock_mesh.get_parent().remove_child(_axis_lock_mesh)
		_current_terrain.add_child(_axis_lock_mesh)

	var origin: Vector3 = _axis_lock_origin
	if _axis_lock_origin == Vector3.ZERO and _has_valid_hit:
		origin = _last_hit_pos

	_axis_lock_mesh.global_position = origin + Vector3.UP * 0.08

	if _axis_lock_mode == AxisLockMode.X:
		_axis_lock_mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		if _axis_lock_mat != null:
			_axis_lock_mat.albedo_color = Color(1.0, 0.25, 0.25, 0.85)
	elif _axis_lock_mode == AxisLockMode.Z:
		_axis_lock_mesh.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		if _axis_lock_mat != null:
			_axis_lock_mat.albedo_color = Color(0.25, 0.6, 1.0, 0.85)

	_axis_lock_mesh.show()


func _ensure_brush_indicator() -> void:
	if _brush_indicator == null or not is_instance_valid(_brush_indicator):
		_brush_indicator = MeshInstance3D.new()
		_brush_indicator.name = "TerrainBrushIndicator"
		_brush_indicator.top_level = true
		_brush_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.96
		torus.outer_radius = 1.0
		torus.rings = 36
		torus.ring_segments = 4
		_brush_indicator.mesh = torus

		_brush_material = StandardMaterial3D.new()
		_brush_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_brush_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_brush_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brush_material.albedo_color = Color(0.2, 1.0, 0.4, 0.85)
		_brush_indicator.material_override = _brush_material

	if _brush_inner_indicator == null or not is_instance_valid(_brush_inner_indicator):
		_brush_inner_indicator = MeshInstance3D.new()
		_brush_inner_indicator.name = "TerrainBrushInnerIndicator"
		_brush_inner_indicator.top_level = true
		_brush_inner_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var inner_torus: TorusMesh = TorusMesh.new()
		inner_torus.inner_radius = 0.95
		inner_torus.outer_radius = 1.0
		inner_torus.rings = 28
		inner_torus.ring_segments = 4
		_brush_inner_indicator.mesh = inner_torus

		_brush_inner_material = StandardMaterial3D.new()
		_brush_inner_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_brush_inner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_brush_inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brush_inner_material.albedo_color = Color(0.2, 1.0, 0.4, 0.45)
		_brush_inner_indicator.material_override = _brush_inner_material

	if _brush_decal == null or not is_instance_valid(_brush_decal):
		_brush_decal = Decal.new()
		_brush_decal.name = "TerrainBrushDecal"
		_brush_decal.top_level = true
		_brush_decal.normal_fade = 0.0


func _cleanup_brush_indicator() -> void:
	if _brush_indicator != null and is_instance_valid(_brush_indicator):
		if _brush_indicator.get_parent() != null:
			_brush_indicator.get_parent().remove_child(_brush_indicator)
		_brush_indicator.queue_free()
	_brush_indicator = null
	_brush_material = null

	if _brush_inner_indicator != null and is_instance_valid(_brush_inner_indicator):
		if _brush_inner_indicator.get_parent() != null:
			_brush_inner_indicator.get_parent().remove_child(_brush_inner_indicator)
		_brush_inner_indicator.queue_free()
	_brush_inner_indicator = null
	_brush_inner_material = null

	if _brush_decal != null and is_instance_valid(_brush_decal):
		if _brush_decal.get_parent() != null:
			_brush_decal.get_parent().remove_child(_brush_decal)
		_brush_decal.queue_free()
	_brush_decal = null


func _hide_brush_indicator() -> void:
	if _brush_indicator != null and is_instance_valid(_brush_indicator):
		_brush_indicator.hide()
	if _brush_inner_indicator != null and is_instance_valid(_brush_inner_indicator):
		_brush_inner_indicator.hide()
	if _brush_decal != null and is_instance_valid(_brush_decal):
		_brush_decal.hide()


func _update_brush_indicator(hit_pos: Vector3, hit_normal: Vector3, shift_pressed: bool = false, ctrl_pressed: bool = false) -> void:
	_ensure_brush_indicator()
	if _brush_indicator == null or _current_terrain == null:
		return

	if _brush_indicator.get_parent() != _current_terrain:
		if _brush_indicator.get_parent() != null:
			_brush_indicator.get_parent().remove_child(_brush_indicator)
		_current_terrain.add_child(_brush_indicator)

	if _brush_inner_indicator.get_parent() != _current_terrain:
		if _brush_inner_indicator.get_parent() != null:
			_brush_inner_indicator.get_parent().remove_child(_brush_inner_indicator)
		_current_terrain.add_child(_brush_inner_indicator)

	if _brush_decal != null and is_instance_valid(_brush_decal) and _brush_decal.get_parent() != _current_terrain:
		if _brush_decal.get_parent() != null:
			_brush_decal.get_parent().remove_child(_brush_decal)
		_current_terrain.add_child(_brush_decal)

	var radius: float = 5.0
	var falloff: float = 0.5
	var brush_color: Color = Color(0.2, 1.0, 0.4, 0.85)

	if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
		radius = _toolbar.get_sculpt_radius()
		falloff = _toolbar.get_sculpt_falloff()
		var submode: int = _toolbar.get_sculpt_submode()
		if shift_pressed:
			if submode == SimpleTerrain3D.SculptMode.RAISE:
				submode = SimpleTerrain3D.SculptMode.LOWER
			elif submode == SimpleTerrain3D.SculptMode.LOWER:
				submode = SimpleTerrain3D.SculptMode.RAISE
		if ctrl_pressed:
			submode = SimpleTerrain3D.SculptMode.SMOOTH

		match submode:
			SimpleTerrain3D.SculptMode.RAISE:
				brush_color = Color(0.2, 1.0, 0.3, 0.85)
			SimpleTerrain3D.SculptMode.LOWER:
				brush_color = Color(1.0, 0.3, 0.2, 0.85)
			SimpleTerrain3D.SculptMode.SMOOTH:
				brush_color = Color(0.2, 0.6, 1.0, 0.85)
			SimpleTerrain3D.SculptMode.FLATTEN:
				brush_color = Color(1.0, 0.75, 0.1, 0.85)
			SimpleTerrain3D.SculptMode.NOISE:
				brush_color = Color(0.8, 0.3, 1.0, 0.85)
			SimpleTerrain3D.SculptMode.TERRACE:
				brush_color = Color(0.2, 0.85, 0.9, 0.85)
			SimpleTerrain3D.SculptMode.RAMP:
				brush_color = Color(1.0, 0.6, 0.1, 0.85)

	elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
		radius = _toolbar.get_paint_radius()
		falloff = _toolbar.get_paint_falloff()
		if _toolbar.get_paint_submode() == SimpleTerrain3D.PaintMode.COLOR:
			brush_color = _toolbar.get_paint_color()
			brush_color.a = 0.85
		else:
			brush_color = Color(0.9, 0.2, 1.0, 0.85)

	elif _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
		radius = _toolbar.get_foliage_radius()
		falloff = 0.2
		var submode: int = _toolbar.get_foliage_submode()
		if shift_pressed:
			submode = SimpleTerrain3D.FoliageBrushMode.ERASE if submode == SimpleTerrain3D.FoliageBrushMode.PAINT else SimpleTerrain3D.FoliageBrushMode.PAINT
		if submode == SimpleTerrain3D.FoliageBrushMode.PAINT:
			brush_color = Color(0.18, 0.85, 0.45, 0.85)
		else:
			brush_color = Color(0.95, 0.35, 0.25, 0.85)

	var inner_ratio: float = 0.5
	var ipreset: int = int(round(falloff))
	if absf(falloff - float(ipreset)) < 0.001 and ipreset >= 0 and ipreset <= 3:
		match ipreset:
			SimpleTerrain3D.FalloffType.SMOOTH:
				inner_ratio = 0.5
			SimpleTerrain3D.FalloffType.LINEAR:
				inner_ratio = 0.15
			SimpleTerrain3D.FalloffType.SPHERICAL:
				inner_ratio = 0.75
			SimpleTerrain3D.FalloffType.FLAT:
				inner_ratio = 0.99
	else:
		inner_ratio = clampf(1.0 - falloff, 0.05, 1.0)

	var inner_radius: float = maxf(radius * inner_ratio, 0.1)

	_brush_indicator.global_position = hit_pos + hit_normal * 0.05
	_brush_indicator.scale = Vector3(radius, 1.0, radius)

	_brush_inner_indicator.global_position = hit_pos + hit_normal * 0.06
	_brush_inner_indicator.scale = Vector3(inner_radius, 1.0, inner_radius)

	var up: Vector3 = hit_normal.normalized()
	if absf(up.dot(Vector3.UP)) < 0.99:
		_brush_indicator.look_at(hit_pos + up, Vector3.UP)
		_brush_indicator.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_brush_inner_indicator.rotation = _brush_indicator.rotation
	else:
		_brush_indicator.rotation = Vector3.ZERO
		_brush_inner_indicator.rotation = Vector3.ZERO

	if _brush_material != null:
		_brush_material.albedo_color = brush_color
	if _brush_inner_material != null:
		var inner_col: Color = brush_color
		inner_col.a = 0.45
		_brush_inner_material.albedo_color = inner_col

	_brush_indicator.show()
	_brush_inner_indicator.show()

	if _brush_decal != null and is_instance_valid(_brush_decal):
		var brush_tex: Texture2D = null
		var brush_ang: float = 0.0
		if _toolbar != null:
			if _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
				brush_tex = _toolbar.get_brush_texture()
				brush_ang = _toolbar.get_brush_angle()
			elif _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
				brush_tex = _toolbar.loaded_mask_texture
				brush_ang = _toolbar.get_sculpt_mask_angle()

		if brush_tex != null:
			if _brush_decal.texture_albedo != brush_tex:
				_brush_decal.texture_albedo = brush_tex
			var target_sz: Vector3 = Vector3(radius * 2.0, maxf(radius * 4.0, 20.0), radius * 2.0)
			if _brush_decal.size != target_sz:
				_brush_decal.size = target_sz
			_brush_decal.global_position = hit_pos
			_brush_decal.rotation = Vector3(0.0, brush_ang, 0.0)
			var decal_col: Color = brush_color
			decal_col.a = 0.65
			if _brush_decal.modulate != decal_col:
				_brush_decal.modulate = decal_col
			_brush_decal.show()
		else:
			_brush_decal.hide()


func _update_raycast(viewport_camera: Camera3D, mouse_pos: Vector2) -> void:
	if _current_terrain == null or not is_instance_valid(_current_terrain):
		_has_valid_hit = false
		_hide_brush_indicator()
		return

	var ray_origin: Vector3 = viewport_camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = viewport_camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = viewport_camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 5000.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var found_hit: bool = false
	var hit_pos: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.UP
	var exclude_rids: Array[RID] = []

	for _step: int in range(8):
		query.exclude = exclude_rids
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.collider
		if collider is Node and (collider == _current_terrain or _current_terrain.is_ancestor_of(collider as Node)):
			hit_pos = hit.position
			hit_normal = hit.normal
			found_hit = true
			break
		elif hit.has("rid"):
			exclude_rids.append(hit.rid)
		else:
			break

	if not found_hit:
		var terrain_plane: Plane = Plane(_current_terrain.global_transform.basis.y.normalized(), _current_terrain.global_position)
		var plane_hit: Variant = terrain_plane.intersects_ray(ray_origin, ray_dir)
		if plane_hit != null:
			var p: Vector3 = plane_hit as Vector3
			var local_p: Vector3 = _current_terrain.global_transform.affine_inverse() * p
			var half_x: float = _current_terrain.get_terrain_size().x * 0.5
			var half_z: float = _current_terrain.get_terrain_size().y * 0.5
			if absf(local_p.x) <= half_x + 5.0 and absf(local_p.z) <= half_z + 5.0:
				local_p.y = _current_terrain.get_height_bilinear(local_p.x, local_p.z)
				hit_pos = _current_terrain.global_transform * local_p
				hit_normal = _current_terrain.get_normal_at_local(local_p.x, local_p.z)
				found_hit = true

	_has_valid_hit = found_hit
	if found_hit:
		_last_hit_pos = hit_pos
		_last_hit_normal = hit_normal
	else:
		_hide_brush_indicator()


func _on_drag_start() -> void:
	_last_action_msec = Time.get_ticks_msec() - 30
	_last_paint_msec = 0
	_last_painted_pos = Vector3.INF
	_last_sculpt_msec = 0
	_last_sculpt_pos = Vector3.INF
	if _current_terrain != null and _has_valid_hit and _axis_lock_mode != AxisLockMode.NONE:
		_axis_lock_origin = _last_hit_pos
		_axis_lock_origin_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
		_update_axis_guide()

	if _current_terrain != null and _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
		var submode: int = _toolbar.get_sculpt_submode()
		if submode == SimpleTerrain3D.SculptMode.FLATTEN:
			var local_pos: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
			if _toolbar.is_picking_height:
				_flatten_target_height = _current_terrain.get_height_at_local(local_pos)
				_toolbar.set_flatten_target_height(_flatten_target_height)
			else:
				var tb_h: float = _toolbar.get_flatten_target_height()
				if tb_h != 0.0:
					_flatten_target_height = tb_h
				else:
					_flatten_target_height = _current_terrain.get_height_at_local(local_pos)
					_toolbar.set_flatten_target_height(_flatten_target_height)


func _apply_action(shift_pressed: bool, ctrl_pressed: bool, force_apply: bool = false) -> void:
	if _current_terrain == null or not _has_valid_hit:
		return

	var now: int = Time.get_ticks_msec()
	var delta: float = float(now - _last_action_msec) / 1000.0
	if delta < 0.016 or delta > 0.1:
		delta = 0.025
	_last_action_msec = now

	var local_pos: Vector3 = _current_terrain.global_transform.affine_inverse() * _last_hit_pos

	if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
		var submode: int = _toolbar.get_sculpt_submode()
		if submode == SimpleTerrain3D.SculptMode.RAMP:
			return

		if shift_pressed:
			if submode == SimpleTerrain3D.SculptMode.RAISE:
				submode = SimpleTerrain3D.SculptMode.LOWER
			elif submode == SimpleTerrain3D.SculptMode.LOWER:
				submode = SimpleTerrain3D.SculptMode.RAISE
		if ctrl_pressed:
			submode = SimpleTerrain3D.SculptMode.SMOOTH

		var radius: float = _toolbar.get_sculpt_radius()
		if not force_apply:
			var spc_pct: float = _toolbar.get_sculpt_spacing()
			var min_step: float = maxf(radius * (spc_pct / 100.0), 0.05)
			var dist: float = _last_sculpt_pos.distance_to(_last_hit_pos)
			var time_diff: int = now - _last_sculpt_msec
			if dist < min_step and time_diff < 40:
				return

		_last_sculpt_pos = _last_hit_pos
		_last_sculpt_msec = now

		var j_pos_pct: float = _toolbar.get_sculpt_jitter_pos() / 100.0
		if j_pos_pct > 0.001:
			var rnd_ang: float = randf() * TAU
			var rnd_r: float = randf() * j_pos_pct * radius
			local_pos.x += cos(rnd_ang) * rnd_r
			local_pos.z += sin(rnd_ang) * rnd_r

		var strength: float = _toolbar.get_sculpt_strength()
		var falloff: float = _toolbar.get_sculpt_falloff()
		var mask_img: Image = _toolbar.get_sculpt_mask_image()
		var mask_ang: float = _toolbar.get_sculpt_mask_angle()
		var j_ang: float = _toolbar.get_sculpt_jitter_angle()
		if j_ang > 0.001:
			mask_ang += deg_to_rad(randf_range(-180.0, 180.0) * (j_ang / 360.0))

		var step_size: float = _toolbar.get_terrace_step()
		var min_slope: float = _toolbar.get_min_slope_deg()
		var max_slope: float = _toolbar.get_max_slope_deg()
		_current_terrain.sculpt(local_pos, radius, strength, falloff, submode, delta, _flatten_target_height, step_size, mask_img, mask_ang, 1.0, min_slope, max_slope)

	elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
		var radius: float = _toolbar.get_paint_radius()
		if not force_apply:
			var spc_pct: float = _toolbar.get_paint_spacing()
			var min_step: float = maxf(radius * (spc_pct / 100.0), 0.05)
			var dist: float = _last_painted_pos.distance_to(_last_hit_pos)
			var time_diff: int = now - _last_paint_msec

			if dist < min_step and time_diff < 40:
				return

		_last_painted_pos = _last_hit_pos
		_last_paint_msec = now

		var j_pos_pct: float = _toolbar.get_paint_jitter_pos() / 100.0
		if j_pos_pct > 0.001:
			var rnd_ang: float = randf() * TAU
			var rnd_r: float = randf() * j_pos_pct * radius
			local_pos.x += cos(rnd_ang) * rnd_r
			local_pos.z += sin(rnd_ang) * rnd_r

		var submode: int = _toolbar.get_paint_submode()
		var strength: float = _toolbar.get_paint_strength()
		var falloff: float = _toolbar.get_paint_falloff()
		var brush_img: Image = _toolbar.get_brush_image()
		var brush_ang: float = _toolbar.get_brush_angle()
		var min_slope: float = _toolbar.get_min_slope_deg()
		var max_slope: float = _toolbar.get_max_slope_deg()

		if submode == SimpleTerrain3D.PaintMode.COLOR:
			var color: Color = _toolbar.get_paint_color()
			_current_terrain.paint_color(local_pos, radius, strength, falloff, color, brush_img, brush_ang, min_slope, max_slope)
		elif submode == SimpleTerrain3D.PaintMode.TEXTURE:
			var stamp_img: Image = _toolbar.loaded_stamp_image
			var tiling: float = _toolbar.get_paint_tiling()
			var angle: float = _toolbar.get_paint_angle()
			var j_ang: float = _toolbar.get_paint_jitter_angle()
			if j_ang > 0.001:
				angle += randf_range(-180.0, 180.0) * (j_ang / 360.0)
			if stamp_img != null and not stamp_img.is_empty():
				_current_terrain.paint_texture(local_pos, radius, strength, falloff, stamp_img, tiling, angle, brush_img, brush_ang, min_slope, max_slope)

	elif _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
		var radius: float = _toolbar.get_foliage_radius()
		var submode: int = _toolbar.get_foliage_submode()
		if shift_pressed:
			submode = SimpleTerrain3D.FoliageBrushMode.ERASE if submode == SimpleTerrain3D.FoliageBrushMode.PAINT else SimpleTerrain3D.FoliageBrushMode.PAINT

		var layer_idx: int = _toolbar.get_foliage_layer_index()
		if _current_terrain.data == null or layer_idx < 0 or layer_idx >= _current_terrain.data.foliage_layers.size():
			return

		var active_lyr: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[layer_idx]
		if active_lyr != null and not active_lyr.visible:
			_current_terrain.set_foliage_layer_visible(layer_idx, true)

		if submode == SimpleTerrain3D.FoliageBrushMode.PAINT:
			if not force_apply:
				var min_step: float = maxf(radius * 0.15, 0.1)
				var dist: float = _last_painted_pos.distance_to(_last_hit_pos)
				var time_diff: int = now - _last_paint_msec
				if dist < min_step and time_diff < 50:
					return

			_last_painted_pos = _last_hit_pos
			_last_paint_msec = now

			var density: float = 12.0
			var min_spacing: float = 0.25
			var align_norm: float = 0.5
			var max_slope: float = 40.0
			var min_scale: float = 0.8
			var max_scale: float = 1.3
			var height_off: float = -0.05
			var rand_yaw: bool = true
			var rand_tilt: float = 5.0

			if _current_terrain.data != null and layer_idx < _current_terrain.data.foliage_layers.size():
				var lyr: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[layer_idx]
				if lyr != null:
					density = lyr.density
					min_spacing = lyr.min_spacing
					align_norm = lyr.align_to_normal
					max_slope = lyr.max_slope_deg
					min_scale = lyr.min_scale
					max_scale = lyr.max_scale
					height_off = lyr.height_offset
					rand_yaw = lyr.random_yaw
					rand_tilt = lyr.random_tilt_deg

			_current_terrain.paint_foliage(
				local_pos,
				radius,
				layer_idx,
				density,
				min_spacing,
				min_scale,
				max_scale,
				align_norm,
				max_slope,
				height_off,
				rand_yaw,
				rand_tilt
			)

		elif submode == SimpleTerrain3D.FoliageBrushMode.ERASE:
			_current_terrain.erase_foliage(local_pos, radius, layer_idx)


func _snapshot_undo_state() -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT:
		_drag_start_heights = _current_terrain.data.height_data.duplicate()
		if _current_terrain.auto_slope_on_sculpt:
			_current_terrain.sync_image_data()
			_drag_start_image_data = _current_terrain.data.image_data.duplicate()
	elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
		_current_terrain.sync_image_data()
		_drag_start_image_data = _current_terrain.data.image_data.duplicate()
	elif _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
		_drag_start_foliage_layer_idx = _toolbar.get_foliage_layer_index()
		_drag_start_foliage_transforms = _current_terrain.get_layer_transforms(_drag_start_foliage_layer_idx)


func _commit_undo_action(action_name: String = "Sculpt Terrain") -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	if _current_mode == TerrainEditorToolbar.ToolMode.SCULPT and _drag_start_heights.size() > 0:
		var new_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()
		var old_heights: PackedFloat32Array = _drag_start_heights
		var has_slope_texture: bool = _current_terrain.auto_slope_on_sculpt and _drag_start_image_data.size() > 0
		var new_img_data: PackedByteArray = PackedByteArray()
		var old_img_data: PackedByteArray = PackedByteArray()
		if has_slope_texture:
			_current_terrain.sync_image_data()
			new_img_data = _current_terrain.data.image_data.duplicate()
			old_img_data = _drag_start_image_data

		undo_redo.create_action(action_name if not action_name.is_empty() else "Sculpt Terrain")
		undo_redo.add_do_property(_current_terrain.data, "height_data", new_heights)
		if has_slope_texture:
			undo_redo.add_do_property(_current_terrain.data, "image_data", new_img_data)
			undo_redo.add_do_method(_current_terrain, "_load_or_create_data")
		undo_redo.add_do_method(_current_terrain, "update_mesh_geometry")
		undo_redo.add_do_method(_current_terrain, "update_collision")

		undo_redo.add_undo_property(_current_terrain.data, "height_data", old_heights)
		if has_slope_texture:
			undo_redo.add_undo_property(_current_terrain.data, "image_data", old_img_data)
			undo_redo.add_undo_method(_current_terrain, "_load_or_create_data")
		undo_redo.add_undo_method(_current_terrain, "update_mesh_geometry")
		undo_redo.add_undo_method(_current_terrain, "update_collision")
		undo_redo.commit_action(false)
		_drag_start_heights = PackedFloat32Array()
		_drag_start_image_data = PackedByteArray()

	elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT and _drag_start_image_data.size() > 0:
		_current_terrain.sync_image_data()
		var new_img_data: PackedByteArray = _current_terrain.data.image_data.duplicate()
		var old_img_data: PackedByteArray = _drag_start_image_data
		undo_redo.create_action("Paint Terrain")
		undo_redo.add_do_property(_current_terrain.data, "image_data", new_img_data)
		undo_redo.add_do_method(_current_terrain, "_load_or_create_data")
		undo_redo.add_undo_property(_current_terrain.data, "image_data", old_img_data)
		undo_redo.add_undo_method(_current_terrain, "_load_or_create_data")
		undo_redo.commit_action(false)
		_drag_start_image_data = PackedByteArray()

	elif _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE and _drag_start_foliage_layer_idx >= 0:
		var l_idx: int = _drag_start_foliage_layer_idx
		var new_xforms: Array[Transform3D] = _current_terrain.get_layer_transforms(l_idx)
		var old_xforms: Array[Transform3D] = _drag_start_foliage_transforms
		if new_xforms.size() != old_xforms.size() or new_xforms != old_xforms:
			var is_erase: bool = (_toolbar.get_foliage_submode() == SimpleTerrain3D.FoliageBrushMode.ERASE)
			var fol_action_name: String = "Erase Foliage" if is_erase else "Scatter Foliage"
			undo_redo.create_action(fol_action_name)
			undo_redo.add_do_method(_current_terrain, "set_layer_transforms", l_idx, new_xforms)
			undo_redo.add_undo_method(_current_terrain, "set_layer_transforms", l_idx, old_xforms)
			undo_redo.commit_action(false)
		_drag_start_foliage_transforms = []
		_drag_start_foliage_layer_idx = -1


func _on_mode_changed(mode: int) -> void:
	_current_mode = mode
	_clear_ramp()
	if _current_mode == TerrainEditorToolbar.ToolMode.VIEW:
		_hide_brush_indicator()
		_hide_foliage_indicators()
	elif _current_mode != TerrainEditorToolbar.ToolMode.FOLIAGE:
		_hide_foliage_indicators()

	if _current_mode == TerrainEditorToolbar.ToolMode.FOLIAGE:
		_on_open_asset_dock_requested(0)
	elif _current_mode == TerrainEditorToolbar.ToolMode.PAINT:
		if _asset_dock != null and is_instance_valid(_asset_dock) and _asset_dock.is_visible_in_tree():
			_asset_dock.select_tab(1)


func _ensure_ramp_guide() -> void:
	if _ramp_guide_mesh == null:
		_ramp_guide_mesh = MeshInstance3D.new()
		_ramp_guide_mesh.name = "TerrainRampGuide"
		_ramp_guide_mesh.top_level = true
		_ramp_guide_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		_ramp_guide_mat = StandardMaterial3D.new()
		_ramp_guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ramp_guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ramp_guide_mat.vertex_color_use_as_albedo = true
		_ramp_guide_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ramp_guide_mesh.material_override = _ramp_guide_mat


func _hide_ramp_guide() -> void:
	if _ramp_guide_mesh != null:
		_ramp_guide_mesh.hide()


func _cleanup_ramp_guide() -> void:
	if _ramp_guide_mesh != null:
		if _ramp_guide_mesh.get_parent() != null:
			_ramp_guide_mesh.get_parent().remove_child(_ramp_guide_mesh)
		_ramp_guide_mesh.queue_free()
		_ramp_guide_mesh = null
		_ramp_guide_mat = null


func _clear_ramp() -> void:
	_ramp_has_point_a = false
	_ramp_has_point_b = false
	_hide_ramp_guide()


func _on_ramp_apply_requested() -> void:
	if _current_terrain == null or not _ramp_has_point_a:
		return
	var b_local: Vector3 = _ramp_point_b_local
	if not _ramp_has_point_b:
		if _has_valid_hit:
			b_local = _current_terrain.global_transform.affine_inverse() * _last_hit_pos
		else:
			return

	var width: float = _toolbar.get_ramp_width()
	var falloff: float = _toolbar.get_ramp_falloff()
	var crown: float = _toolbar.get_ramp_crown()

	_snapshot_undo_state()
	_current_terrain.apply_ramp(_ramp_point_a_local, b_local, width, falloff, crown)
	_commit_undo_action("Apply Terrain Ramp")
	_clear_ramp()
	_update_hud()


func _on_ramp_clear_requested() -> void:
	_clear_ramp()
	_update_hud()


func _update_ramp_guide(b_world: Vector3) -> void:
	if not _ramp_has_point_a or _current_terrain == null:
		_hide_ramp_guide()
		return

	_ensure_ramp_guide()
	if _ramp_guide_mesh.get_parent() != _current_terrain:
		if _ramp_guide_mesh.get_parent() != null:
			_ramp_guide_mesh.get_parent().remove_child(_ramp_guide_mesh)
		_current_terrain.add_child(_ramp_guide_mesh)

	var a_world: Vector3 = _ramp_point_a_world
	var dir_xz: Vector2 = Vector2(b_world.x - a_world.x, b_world.z - a_world.z)
	var len_xz: float = dir_xz.length()
	if len_xz < 0.1:
		_hide_ramp_guide()
		return

	var u_xz: Vector2 = dir_xz / len_xz
	var n_xz: Vector2 = Vector2(-u_xz.y, u_xz.x)
	var half_w: float = _toolbar.get_ramp_width() * 0.5
	var falloff: float = _toolbar.get_ramp_falloff()
	var total_w: float = half_w + falloff

	var lines: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var col_center: Color = Color(1.0, 0.8, 0.1, 0.95)
	var col_edge: Color = Color(0.2, 0.9, 1.0, 0.9)
	var col_falloff: Color = Color(0.6, 0.7, 1.0, 0.45)
	var col_a: Color = Color(0.2, 1.0, 0.4, 1.0)
	var col_b: Color = Color(0.2, 0.6, 1.0, 1.0)

	var y_lift: Vector3 = Vector3.UP * 0.1

	# Centerline
	lines.append(a_world + y_lift)
	colors.append(col_center)
	lines.append(b_world + y_lift)
	colors.append(col_center)

	# Left & Right edges at elevation
	var l_offset: Vector3 = Vector3(n_xz.x * half_w, 0.0, n_xz.y * half_w)
	var r_offset: Vector3 = Vector3(-n_xz.x * half_w, 0.0, -n_xz.y * half_w)

	lines.append(a_world + l_offset + y_lift)
	colors.append(col_edge)
	lines.append(b_world + l_offset + y_lift)
	colors.append(col_edge)

	lines.append(a_world + r_offset + y_lift)
	colors.append(col_edge)
	lines.append(b_world + r_offset + y_lift)
	colors.append(col_edge)

	# Cross rungs along the ramp
	var steps: int = clampi(int(len_xz / 4.0), 3, 20)
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p_mid: Vector3 = a_world.lerp(b_world, t) + y_lift
		lines.append(p_mid + l_offset)
		colors.append(col_edge)
		lines.append(p_mid + r_offset)
		colors.append(col_edge)

	# Outer falloff lines
	if falloff > 0.1:
		var fl_offset: Vector3 = Vector3(n_xz.x * total_w, 0.0, n_xz.y * total_w)
		var fr_offset: Vector3 = Vector3(-n_xz.x * total_w, 0.0, -n_xz.y * total_w)
		lines.append(a_world + fl_offset + y_lift)
		colors.append(col_falloff)
		lines.append(b_world + fl_offset + y_lift)
		colors.append(col_falloff)

		lines.append(a_world + fr_offset + y_lift)
		colors.append(col_falloff)
		lines.append(b_world + fr_offset + y_lift)
		colors.append(col_falloff)

	# Markers at A and B (crosshairs)
	var cross_rad: float = maxf(half_w * 0.4, 0.5)
	lines.append(a_world + Vector3(-cross_rad, 0, 0) + y_lift)
	colors.append(col_a)
	lines.append(a_world + Vector3(cross_rad, 0, 0) + y_lift)
	colors.append(col_a)
	lines.append(a_world + Vector3(0, 0, -cross_rad) + y_lift)
	colors.append(col_a)
	lines.append(a_world + Vector3(0, 0, cross_rad) + y_lift)
	colors.append(col_a)

	lines.append(b_world + Vector3(-cross_rad, 0, 0) + y_lift)
	colors.append(col_b)
	lines.append(b_world + Vector3(cross_rad, 0, 0) + y_lift)
	colors.append(col_b)
	lines.append(b_world + Vector3(0, 0, -cross_rad) + y_lift)
	colors.append(col_b)
	lines.append(b_world + Vector3(0, 0, cross_rad) + y_lift)
	colors.append(col_b)

	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = lines
	arr[Mesh.ARRAY_COLOR] = colors
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)

	_ramp_guide_mesh.mesh = arr_mesh
	_ramp_guide_mesh.global_position = Vector3.ZERO
	_ramp_guide_mesh.show()


func _on_create_terrain_requested(size: Vector2, resolution: Vector2i, tex_size: Vector2i, base_color: Color) -> void:
	if _current_terrain == null:
		return
	_current_terrain.create_new_terrain(size, resolution, tex_size, base_color)
	if _toolbar != null and _toolbar.has_method("set_current_terrain_info"):
		_toolbar.set_current_terrain_info(size, resolution)
	print("[SimpleTerrain] Created new terrain (Size: %s, Res: %s, Texture: %s)" % [size, resolution, tex_size])
	if _toolbar != null:
		_toolbar.set_embedded_warning(true)
		_toolbar.open_save_data_dialog("terrain_data.res")


func _on_resize_terrain_requested(size: Vector2, resolution: Vector2i) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	var old_size: Vector2 = _current_terrain.get_terrain_size()
	var old_res: Vector2i = _current_terrain.get_resolution()
	var old_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()
	var old_img: PackedByteArray = _current_terrain.data.image_data.duplicate()

	_current_terrain.resize_terrain(size, resolution)

	var new_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()
	var new_img: PackedByteArray = _current_terrain.data.image_data.duplicate()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Resize Terrain")
	undo_redo.add_do_method(_current_terrain, "apply_resize_data", size, resolution, new_heights, new_img)
	undo_redo.add_undo_method(_current_terrain, "apply_resize_data", old_size, old_res, old_heights, old_img)
	undo_redo.commit_action(false)

	if _toolbar != null and _toolbar.has_method("set_current_terrain_info"):
		_toolbar.set_current_terrain_info(size, resolution)

	print("[SimpleTerrain] Resized terrain additively (Size: %s, Res: %s)" % [size, resolution])


func _on_generate_noise_requested(noise: FastNoiseLite, amp: float, flatten_edges: bool) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	var old_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()
	_current_terrain.generate_from_noise(noise, amp, flatten_edges)
	var new_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Generate Noise Terrain")
	undo_redo.add_do_property(_current_terrain.data, "height_data", new_heights)
	undo_redo.add_do_method(_current_terrain, "update_mesh_geometry")
	undo_redo.add_do_method(_current_terrain, "update_collision")
	undo_redo.add_undo_property(_current_terrain.data, "height_data", old_heights)
	undo_redo.add_undo_method(_current_terrain, "update_mesh_geometry")
	undo_redo.add_undo_method(_current_terrain, "update_collision")
	undo_redo.commit_action(false)
	print("[SimpleTerrain] Generated procedural noise terrain (Amp: %.1fm)" % amp)


func _on_flatten_all_requested() -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	var old_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()
	_current_terrain.flatten_all(0.0)
	var new_heights: PackedFloat32Array = _current_terrain.data.height_data.duplicate()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Flatten Entire Terrain")
	undo_redo.add_do_property(_current_terrain.data, "height_data", new_heights)
	undo_redo.add_do_method(_current_terrain, "update_mesh_geometry")
	undo_redo.add_do_method(_current_terrain, "update_collision")
	undo_redo.add_undo_property(_current_terrain.data, "height_data", old_heights)
	undo_redo.add_undo_method(_current_terrain, "update_mesh_geometry")
	undo_redo.add_undo_method(_current_terrain, "update_collision")
	undo_redo.commit_action(false)
	print("[SimpleTerrain] Flattened all terrain heights to 0m")


func _on_clear_texture_requested() -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	_current_terrain.sync_image_data()
	var old_img: PackedByteArray = _current_terrain.data.image_data.duplicate()
	_current_terrain.clear_texture_to_color(SimpleTerrainData.DEFAULT_BASE_COLOR)
	_current_terrain.sync_image_data()
	var new_img: PackedByteArray = _current_terrain.data.image_data.duplicate()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Clear Terrain Texture")
	undo_redo.add_do_property(_current_terrain.data, "image_data", new_img)
	undo_redo.add_do_method(_current_terrain, "_load_or_create_data")
	undo_redo.add_undo_property(_current_terrain.data, "image_data", old_img)
	undo_redo.add_undo_method(_current_terrain, "_load_or_create_data")
	undo_redo.commit_action(false)
	print("[SimpleTerrain] Cleared terrain texture to base color")


func _on_save_mesh_requested(path: String) -> void:
	if _current_terrain == null:
		return
	var err: Error = _current_terrain.save_mesh_to_file(path)
	if err == OK:
		print("[SimpleTerrain] Successfully saved terrain mesh to: ", path)
		_refresh_filesystem(path)
	else:
		printerr("[SimpleTerrain] Failed to save mesh: ", err)


func _on_export_gltf_requested(path: String) -> void:
	if _current_terrain == null:
		return
	var err: Error = _current_terrain.export_to_gltf(path)
	if err == OK:
		print("[SimpleTerrain] Successfully exported terrain as glTF to: ", path)
		_refresh_filesystem(path)
	else:
		printerr("[SimpleTerrain] Failed to export glTF: ", err)


func _on_save_texture_requested(path: String) -> void:
	if _current_terrain == null:
		return
	var err: Error = _current_terrain.save_texture_to_file(path)
	if err == OK:
		print("[SimpleTerrain] Successfully saved terrain texture to: ", path)
		_refresh_filesystem(path)
	else:
		printerr("[SimpleTerrain] Failed to save texture: ", err)


func _on_save_data_requested(path: String) -> void:
	if _current_terrain == null:
		return
	var err: Error = _current_terrain.save_data_to_file(path)
	if err == OK:
		print("[SimpleTerrain] Successfully saved terrain data to: ", path)
		_refresh_filesystem(path)
		var loaded_data: SimpleTerrainData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as SimpleTerrainData
		if loaded_data != null:
			var undo_redo: EditorUndoRedoManager = get_undo_redo()
			undo_redo.create_action("Assign Saved Terrain Data")
			undo_redo.add_do_property(_current_terrain, "data", loaded_data)
			undo_redo.add_undo_property(_current_terrain, "data", _current_terrain.data)
			undo_redo.commit_action()
			if _toolbar != null and _toolbar.has_method("set_embedded_warning"):
				_toolbar.set_embedded_warning(_current_terrain.is_data_embedded())
	else:
		printerr("[SimpleTerrain] Failed to save terrain data: ", err)


func _apply_changes() -> void:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null:
		return
	_save_terrains_recursive(edited_root)
	if _toolbar != null and _current_terrain != null and _toolbar.has_method("set_embedded_warning"):
		_toolbar.set_embedded_warning(_current_terrain.is_data_embedded())


func _save_external_data() -> void:
	_apply_changes()


func _save_terrains_recursive(node: Node) -> void:
	if node is SimpleTerrain3D:
		var terrain: SimpleTerrain3D = node as SimpleTerrain3D
		terrain.sync_image_data()
		if terrain.data != null:
			var res_path: String = terrain.data.resource_path
			if not res_path.is_empty() and not "::" in res_path:
				var err: Error = ResourceSaver.save(terrain.data, res_path)
				if err != OK:
					printerr("[SimpleTerrain] Failed to auto-save terrain data to: ", res_path, " Error: ", err)
	for child: Node in node.get_children():
		_save_terrains_recursive(child)


func _refresh_filesystem(path: String) -> void:
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs != null:
		if path.begins_with("res://"):
			fs.update_file(path)
		fs.scan()


func _on_wireframe_toggled(active: bool) -> void:
	if _current_terrain != null:
		_current_terrain.show_wireframe = active


func _on_auto_slope_sculpt_toggled(active: bool) -> void:
	if _current_terrain == null:
		return
	_current_terrain.auto_slope_on_sculpt = active


func _on_apply_slope_requested(
	cliff_mode: int,
	cliff_color: Color,
	cliff_texture: Texture2D,
	cliff_image: Image,
	cliff_tiling: float,
	threshold_deg: float,
	blend_deg: float,
	keep_flat_paint: bool,
	ground_color: Color,
	auto_slope_sculpt: bool
) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return

	_current_terrain.auto_slope_on_sculpt = auto_slope_sculpt
	_current_terrain.slope_cliff_mode = cliff_mode as SimpleTerrain3D.SlopeCliffMode
	_current_terrain.slope_cliff_color = cliff_color
	_current_terrain.slope_cliff_tiling = cliff_tiling
	_current_terrain.slope_threshold_deg = threshold_deg
	_current_terrain.slope_blend_deg = blend_deg
	_current_terrain.slope_keep_flat_paint = keep_flat_paint
	_current_terrain.slope_ground_color = ground_color

	if cliff_mode == SimpleTerrain3D.SlopeCliffMode.COLOR:
		_current_terrain.slope_cliff_texture = null
	elif cliff_texture != null:
		_current_terrain.slope_cliff_texture = cliff_texture
	elif cliff_image != null and not cliff_image.is_empty():
		var tex: ImageTexture = ImageTexture.create_from_image(cliff_image)
		_current_terrain.slope_cliff_texture = tex
	else:
		_current_terrain.slope_cliff_texture = null

	_current_terrain.sync_image_data()
	var old_image_data: PackedByteArray = _current_terrain.data.image_data.duplicate()

	_current_terrain.apply_slope_coloring(
		cliff_mode,
		cliff_color,
		cliff_image,
		cliff_tiling,
		threshold_deg,
		blend_deg,
		keep_flat_paint,
		ground_color
	)

	_current_terrain.sync_image_data()
	var new_image_data: PackedByteArray = _current_terrain.data.image_data.duplicate()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Auto Color Slopes")
	undo_redo.add_do_property(_current_terrain.data, "image_data", new_image_data)
	undo_redo.add_do_method(_current_terrain, "_load_or_create_data")
	undo_redo.add_undo_property(_current_terrain.data, "image_data", old_image_data)
	undo_redo.add_undo_method(_current_terrain, "_load_or_create_data")
	undo_redo.commit_action(false)


func _on_foliage_add_layer_requested(layer: SimpleTerrainFoliageLayer) -> void:
	if _current_terrain == null or _current_terrain.data == null or layer == null:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	var new_index: int = _current_terrain.data.foliage_layers.size()
	undo_redo.create_action("Add Foliage Layer")
	undo_redo.add_do_method(_current_terrain, "add_foliage_layer", layer)
	undo_redo.add_undo_method(_current_terrain, "remove_foliage_layer", new_index)
	undo_redo.commit_action()
	if _toolbar != null:
		_toolbar.update_foliage_layers(_current_terrain.data.foliage_layers, new_index)
	if _asset_dock != null:
		_asset_dock.set_terrain(_current_terrain)
		_asset_dock.select_active_layer(new_index)


func _on_foliage_delete_layer_requested(layer_index: int) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	if layer_index < 0 or layer_index >= _current_terrain.data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[layer_index]
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Delete Foliage Layer")
	undo_redo.add_do_method(_current_terrain, "remove_foliage_layer", layer_index)
	undo_redo.add_undo_method(_current_terrain, "insert_foliage_layer", layer_index, layer)
	undo_redo.commit_action()
	if _toolbar != null:
		_toolbar.update_foliage_layers(_current_terrain.data.foliage_layers)
	if _asset_dock != null:
		_asset_dock.set_terrain(_current_terrain)


func _on_foliage_clear_layer_requested(layer_index: int) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	if layer_index < 0 or layer_index >= _current_terrain.data.foliage_layers.size():
		return
	var old_transforms: Array[Transform3D] = _current_terrain.get_layer_transforms(layer_index)
	var empty_transforms: Array[Transform3D] = []
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Clear Foliage Layer")
	undo_redo.add_do_method(_current_terrain, "set_layer_transforms", layer_index, empty_transforms)
	undo_redo.add_undo_method(_current_terrain, "set_layer_transforms", layer_index, old_transforms)
	undo_redo.commit_action()
	if _asset_dock != null:
		_asset_dock.set_terrain(_current_terrain)


func _on_terrain_foliage_modified(layer_index: int) -> void:
	if _toolbar == null or _current_terrain == null or _current_terrain.data == null:
		return
	if layer_index == -1:
		_toolbar.update_foliage_layers(_current_terrain.data.foliage_layers)
	else:
		var cur_idx: int = _toolbar.get_foliage_layer_index()
		if cur_idx >= 0 and cur_idx < _current_terrain.data.foliage_layers.size():
			var layer: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[cur_idx]
			if layer != null:
				_toolbar.update_foliage_instance_count(layer.transforms.size())
	if _asset_dock != null:
		_asset_dock.set_terrain(_current_terrain)


func _ensure_foliage_indicators() -> void:
	if _foliage_select_indicator == null:
		_foliage_select_indicator = Node3D.new()
		_foliage_select_indicator.name = "FoliageSelectIndicator"
		_foliage_select_indicator.top_level = true

		_foliage_select_ring = MeshInstance3D.new()
		_foliage_select_ring.name = "SelectRing"
		var ring_torus: TorusMesh = TorusMesh.new()
		ring_torus.inner_radius = 0.94
		ring_torus.outer_radius = 1.0
		ring_torus.rings = 36
		ring_torus.ring_segments = 4
		_foliage_select_ring.mesh = ring_torus

		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_mat.albedo_color = Color(1.0, 0.65, 0.1, 0.95)
		_foliage_select_ring.material_override = ring_mat
		_foliage_select_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_foliage_select_indicator.add_child(_foliage_select_ring)

		_foliage_select_box = MeshInstance3D.new()
		_foliage_select_box.name = "SelectBox"
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = Vector3(1.0, 1.0, 1.0)
		_foliage_select_box.mesh = box_mesh

		var box_mat: StandardMaterial3D = StandardMaterial3D.new()
		box_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box_mat.albedo_color = Color(1.0, 0.75, 0.2, 0.25)
		_foliage_select_box.material_override = box_mat
		_foliage_select_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_foliage_select_indicator.add_child(_foliage_select_box)

	if _foliage_hover_indicator == null:
		_foliage_hover_indicator = MeshInstance3D.new()
		_foliage_hover_indicator.name = "FoliageHoverIndicator"
		_foliage_hover_indicator.top_level = true
		_foliage_hover_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var hover_torus: TorusMesh = TorusMesh.new()
		hover_torus.inner_radius = 0.92
		hover_torus.outer_radius = 1.0
		hover_torus.rings = 32
		hover_torus.ring_segments = 4
		_foliage_hover_indicator.mesh = hover_torus

		var hover_mat: StandardMaterial3D = StandardMaterial3D.new()
		hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hover_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		hover_mat.albedo_color = Color(1.0, 0.9, 0.2, 0.65)
		_foliage_hover_indicator.material_override = hover_mat

	if _current_terrain != null:
		if _foliage_select_indicator.get_parent() != _current_terrain:
			if _foliage_select_indicator.get_parent() != null:
				_foliage_select_indicator.get_parent().remove_child(_foliage_select_indicator)
			_current_terrain.add_child(_foliage_select_indicator)

		if _foliage_hover_indicator.get_parent() != _current_terrain:
			if _foliage_hover_indicator.get_parent() != null:
				_foliage_hover_indicator.get_parent().remove_child(_foliage_hover_indicator)
			_current_terrain.add_child(_foliage_hover_indicator)


func _cleanup_foliage_indicators() -> void:
	if _foliage_select_indicator != null:
		if _foliage_select_indicator.get_parent() != null:
			_foliage_select_indicator.get_parent().remove_child(_foliage_select_indicator)
		_foliage_select_indicator.queue_free()
		_foliage_select_indicator = null
		_foliage_select_ring = null
		_foliage_select_box = null

	if _foliage_hover_indicator != null:
		if _foliage_hover_indicator.get_parent() != null:
			_foliage_hover_indicator.get_parent().remove_child(_foliage_hover_indicator)
		_foliage_hover_indicator.queue_free()
		_foliage_hover_indicator = null


func _hide_foliage_indicators() -> void:
	if _foliage_select_indicator != null:
		_foliage_select_indicator.hide()
	if _foliage_hover_indicator != null:
		_foliage_hover_indicator.hide()
	_hovered_foliage_layer_idx = -1
	_hovered_foliage_instance_idx = -1


func _select_foliage_instance(layer_idx: int, instance_idx: int) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	if layer_idx < 0 or layer_idx >= _current_terrain.data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[layer_idx]
	if layer == null or instance_idx < 0 or instance_idx >= layer.transforms.size():
		return

	_selected_foliage_layer_idx = layer_idx
	_selected_foliage_instance_idx = instance_idx
	var xform: Transform3D = layer.transforms[instance_idx]

	_update_foliage_selection_indicator()
	if _toolbar != null:
		_toolbar.set_selected_foliage_instance(layer_idx, instance_idx, xform, layer.name)


func _deselect_foliage_instance() -> void:
	_selected_foliage_layer_idx = -1
	_selected_foliage_instance_idx = -1
	_is_dragging_foliage_instance = false
	if _foliage_select_indicator != null:
		_foliage_select_indicator.hide()
	if _toolbar != null:
		_toolbar.set_selected_foliage_instance(-1, -1, Transform3D.IDENTITY, "")


func _update_foliage_selection_indicator() -> void:
	_ensure_foliage_indicators()
	if _foliage_select_indicator == null or _current_terrain == null or _current_terrain.data == null:
		return
	if _selected_foliage_layer_idx < 0 or _selected_foliage_layer_idx >= _current_terrain.data.foliage_layers.size():
		_foliage_select_indicator.hide()
		return
	var layer: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[_selected_foliage_layer_idx]
	if layer == null or _selected_foliage_instance_idx < 0 or _selected_foliage_instance_idx >= layer.transforms.size():
		_foliage_select_indicator.hide()
		return

	var local_xform: Transform3D = layer.transforms[_selected_foliage_instance_idx]
	var world_xform: Transform3D = _current_terrain.global_transform * local_xform

	var aabb: AABB = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	if layer.mesh != null:
		aabb = layer.mesh.get_aabb()

	var mesh_w: float = maxf(aabb.size.x, aabb.size.z) * 0.5 * world_xform.basis.get_scale().x
	mesh_w = maxf(mesh_w, 0.5)
	var mesh_h: float = maxf(aabb.size.y, 0.5) * world_xform.basis.get_scale().y

	_foliage_select_indicator.global_transform = Transform3D(Basis(), world_xform.origin)
	if _foliage_select_ring != null:
		_foliage_select_ring.scale = Vector3(mesh_w * 1.3, 1.0, mesh_w * 1.3)
		_foliage_select_ring.position = Vector3(0.0, 0.05, 0.0)

	if _foliage_select_box != null:
		_foliage_select_box.scale = Vector3(mesh_w * 2.2, mesh_h, mesh_w * 2.2)
		_foliage_select_box.position = Vector3(0.0, mesh_h * 0.5, 0.0)

	_foliage_select_indicator.show()


func _update_foliage_hover_indicator(layer_idx: int, instance_idx: int) -> void:
	_ensure_foliage_indicators()
	if _foliage_hover_indicator == null or _current_terrain == null or _current_terrain.data == null:
		return
	if layer_idx < 0 or layer_idx >= _current_terrain.data.foliage_layers.size():
		_foliage_hover_indicator.hide()
		return
	var layer: SimpleTerrainFoliageLayer = _current_terrain.data.foliage_layers[layer_idx]
	if layer == null or instance_idx < 0 or instance_idx >= layer.transforms.size():
		_foliage_hover_indicator.hide()
		return

	if layer_idx == _selected_foliage_layer_idx and instance_idx == _selected_foliage_instance_idx:
		_foliage_hover_indicator.hide()
		return

	var local_xform: Transform3D = layer.transforms[instance_idx]
	var world_pos: Vector3 = _current_terrain.global_transform * local_xform.origin

	var aabb: AABB = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	if layer.mesh != null:
		aabb = layer.mesh.get_aabb()
	var mesh_w: float = maxf(aabb.size.x, aabb.size.z) * 0.5 * local_xform.basis.get_scale().x
	mesh_w = maxf(mesh_w, 0.5)

	_foliage_hover_indicator.global_position = world_pos + Vector3(0.0, 0.06, 0.0)
	_foliage_hover_indicator.scale = Vector3(mesh_w * 1.3, 1.0, mesh_w * 1.3)
	_foliage_hover_indicator.show()


func _hide_foliage_hover_indicator() -> void:
	if _foliage_hover_indicator != null:
		_foliage_hover_indicator.hide()
	_hovered_foliage_layer_idx = -1
	_hovered_foliage_instance_idx = -1


func _rotate_selected_foliage_instance(deg: float) -> void:
	if _current_terrain == null or _current_terrain.data == null or _selected_foliage_instance_idx < 0:
		return
	var old_xform: Transform3D = _current_terrain.get_foliage_instance_transform(_selected_foliage_layer_idx, _selected_foliage_instance_idx)
	var rad: float = deg_to_rad(deg)
	var new_xform: Transform3D = old_xform
	new_xform.basis = new_xform.basis.rotated(Vector3.UP, rad)

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Rotate Foliage Instance")
	undo_redo.add_do_method(_current_terrain, "set_foliage_instance_transform", _selected_foliage_layer_idx, _selected_foliage_instance_idx, new_xform)
	undo_redo.add_undo_method(_current_terrain, "set_foliage_instance_transform", _selected_foliage_layer_idx, _selected_foliage_instance_idx, old_xform)
	undo_redo.commit_action()
	_update_foliage_selection_indicator()
	if _toolbar != null:
		var layer_name: String = _current_terrain.data.foliage_layers[_selected_foliage_layer_idx].name
		_toolbar.set_selected_foliage_instance(_selected_foliage_layer_idx, _selected_foliage_instance_idx, new_xform, layer_name)


func _on_foliage_instance_transform_changed(layer_idx: int, instance_idx: int, new_xform: Transform3D) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	var old_xform: Transform3D = _current_terrain.get_foliage_instance_transform(layer_idx, instance_idx)
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Edit Foliage Instance")
	undo_redo.add_do_method(_current_terrain, "set_foliage_instance_transform", layer_idx, instance_idx, new_xform)
	undo_redo.add_undo_method(_current_terrain, "set_foliage_instance_transform", layer_idx, instance_idx, old_xform)
	undo_redo.commit_action()
	_update_foliage_selection_indicator()


func _on_foliage_instance_align_requested(layer_idx: int, instance_idx: int) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	var old_xform: Transform3D = _current_terrain.get_foliage_instance_transform(layer_idx, instance_idx)
	var new_xform: Transform3D = _current_terrain.align_foliage_instance_to_surface(layer_idx, instance_idx)
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Align Foliage Instance to Surface")
	undo_redo.add_do_method(_current_terrain, "set_foliage_instance_transform", layer_idx, instance_idx, new_xform)
	undo_redo.add_undo_method(_current_terrain, "set_foliage_instance_transform", layer_idx, instance_idx, old_xform)
	undo_redo.commit_action()
	_update_foliage_selection_indicator()
	if _toolbar != null:
		var layer_name: String = _current_terrain.data.foliage_layers[layer_idx].name
		_toolbar.set_selected_foliage_instance(layer_idx, instance_idx, new_xform, layer_name)


func _on_foliage_instance_delete_requested(layer_idx: int, instance_idx: int) -> void:
	if _current_terrain == null or _current_terrain.data == null:
		return
	var old_xforms: Array[Transform3D] = _current_terrain.get_layer_transforms(layer_idx)
	var new_xforms: Array[Transform3D] = old_xforms.duplicate()
	if instance_idx >= 0 and instance_idx < new_xforms.size():
		new_xforms.remove_at(instance_idx)
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Delete Foliage Instance")
	undo_redo.add_do_method(_current_terrain, "set_layer_transforms", layer_idx, new_xforms)
	undo_redo.add_undo_method(_current_terrain, "set_layer_transforms", layer_idx, old_xforms)
	undo_redo.commit_action()
	_deselect_foliage_instance()


