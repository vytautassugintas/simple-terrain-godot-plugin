@tool
class_name SimpleTerrainSettings

## Manages persistent editor configuration, imported models registry, custom patterns, and user tool preferences.

const PROJECT_SETTINGS_PATH: String = "res://addons/simple_terrain/settings.json"
const USER_STATE_PATH: String = "user://simple_terrain_editor_state.json"
const FOLIAGE_PRESETS_DIR: String = "res://addons/simple_terrain/foliage_presets"
const PATTERNS_DIR: String = "res://addons/simple_terrain/patterns"
const BRUSHES_DIR: String = "res://addons/simple_terrain/brushes"

const BUILTIN_BRUSHES: Array[Dictionary] = [
	{
		"id": "circle",
		"name": "Soft Circle",
		"path": "res://addons/simple_terrain/brushes/circle_gradient.png",
		"icon": "res://addons/simple_terrain/icons/brush_circle.svg"
	},
	{
		"id": "square",
		"name": "Square",
		"path": "res://addons/simple_terrain/brushes/square.png",
		"icon": "res://addons/simple_terrain/icons/brush_square.svg"
	},
	{
		"id": "patch",
		"name": "Patch / Grunge",
		"path": "res://addons/simple_terrain/brushes/patch.png",
		"icon": "res://addons/simple_terrain/icons/brush_patch.svg"
	},
	{
		"id": "small_dots",
		"name": "Small Dots",
		"path": "res://addons/simple_terrain/brushes/small_dots.png",
		"icon": "res://addons/simple_terrain/icons/brush_dots.svg"
	},
	{
		"id": "x_gradient",
		"name": "Star / Cross",
		"path": "res://addons/simple_terrain/brushes/x_gradient.png",
		"icon": "res://addons/simple_terrain/icons/brush_cross.svg"
	},
]


static func load_project_settings() -> Dictionary:
	if not FileAccess.file_exists(PROJECT_SETTINGS_PATH):
		return {"custom_patterns": [], "custom_models": []}
	var file: FileAccess = FileAccess.open(PROJECT_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {"custom_patterns": [], "custom_models": []}
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK or not json.data is Dictionary:
		return {"custom_patterns": [], "custom_models": []}
	var dict: Dictionary = json.data as Dictionary
	if not dict.has("custom_patterns"):
		dict["custom_patterns"] = []
	if not dict.has("custom_models"):
		dict["custom_models"] = []
	if not dict.has("custom_brushes"):
		dict["custom_brushes"] = []
	return dict


static func save_project_settings(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PROJECT_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		printerr("[SimpleTerrainSettings] Could not open project settings for writing: ", PROJECT_SETTINGS_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


static func register_custom_pattern(p_name: String, p_path: String) -> void:
	var data: Dictionary = load_project_settings()
	var patterns: Array = data.get("custom_patterns", [])
	for entry: Variant in patterns:
		if entry is Dictionary and entry.get("path", "") == p_path:
			return # already registered
	patterns.append({"name": p_name, "path": p_path})
	data["custom_patterns"] = patterns
	save_project_settings(data)


static func get_custom_patterns() -> Array[Dictionary]:
	var data: Dictionary = load_project_settings()
	var res: Array[Dictionary] = []
	for item: Variant in data.get("custom_patterns", []):
		if item is Dictionary:
			res.append(item as Dictionary)
	return res


static func register_imported_model(p_name: String, p_path: String) -> void:
	var data: Dictionary = load_project_settings()
	var models: Array = data.get("custom_models", [])
	for entry: Variant in models:
		if entry is Dictionary and entry.get("path", "") == p_path:
			return # already registered
	models.append({"name": p_name, "path": p_path})
	data["custom_models"] = models
	save_project_settings(data)


static func get_imported_models() -> Array[Dictionary]:
	var data: Dictionary = load_project_settings()
	var res: Array[Dictionary] = []
	for item: Variant in data.get("custom_models", []):
		if item is Dictionary:
			res.append(item as Dictionary)
	return res


static func register_custom_brush(p_path: String, p_name: String = "") -> String:
	var data: Dictionary = load_project_settings()
	var brushes: Array = data.get("custom_brushes", [])
	for entry: Variant in brushes:
		if entry is Dictionary and entry.get("path", "") == p_path:
			return str((entry as Dictionary).get("id", ""))
	if p_name.is_empty():
		p_name = p_path.get_file().get_basename().capitalize().replace("_", " ")
	var new_id: String = "custom_" + str(brushes.size())
	brushes.append({
		"id": new_id,
		"name": p_name,
		"path": p_path,
		"icon": "res://addons/simple_terrain/icons/brush_shape.svg"
	})
	data["custom_brushes"] = brushes
	save_project_settings(data)
	return new_id


static func get_custom_brushes() -> Array[Dictionary]:
	var data: Dictionary = load_project_settings()
	var res: Array[Dictionary] = []
	for item: Variant in data.get("custom_brushes", []):
		if item is Dictionary:
			res.append(item as Dictionary)
	return res


static func get_all_brushes() -> Array[Dictionary]:
	var list: Array[Dictionary] = BUILTIN_BRUSHES.duplicate(true)
	for b: Dictionary in get_custom_brushes():
		list.append(b)
	return list


static func save_last_brush_id(p_id: String) -> void:
	var state: Dictionary = load_user_state()
	state["selected_brush_id"] = p_id
	save_user_state(state)


static func get_last_brush_id() -> String:
	var state: Dictionary = load_user_state()
	return str(state.get("selected_brush_id", "circle"))


static func save_slope_limits(min_deg: float, max_deg: float) -> void:
	var state: Dictionary = load_user_state()
	state["slope_limit_min"] = min_deg
	state["slope_limit_max"] = max_deg
	save_user_state(state)


static func get_slope_limits() -> Vector2:
	var state: Dictionary = load_user_state()
	var min_d: float = float(state.get("slope_limit_min", 0.0))
	var max_d: float = float(state.get("slope_limit_max", 90.0))
	return Vector2(min_d, max_d)


static func load_user_state() -> Dictionary:
	if not FileAccess.file_exists(USER_STATE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(USER_STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK or not json.data is Dictionary:
		return {}
	return json.data as Dictionary


static func save_user_state(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(USER_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


static func save_last_pattern_path(path: String) -> void:
	var state: Dictionary = load_user_state()
	state["selected_pattern_path"] = path
	save_user_state(state)


static func get_last_pattern_path() -> String:
	var state: Dictionary = load_user_state()
	return str(state.get("selected_pattern_path", ""))


static func save_brush_options(options: Dictionary) -> void:
	var state: Dictionary = load_user_state()
	for k: Variant in options:
		state[k] = options[k]
	save_user_state(state)


static func get_brush_options() -> Dictionary:
	return load_user_state()


const DEFAULT_SHORTCUTS: Dictionary = {
	"mode_view": {"keycode": KEY_V, "shift": false, "ctrl": false, "alt": true},
	"mode_sculpt": {"keycode": KEY_B, "shift": false, "ctrl": false, "alt": true},
	"mode_paint": {"keycode": KEY_P, "shift": false, "ctrl": false, "alt": true},
	"mode_foliage": {"keycode": KEY_G, "shift": false, "ctrl": false, "alt": true},
	"toggle_pie_menu": {"keycode": KEY_TAB, "shift": false, "ctrl": false, "alt": true},
	"toggle_wireframe": {"keycode": KEY_W, "shift": false, "ctrl": false, "alt": true},
	"toggle_hud": {"keycode": KEY_H, "shift": false, "ctrl": false, "alt": true},
	"axis_lock_x": {"keycode": KEY_X, "shift": false, "ctrl": false, "alt": true},
	"axis_lock_z": {"keycode": KEY_Z, "shift": false, "ctrl": false, "alt": true},
	"axis_lock_clear": {"keycode": KEY_C, "shift": false, "ctrl": false, "alt": true},
	"brush_gesture": {"keycode": KEY_R, "shift": false, "ctrl": false, "alt": true},
}


static func get_shortcuts() -> Dictionary:
	var proj: Dictionary = load_project_settings()
	var sc: Dictionary = DEFAULT_SHORTCUTS.duplicate(true)
	if proj.has("shortcuts") and proj["shortcuts"] is Dictionary:
		var user_sc: Dictionary = proj["shortcuts"] as Dictionary
		for action: Variant in user_sc:
			var act_str: String = str(action)
			if user_sc[action] is Dictionary:
				sc[act_str] = user_sc[action]
	return sc


static func save_shortcuts(shortcuts: Dictionary) -> void:
	var proj: Dictionary = load_project_settings()
	proj["shortcuts"] = shortcuts
	save_project_settings(proj)


static func matches_shortcut(action: String, event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	var shortcuts: Dictionary = get_shortcuts()
	if not shortcuts.has(action):
		return false
	var cfg: Dictionary = shortcuts[action]
	var code: int = int(cfg.get("keycode", 0))
	var shift: bool = bool(cfg.get("shift", false))
	var ctrl: bool = bool(cfg.get("ctrl", false))
	var alt: bool = bool(cfg.get("alt", false))
	return event.keycode == code and event.shift_pressed == shift and event.ctrl_pressed == ctrl and event.alt_pressed == alt

