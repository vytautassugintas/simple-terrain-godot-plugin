@tool
class_name TerrainSlopeDialog
extends ConfirmationDialog

## Dialog for configuring and applying automatic slope coloring to terrain.

signal apply_slope_requested(
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
)
signal auto_slope_sculpt_toggled(active: bool)

enum CliffMode {
	COLOR = 0,
	TEXTURE = 1,
}

const PRESET_ROCK_GRAY: Color = Color(0.45, 0.45, 0.45, 1.0)
const PRESET_DARK_SLATE: Color = Color(0.24, 0.25, 0.28, 1.0)
const PRESET_SANDSTONE: Color = Color(0.78, 0.64, 0.44, 1.0)
const PRESET_RED_ROCK: Color = Color(0.55, 0.29, 0.22, 1.0)
const PRESET_SNOW_PEAK: Color = Color(0.92, 0.95, 0.98, 1.0)
const DEFAULT_CLIFF_PATTERN_PATH: String = "res://addons/simple_terrain/patterns/rock_cliff.png"

var current_cliff_mode: CliffMode = CliffMode.TEXTURE
var selected_cliff_image: Image = null
var selected_cliff_texture: Texture2D = null
var selected_cliff_name: String = "Rock Cliff"

var pattern_menu: PopupMenu = null
@onready var file_dialog: FileDialog = %CliffFileDialog

@onready var mode_color_btn: Button = %ModeColorBtn
@onready var mode_texture_btn: Button = %ModeTextureBtn

@onready var color_options_box: HBoxContainer = %ColorOptionsBox
@onready var cliff_color_picker: ColorPickerButton = %CliffColorPicker
@onready var preset_gray_btn: Button = %PresetGrayBtn
@onready var preset_slate_btn: Button = %PresetSlateBtn
@onready var preset_sandstone_btn: Button = %PresetSandstoneBtn
@onready var preset_red_btn: Button = %PresetRedBtn
@onready var preset_snow_btn: Button = %PresetSnowBtn

@onready var texture_options_box: HBoxContainer = %TextureOptionsBox
@onready var texture_preview_rect: TextureRect = %TexturePreviewRect
@onready var pattern_name_label: Label = %PatternNameLabel
@onready var choose_pattern_btn: MenuButton = %ChoosePatternBtn
@onready var tiling_spin: SpinBox = %TilingSpinBox

@onready var threshold_spin: SpinBox = %ThresholdSpinBox
@onready var blend_spin: SpinBox = %BlendSpinBox

@onready var keep_flat_check: CheckBox = %KeepFlatCheck
@onready var ground_color_box: HBoxContainer = %GroundColorBox
@onready var ground_color_picker: ColorPickerButton = %GroundColorPicker

@onready var auto_sculpt_check: CheckBox = %AutoSculptCheck


func _ready() -> void:
	_connect_controls()
	_load_default_cliff_pattern()
	_update_ui_state()


func _connect_controls() -> void:
	confirmed.connect(_on_confirmed)

	if mode_color_btn != null:
		mode_color_btn.pressed.connect(func() -> void: set_cliff_mode(CliffMode.COLOR))
	if mode_texture_btn != null:
		mode_texture_btn.pressed.connect(func() -> void: set_cliff_mode(CliffMode.TEXTURE))

	if preset_gray_btn != null:
		preset_gray_btn.pressed.connect(func() -> void: _apply_color_preset(PRESET_ROCK_GRAY))
	if preset_slate_btn != null:
		preset_slate_btn.pressed.connect(func() -> void: _apply_color_preset(PRESET_DARK_SLATE))
	if preset_sandstone_btn != null:
		preset_sandstone_btn.pressed.connect(func() -> void: _apply_color_preset(PRESET_SANDSTONE))
	if preset_red_btn != null:
		preset_red_btn.pressed.connect(func() -> void: _apply_color_preset(PRESET_RED_ROCK))
	if preset_snow_btn != null:
		preset_snow_btn.pressed.connect(func() -> void: _apply_color_preset(PRESET_SNOW_PEAK))

	if choose_pattern_btn != null:
		pattern_menu = choose_pattern_btn.get_popup()
		_setup_pattern_menu()

	if keep_flat_check != null:
		keep_flat_check.toggled.connect(func(_p: bool) -> void: _update_ui_state())

	if auto_sculpt_check != null:
		auto_sculpt_check.toggled.connect(func(val: bool) -> void: auto_slope_sculpt_toggled.emit(val))


func _setup_pattern_menu() -> void:
	if pattern_menu != null and pattern_menu.item_count == 0:
		pattern_menu.add_item("Rock Cliff", 0)
		pattern_menu.add_item("Cobblestone", 1)
		pattern_menu.add_item("Dirt Gravel", 2)
		pattern_menu.add_item("Cracked Earth", 3)
		pattern_menu.add_item("Sand Ripples", 4)
		pattern_menu.add_item("Grass Blades", 5)
		pattern_menu.add_item("Soft Radial", 6)
		pattern_menu.add_item("Splatter Grunge", 7)
		pattern_menu.add_separator()
		pattern_menu.add_item("Choose Custom Image File...", 10)
		if not pattern_menu.id_pressed.is_connected(_on_pattern_menu_id_pressed):
			pattern_menu.id_pressed.connect(_on_pattern_menu_id_pressed)

	if file_dialog != null and not file_dialog.file_selected.is_connected(_on_custom_file_selected):
		file_dialog.file_selected.connect(_on_custom_file_selected)


func _on_pattern_menu_id_pressed(id: int) -> void:
	var pattern_map: Dictionary = {
		0: "rock_cliff",
		1: "cobblestone",
		2: "dirt_gravel",
		3: "cracked_earth",
		4: "sand_ripples",
		5: "grass_blades",
		6: "soft_radial",
		7: "splatter_grunge"
	}
	if id == 10:
		if file_dialog != null:
			file_dialog.popup_centered(Vector2i(800, 500))
		return

	var file_prefix: String = pattern_map.get(id, "rock_cliff")
	var file_path: String = "res://addons/simple_terrain/patterns/%s.png" % file_prefix
	if ResourceLoader.exists(file_path):
		var tex: Texture2D = load(file_path) as Texture2D
		if tex != null:
			var title: String = file_prefix.replace("_", " ").capitalize()
			set_cliff_pattern(tex, title)


func _on_custom_file_selected(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			var title: String = path.get_file().get_basename().capitalize()
			set_cliff_pattern(tex, title)


func _apply_color_preset(col: Color) -> void:
	if cliff_color_picker != null:
		cliff_color_picker.color = col


func _load_default_cliff_pattern() -> void:
	if ResourceLoader.exists(DEFAULT_CLIFF_PATTERN_PATH):
		var res: Resource = ResourceLoader.load(DEFAULT_CLIFF_PATTERN_PATH)
		if res is Texture2D:
			selected_cliff_texture = res as Texture2D
			selected_cliff_image = selected_cliff_texture.get_image()
			if selected_cliff_image != null:
				selected_cliff_image = selected_cliff_image.duplicate()
			selected_cliff_name = "Rock Cliff"
			if texture_preview_rect != null:
				texture_preview_rect.texture = selected_cliff_texture
			if pattern_name_label != null:
				pattern_name_label.text = selected_cliff_name


func open_dialog(_pattern_dlg: Variant = null) -> void:
	if selected_cliff_texture == null:
		_load_default_cliff_pattern()
	else:
		if texture_preview_rect != null:
			texture_preview_rect.texture = selected_cliff_texture
		if pattern_name_label != null:
			pattern_name_label.text = selected_cliff_name

	_update_ui_state()
	popup_centered(Vector2i(480, 420))


func set_cliff_mode(mode: CliffMode) -> void:
	current_cliff_mode = mode
	_update_ui_state()


func _update_ui_state() -> void:
	if mode_color_btn == null or mode_texture_btn == null:
		return

	mode_color_btn.button_pressed = (current_cliff_mode == CliffMode.COLOR)
	mode_texture_btn.button_pressed = (current_cliff_mode == CliffMode.TEXTURE)

	color_options_box.visible = (current_cliff_mode == CliffMode.COLOR)
	texture_options_box.visible = (current_cliff_mode == CliffMode.TEXTURE)

	ground_color_box.visible = not keep_flat_check.button_pressed


func set_cliff_pattern(tex: Texture2D, p_name: String) -> void:
	selected_cliff_texture = tex
	if tex != null:
		selected_cliff_image = tex.get_image()
		if selected_cliff_image != null:
			selected_cliff_image = selected_cliff_image.duplicate()
	else:
		selected_cliff_image = null
	selected_cliff_name = p_name

	if texture_preview_rect != null:
		texture_preview_rect.texture = selected_cliff_texture
	if pattern_name_label != null:
		pattern_name_label.text = selected_cliff_name


func set_cliff_pattern_from_image(img: Image, p_name: String) -> void:
	selected_cliff_image = img.duplicate() if img != null else null
	selected_cliff_texture = ImageTexture.create_from_image(selected_cliff_image) if selected_cliff_image != null else null
	selected_cliff_name = p_name

	if texture_preview_rect != null:
		texture_preview_rect.texture = selected_cliff_texture
	if pattern_name_label != null:
		pattern_name_label.text = selected_cliff_name


func init_from_terrain(terrain: SimpleTerrain3D) -> void:
	if terrain == null:
		return
	set_cliff_mode(terrain.slope_cliff_mode as CliffMode)
	if cliff_color_picker != null:
		cliff_color_picker.color = terrain.slope_cliff_color
	if terrain.slope_cliff_texture != null:
		var tex_name: String = terrain.slope_cliff_texture.resource_path.get_file().get_basename().capitalize()
		if tex_name.is_empty():
			tex_name = "Cliff Texture"
		set_cliff_pattern(terrain.slope_cliff_texture, tex_name)
	elif selected_cliff_texture == null:
		_load_default_cliff_pattern()
	if tiling_spin != null:
		tiling_spin.value = terrain.slope_cliff_tiling
	if threshold_spin != null:
		threshold_spin.value = terrain.slope_threshold_deg
	if blend_spin != null:
		blend_spin.value = terrain.slope_blend_deg
	if keep_flat_check != null:
		keep_flat_check.button_pressed = terrain.slope_keep_flat_paint
	if ground_color_picker != null:
		ground_color_picker.color = terrain.slope_ground_color
	if auto_sculpt_check != null:
		auto_sculpt_check.button_pressed = terrain.auto_slope_on_sculpt
	_update_ui_state()


func set_auto_sculpt_active(active: bool) -> void:
	if auto_sculpt_check != null:
		auto_sculpt_check.button_pressed = active


func set_auto_sculpt_enabled(active: bool) -> void:
	set_auto_sculpt_active(active)


func is_auto_sculpt_enabled() -> bool:
	return auto_sculpt_check.button_pressed if auto_sculpt_check != null else false


func get_cliff_mode() -> int:
	return int(current_cliff_mode)


func get_cliff_color() -> Color:
	return cliff_color_picker.color if cliff_color_picker != null else PRESET_ROCK_GRAY


func get_cliff_texture() -> Texture2D:
	return selected_cliff_texture


func get_cliff_image() -> Image:
	return selected_cliff_image


func get_cliff_tiling() -> float:
	return float(tiling_spin.value) if tiling_spin != null else 8.0


func get_slope_threshold() -> float:
	return float(threshold_spin.value) if threshold_spin != null else 35.0


func get_slope_blend() -> float:
	return float(blend_spin.value) if blend_spin != null else 10.0


func get_keep_flat_paint() -> bool:
	return keep_flat_check.button_pressed if keep_flat_check != null else true


func get_ground_color() -> Color:
	return ground_color_picker.color if ground_color_picker != null else SimpleTerrainData.DEFAULT_BASE_COLOR


func _on_confirmed() -> void:
	var mode: int = int(current_cliff_mode)
	var col: Color = cliff_color_picker.color
	var tex: Texture2D = selected_cliff_texture
	var img: Image = selected_cliff_image
	var tiling: float = float(tiling_spin.value)
	var threshold: float = float(threshold_spin.value)
	var blend: float = float(blend_spin.value)
	var keep_flat: bool = keep_flat_check.button_pressed
	var ground_col: Color = ground_color_picker.color
	var auto_sculpt: bool = auto_sculpt_check.button_pressed

	apply_slope_requested.emit(
		mode,
		col,
		tex,
		img,
		tiling,
		threshold,
		blend,
		keep_flat,
		ground_col,
		auto_sculpt
	)
