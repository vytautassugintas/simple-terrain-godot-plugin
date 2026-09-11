@tool
class_name TerrainEditorToolbar
extends PanelContainer

## Professional toolbar for SimpleTerrain3D inside the 3D viewport.

signal mode_changed(tool_mode: int)
signal sculpt_settings_changed(submode: int, radius: float, strength: float, falloff: float, target_height: float)
signal ramp_apply_requested()
signal ramp_clear_requested()
signal sculpt_mask_changed(mask_image: Image, mask_angle: float)
signal brush_shape_changed(brush_image: Image, brush_angle: float, brush_id: String)
signal slope_limits_changed(min_slope_deg: float, max_slope_deg: float)
signal paint_settings_changed(submode: int, color: Color, stamp_image: Image, tiling: float, angle: float, radius: float, strength: float, falloff: float)
signal create_terrain_requested(size: Vector2, resolution: Vector2i, tex_size: Vector2i, base_color: Color)
signal resize_terrain_requested(size: Vector2, resolution: Vector2i)
signal generate_noise_requested(noise: FastNoiseLite, amplitude: float, flatten_edges: bool)
signal flatten_all_requested()
signal clear_texture_requested()
signal save_mesh_requested(path: String)
signal export_gltf_requested(path: String)
signal save_texture_requested(path: String)
signal save_data_requested(path: String)
signal pick_height_mode_toggled(active: bool)
signal wireframe_toggled(active: bool)
signal hud_toggled(active: bool)
signal axis_lock_cycle_requested()
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
signal foliage_settings_changed(
	submode: int,
	layer_index: int,
	radius: float,
	density: float,
	min_spacing: float,
	min_scale: float,
	max_scale: float,
	align_to_normal: float,
	max_slope_deg: float,
	height_offset: float,
	random_yaw: bool,
	random_tilt_deg: float
)
signal foliage_add_layer_requested(layer: SimpleTerrainFoliageLayer)
signal foliage_delete_layer_requested(layer_index: int)
signal foliage_clear_layer_requested(layer_index: int)
signal foliage_instance_transform_changed(layer_index: int, instance_index: int, new_xform: Transform3D)
signal foliage_instance_align_requested(layer_index: int, instance_index: int)
signal foliage_instance_delete_requested(layer_index: int, instance_index: int)
signal foliage_instance_deselect_requested()
signal open_asset_dock_requested(tab_index: int)
signal close_asset_dock_requested()

enum ToolMode {
	VIEW = 0,
	SCULPT = 1,
	PAINT = 2,
	FOLIAGE = 3,
}

const PRESET_COLOR_GRASS: Color = Color(0.28, 0.50, 0.22, 1.0)
const PRESET_COLOR_DIRT: Color = Color(0.48, 0.35, 0.22, 1.0)
const PRESET_COLOR_ROCK: Color = Color(0.45, 0.45, 0.45, 1.0)
const PRESET_COLOR_SAND: Color = Color(0.78, 0.70, 0.45, 1.0)
const PRESET_COLOR_SNOW: Color = Color(0.92, 0.95, 0.98, 1.0)

const ICON_VIEW: Texture2D = preload("res://addons/simple_terrain/icons/mode_view.svg")
const ICON_SCULPT: Texture2D = preload("res://addons/simple_terrain/icons/mode_sculpt.svg")
const ICON_PAINT: Texture2D = preload("res://addons/simple_terrain/icons/mode_paint.svg")
const ICON_SLOPE_COLOR: Texture2D = preload("res://addons/simple_terrain/icons/slope_color.svg")
const ICON_TERRAIN_MENU: Texture2D = preload("res://addons/simple_terrain/icons/terrain_menu.svg")
const ICON_NEW_TERRAIN: Texture2D = preload("res://addons/simple_terrain/icons/new_terrain.svg")
const ICON_NOISE_GEN: Texture2D = preload("res://addons/simple_terrain/icons/noise_gen.svg")
const ICON_SAVE: Texture2D = preload("res://addons/simple_terrain/icons/save.svg")
const ICON_SAVE_DATA: Texture2D = preload("res://addons/simple_terrain/icons/save_data.svg")
const ICON_EXPORT_GLTF: Texture2D = preload("res://addons/simple_terrain/icons/export_gltf.svg")
const ICON_SAVE_MESH: Texture2D = preload("res://addons/simple_terrain/icons/save_mesh.svg")
const ICON_SAVE_TEXTURE: Texture2D = preload("res://addons/simple_terrain/icons/save_texture.svg")
const ICON_SCULPT_RAISE: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_raise.svg")
const ICON_SCULPT_LOWER: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_lower.svg")
const ICON_SCULPT_SMOOTH: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_smooth.svg")
const ICON_SCULPT_FLATTEN: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_flatten.svg")
const ICON_SCULPT_NOISE: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_noise.svg")
const ICON_SCULPT_TERRACE: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_terrace.svg")
const ICON_SCULPT_RAMP: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_ramp.svg")
const ICON_SCULPT_MASK: Texture2D = preload("res://addons/simple_terrain/icons/sculpt_mask.svg")
const ICON_BRUSH_JITTER: Texture2D = preload("res://addons/simple_terrain/icons/brush_jitter.svg")
const ICON_PATTERN_LIB: Texture2D = preload("res://addons/simple_terrain/icons/pattern_library.svg")
const ICON_EYEDROPPER: Texture2D = preload("res://addons/simple_terrain/icons/eyedropper.svg")
const ICON_ERASER: Texture2D = preload("res://addons/simple_terrain/icons/eraser.svg")
const ICON_HELP: Texture2D = preload("res://addons/simple_terrain/icons/help.svg")
const ICON_WIREFRAME: Texture2D = preload("res://addons/simple_terrain/icons/wireframe.svg")
const ICON_HUD: Texture2D = preload("res://addons/simple_terrain/icons/hud_info.svg")
const ICON_AXIS_LOCK: Texture2D = preload("res://addons/simple_terrain/icons/axis_lock.svg")
const ICON_ASSET_PALETTE: Texture2D = preload("res://addons/simple_terrain/icons/asset_palette.svg")
const ICON_BRUSH_SHAPE: Texture2D = preload("res://addons/simple_terrain/icons/brush_shape.svg")
const ICON_SLOPE_LIMIT: Texture2D = preload("res://addons/simple_terrain/icons/slope_limit.svg")

const ICON_CLOSE: Texture2D = preload("res://addons/simple_terrain/icons/close.svg")
const ICON_FALLOFF_SMOOTH: Texture2D = preload("res://addons/simple_terrain/icons/falloff_smooth.svg")
const ICON_FALLOFF_LINEAR: Texture2D = preload("res://addons/simple_terrain/icons/falloff_linear.svg")
const ICON_FALLOFF_SPHERICAL: Texture2D = preload("res://addons/simple_terrain/icons/falloff_spherical.svg")
const ICON_FALLOFF_FLAT: Texture2D = preload("res://addons/simple_terrain/icons/falloff_flat.svg")

var _current_terrain: SimpleTerrain3D = null
var current_mode: ToolMode = ToolMode.VIEW
var current_sculpt_submode: int = SimpleTerrain3D.SculptMode.RAISE
var current_paint_submode: int = SimpleTerrain3D.PaintMode.COLOR
var current_foliage_submode: int = SimpleTerrain3D.FoliageBrushMode.PAINT
var current_foliage_layer_idx: int = 0
var current_sculpt_falloff: int = SimpleTerrain3D.FalloffType.SMOOTH
var current_paint_falloff: int = SimpleTerrain3D.FalloffType.SMOOTH

var current_brush_id: String = "circle_gradient"
var current_brush_name: String = "Circle Gradient"
var current_brush_path: String = "res://addons/simple_terrain/brushes/circle_gradient.png"
var current_brush_image: Image = null
var current_brush_texture: Texture2D = null
var current_brush_angle: float = 0.0
var current_min_slope_deg: float = 0.0
var current_max_slope_deg: float = 90.0

var loaded_stamp_image: Image = null
var loaded_stamp_texture: Texture2D = null
var loaded_mask_image: Image = null
var loaded_mask_texture: Texture2D = null
var is_picking_height: bool = false
var is_eraser_active: bool = false
var previous_paint_color: Color = PRESET_COLOR_GRASS

@onready var terrain_menu_btn: MenuButton = %TerrainMenuBtn
@onready var view_btn: Button = %ViewBtn
@onready var sculpt_btn: Button = %SculptBtn
@onready var paint_btn: Button = %PaintBtn
@onready var foliage_btn: Button = %FoliageBtn

@onready var row_separator: HSeparator = %RowSeparator
@onready var tool_options_row: HBoxContainer = %ToolOptionsRow

@onready var sculpt_container: HBoxContainer = %SculptContainer
@onready var sculpt_raise_btn: Button = %SculptRaiseBtn
@onready var sculpt_lower_btn: Button = %SculptLowerBtn
@onready var sculpt_smooth_btn: Button = %SculptSmoothBtn
@onready var sculpt_flatten_btn: Button = %SculptFlattenBtn
@onready var sculpt_noise_btn: Button = %SculptNoiseBtn
@onready var sculpt_terrace_btn: Button = %SculptTerraceBtn
@onready var sculpt_ramp_btn: Button = %SculptRampBtn

@onready var sculpt_size_scrubber: TerrainScrubber = %SculptSizeScrubber
@onready var sculpt_strength_scrubber: TerrainScrubber = %SculptStrengthScrubber
@onready var sculpt_falloff_btn: Button = %SculptFalloffBtn
@onready var flatten_box: HBoxContainer = %FlattenBox
@onready var flatten_height_scrubber: TerrainScrubber = %FlattenHeightScrubber
@onready var pick_height_btn: Button = %PickHeightBtn
@onready var terrace_box: HBoxContainer = %TerraceBox
@onready var terrace_step_scrubber: TerrainScrubber = %TerraceStepScrubber
@onready var ramp_box: HBoxContainer = %RampBox
@onready var ramp_width_scrubber: TerrainScrubber = %RampWidthScrubber
@onready var ramp_falloff_scrubber: TerrainScrubber = %RampFalloffScrubber
@onready var ramp_crown_scrubber: TerrainScrubber = %RampCrownScrubber
@onready var ramp_apply_btn: Button = %RampApplyBtn
@onready var ramp_clear_btn: Button = %RampClearBtn
@onready var context_sub_bar: PanelContainer = %ContextSubBar
@onready var sculpt_mask_btn: Button = %SculptMaskBtn
@onready var sculpt_mask_rect: TextureRect = %SculptMaskRect
@onready var sculpt_mask_angle_spin: SpinBox = %SculptMaskAngleSpinBox
@onready var sculpt_spacing_spin: SpinBox = %SculptSpacingSpinBox
@onready var sculpt_jitter_pos_spin: SpinBox = %SculptJitterPosSpinBox
@onready var sculpt_jitter_angle_spin: SpinBox = %SculptJitterAngleSpinBox
@onready var sculpt_auto_slope_btn: Button = %SculptAutoSlopeBtn
@onready var sculpt_slope_limit_btn: Button = %SculptSlopeLimitBtn
@onready var sculpt_dynamics_btn: Button = %SculptDynamicsBtn

@onready var paint_container: HBoxContainer = %PaintContainer
@onready var paint_color_picker: ColorPickerButton = %PaintColorPicker
@onready var eraser_btn: Button = %EraserBtn
@onready var pattern_preview_btn: Button = %PatternPreviewBtn
@onready var pattern_preview_rect: TextureRect = %PatternPreviewRect
@onready var brush_shape_btn: Button = %BrushShapeBtn
@onready var brush_shape_rect: TextureRect = %BrushShapeRect
@onready var slope_limit_btn: Button = %SlopeLimitBtn
@onready var paint_size_scrubber: TerrainScrubber = %PaintSizeScrubber
@onready var paint_strength_scrubber: TerrainScrubber = %PaintStrengthScrubber
@onready var paint_falloff_btn: Button = %PaintFalloffBtn
@onready var paint_spacing_spin: SpinBox = %PaintSpacingSpinBox
@onready var paint_jitter_pos_spin: SpinBox = %PaintJitterPosSpinBox
@onready var paint_jitter_angle_spin: SpinBox = %PaintJitterAngleSpinBox
@onready var paint_dynamics_btn: Button = %PaintDynamicsBtn
@onready var paint_auto_slope_btn: Button = %PaintAutoSlopeBtn

@onready var dynamics_popup: PopupPanel = %DynamicsPopup
@onready var sculpt_dynamics_box: VBoxContainer = %SculptDynamicsBox
@onready var paint_dynamics_box: VBoxContainer = %PaintDynamicsBox
@onready var reset_dynamics_btn: Button = %ResetDynamicsBtn

@onready var mask_popup: PopupPanel = %MaskPopup
@onready var mask_preview_rect: TextureRect = %MaskPreviewRect
@onready var mask_name_label: Label = %MaskNameLabel
@onready var mask_clear_btn: Button = %MaskClearBtn
@onready var mask_palette_btn: Button = %MaskPaletteBtn
@onready var mask_btn_rock: Button = %MaskBtnRock
@onready var mask_btn_cobble: Button = %MaskBtnCobble
@onready var mask_btn_gravel: Button = %MaskBtnGravel
@onready var mask_btn_grass: Button = %MaskBtnGrass
@onready var mask_btn_sand: Button = %MaskBtnSand
@onready var mask_btn_cracked: Button = %MaskBtnCracked
@onready var mask_btn_soft: Button = %MaskBtnSoft
@onready var mask_btn_splatter: Button = %MaskBtnSplatter

@onready var pattern_flyout_popup: PopupPanel = %PatternFlyoutPopup
@onready var flyout_pattern_preview_rect: TextureRect = %FlyoutPatternPreviewRect
@onready var flyout_pattern_name_label: Label = %FlyoutPatternNameLabel
@onready var flyout_pattern_clear_btn: Button = %FlyoutPatternClearBtn
@onready var flyout_tiling_spin: SpinBox = %FlyoutTilingSpin
@onready var flyout_angle_spin: SpinBox = %FlyoutAngleSpin
@onready var flyout_open_palette_btn: Button = %FlyoutOpenPaletteBtn
@onready var pat_btn_rock: Button = %PatBtnRock
@onready var pat_btn_cobble: Button = %PatBtnCobble
@onready var pat_btn_gravel: Button = %PatBtnGravel
@onready var pat_btn_grass: Button = %PatBtnGrass
@onready var pat_btn_sand: Button = %PatBtnSand
@onready var pat_btn_cracked: Button = %PatBtnCracked
@onready var pat_btn_soft: Button = %PatBtnSoft
@onready var pat_btn_splatter: Button = %PatBtnSplatter

@onready var brush_flyout_popup: PopupPanel = %BrushFlyoutPopup
@onready var flyout_brush_preview_rect: TextureRect = %FlyoutBrushPreviewRect
@onready var flyout_brush_name_label: Label = %FlyoutBrushNameLabel
@onready var flyout_brush_angle_spin: SpinBox = %FlyoutBrushAngleSpin
@onready var brush_btn_circle: Button = %BrushBtnCircle
@onready var brush_btn_square: Button = %BrushBtnSquare
@onready var brush_btn_patch: Button = %BrushBtnPatch
@onready var brush_btn_dots: Button = %BrushBtnDots
@onready var brush_btn_cross: Button = %BrushBtnCross
@onready var flyout_open_palette_brush_btn: Button = %FlyoutOpenPaletteBrushBtn

@onready var slope_limit_popup: PopupPanel = %SlopeLimitPopup
@onready var slope_min_spin: SpinBox = %SlopeMinSpin
@onready var slope_max_spin: SpinBox = %SlopeMaxSpin
@onready var slope_preset_all_btn: Button = %SlopePresetAllBtn
@onready var slope_preset_flat_btn: Button = %SlopePresetFlatBtn
@onready var slope_preset_cliffs_btn: Button = %SlopePresetCliffsBtn
@onready var slope_reset_btn: Button = %SlopeResetBtn
@onready var custom_brush_file_dialog: FileDialog = %CustomBrushFileDialog

var current_pattern_tiling: float = 8.0
var current_pattern_angle: float = 0.0

@onready var foliage_container: HBoxContainer = %FoliageContainer
@onready var foliage_paint_btn: Button = %FoliagePaintBtn
@onready var foliage_erase_btn: Button = %FoliageEraseBtn
@onready var foliage_select_btn: Button = %FoliageSelectBtn

@onready var foliage_brush_box: HBoxContainer = %FoliageBrushBox
@onready var foliage_size_scrubber: TerrainScrubber = %FoliageSizeScrubber

@onready var foliage_instance_box: HBoxContainer = %FoliageInstanceBox
@onready var foliage_selected_label: Label = %FoliageSelectedLabel
@onready var foliage_pos_x_spin: SpinBox = %FoliagePosXSpin
@onready var foliage_pos_y_spin: SpinBox = %FoliagePosYSpin
@onready var foliage_pos_z_spin: SpinBox = %FoliagePosZSpin
@onready var foliage_yaw_spin: SpinBox = %FoliageYawSpin
@onready var foliage_scale_spin: SpinBox = %FoliageScaleSpin
@onready var foliage_align_surface_btn: Button = %FoliageAlignSurfaceBtn
@onready var foliage_delete_inst_btn: Button = %FoliageDeleteInstBtn
@onready var foliage_deselect_btn: Button = %FoliageDeselectBtn

var _selected_inst_layer: int = -1
var _selected_inst_idx: int = -1
var _selected_inst_transform: Transform3D = Transform3D.IDENTITY
var _updating_inst_spins: bool = false

@onready var wireframe_btn: Button = %WireframeBtn
@onready var hud_btn: Button = %HudBtn
@onready var axis_lock_btn: Button = %AxisLockBtn
@onready var asset_dock_btn: Button = %AssetDockBtn
@onready var export_menu_btn: MenuButton = %ExportMenuBtn
@onready var save_data_warning_btn: Button = %SaveDataWarningBtn
@onready var help_btn: Button = %HelpBtn

var current_terrain_size: Vector2 = Vector2(64.0, 64.0)
var current_terrain_res: Vector2i = Vector2i(64, 64)

@onready var resize_terrain_dialog: ConfirmationDialog = %ResizeTerrainDialog
@onready var resize_size_x_spin: SpinBox = %ResizeSizeXSpin
@onready var resize_size_z_spin: SpinBox = %ResizeSizeZSpin
@onready var resize_res_x_spin: SpinBox = %ResizeResXSpin
@onready var resize_res_z_spin: SpinBox = %ResizeResZSpin

@onready var new_terrain_dialog: ConfirmationDialog = %NewTerrainDialog
@onready var new_size_x_spin: SpinBox = %NewSizeXSpin
@onready var new_size_z_spin: SpinBox = %NewSizeZSpin
@onready var new_res_x_spin: SpinBox = %NewResXSpin
@onready var new_res_z_spin: SpinBox = %NewResZSpin
@onready var new_tex_option: OptionButton = %NewTexOption
@onready var new_base_color_picker: ColorPickerButton = %NewBaseColorPicker

@onready var noise_dialog: TerrainNoiseDialog = %NoiseDialog
@onready var shortcuts_dialog: AcceptDialog = %ShortcutsDialog
@onready var slope_dialog: TerrainSlopeDialog = %SlopeDialog

@onready var save_mesh_dialog: FileDialog = %SaveMeshDialog
@onready var save_gltf_dialog: FileDialog = %SaveGltfDialog
@onready var save_texture_dialog: FileDialog = %SaveTextureDialog
@onready var save_data_dialog: FileDialog = %SaveDataDialog



func _ready() -> void:
	_setup_icons_and_menus()
	_connect_signals()
	_update_falloff_ui()
	_style_segmented_groups()
	_restore_brush_if_available()
	var saved_slopes: Vector2 = SimpleTerrainSettings.get_slope_limits()
	set_slope_limits(saved_slopes.x, saved_slopes.y)
	_update_ui_state()
	_strip_button_focus(self)


func _strip_button_focus(p_node: Node) -> void:
	if p_node is BaseButton:
		p_node.focus_mode = Control.FOCUS_NONE
	for child in p_node.get_children():
		if not (child is Window):
			_strip_button_focus(child)


static func get_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res as Texture2D
	var real_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(real_path):
		var img: Image = Image.load_from_file(real_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _style_segmented_groups() -> void:
	var groups: Array[Node] = [
		get_node_or_null("%ModeBox"),
		get_node_or_null("%SculptSubmodesBox"),
		get_node_or_null("%FoliageSubmodesBox")
	]
	for grp in groups:
		if grp is BoxContainer:
			grp.add_theme_constant_override("separation", 1)


func _get_falloff_icon(falloff: int) -> Texture2D:
	match falloff:
		SimpleTerrain3D.FalloffType.LINEAR:
			return ICON_FALLOFF_LINEAR
		SimpleTerrain3D.FalloffType.SPHERICAL:
			return ICON_FALLOFF_SPHERICAL
		SimpleTerrain3D.FalloffType.FLAT:
			return ICON_FALLOFF_FLAT
		_:
			return ICON_FALLOFF_SMOOTH


func _get_falloff_name(falloff: int) -> String:
	match falloff:
		SimpleTerrain3D.FalloffType.LINEAR:
			return "Linear (Cone)"
		SimpleTerrain3D.FalloffType.SPHERICAL:
			return "Spherical (Dome)"
		SimpleTerrain3D.FalloffType.FLAT:
			return "Flat (Hard Edge)"
		_:
			return "Smooth (Cosine Curve)"


func _update_falloff_ui() -> void:
	if sculpt_falloff_btn != null:
		sculpt_falloff_btn.icon = _get_falloff_icon(current_sculpt_falloff)
		sculpt_falloff_btn.tooltip_text = "Sculpt Falloff: %s\nClick to cycle (Smooth -> Linear -> Spherical -> Flat)" % _get_falloff_name(current_sculpt_falloff)
	if paint_falloff_btn != null:
		paint_falloff_btn.icon = _get_falloff_icon(current_paint_falloff)
		paint_falloff_btn.tooltip_text = "Paint Falloff: %s\nClick to cycle (Smooth -> Linear -> Spherical -> Flat)" % _get_falloff_name(current_paint_falloff)


func _cycle_sculpt_falloff() -> void:
	current_sculpt_falloff = (current_sculpt_falloff + 1) % 4
	_update_falloff_ui()
	_notify_sculpt_changed()


func _cycle_paint_falloff() -> void:
	current_paint_falloff = (current_paint_falloff + 1) % 4
	_update_falloff_ui()
	_notify_paint_changed()


func _setup_icons_and_menus() -> void:
	view_btn.icon = ICON_VIEW
	sculpt_btn.icon = ICON_SCULPT
	paint_btn.icon = ICON_PAINT
	foliage_btn.icon = get_icon("res://addons/simple_terrain/icons/mode_foliage.svg")
	terrain_menu_btn.icon = ICON_TERRAIN_MENU
	export_menu_btn.icon = ICON_SAVE
	save_data_warning_btn.icon = ICON_SAVE_DATA
	wireframe_btn.icon = ICON_WIREFRAME
	hud_btn.icon = ICON_HUD
	axis_lock_btn.icon = ICON_AXIS_LOCK
	asset_dock_btn.icon = ICON_ASSET_PALETTE
	pick_height_btn.icon = ICON_EYEDROPPER
	eraser_btn.icon = ICON_ERASER
	help_btn.icon = ICON_HELP
	sculpt_auto_slope_btn.icon = ICON_SLOPE_COLOR
	paint_auto_slope_btn.icon = ICON_SLOPE_COLOR
	if brush_shape_btn != null:
		brush_shape_btn.icon = ICON_BRUSH_SHAPE
	if slope_limit_btn != null:
		slope_limit_btn.icon = ICON_SLOPE_LIMIT
	if sculpt_slope_limit_btn != null:
		sculpt_slope_limit_btn.icon = ICON_SLOPE_LIMIT

	foliage_paint_btn.icon = get_icon("res://addons/simple_terrain/icons/foliage_paint.svg")
	foliage_erase_btn.icon = get_icon("res://addons/simple_terrain/icons/foliage_erase.svg")
	foliage_select_btn.icon = get_icon("res://addons/simple_terrain/icons/foliage_select.svg")
	foliage_deselect_btn.icon = ICON_CLOSE

	sculpt_raise_btn.icon = ICON_SCULPT_RAISE

	sculpt_lower_btn.icon = ICON_SCULPT_LOWER
	sculpt_smooth_btn.icon = ICON_SCULPT_SMOOTH
	sculpt_flatten_btn.icon = ICON_SCULPT_FLATTEN
	sculpt_noise_btn.icon = ICON_SCULPT_NOISE
	sculpt_terrace_btn.icon = ICON_SCULPT_TERRACE
	sculpt_ramp_btn.icon = ICON_SCULPT_RAMP
	sculpt_mask_btn.icon = ICON_SCULPT_MASK
	sculpt_dynamics_btn.icon = ICON_BRUSH_JITTER
	paint_dynamics_btn.icon = ICON_BRUSH_JITTER

	var t_pop: PopupMenu = terrain_menu_btn.get_popup()
	t_pop.clear()
	t_pop.add_icon_item(ICON_NEW_TERRAIN, "Resize Terrain...", 0)
	t_pop.add_icon_item(ICON_NEW_TERRAIN, "New Terrain...", 1)
	t_pop.add_icon_item(ICON_NOISE_GEN, "Generate Procedural Noise...", 2)
	t_pop.add_separator()
	t_pop.add_icon_item(ICON_SCULPT_FLATTEN, "Flatten All Heights to 0", 3)
	t_pop.add_icon_item(ICON_ERASER, "Clear Texture to Base Color", 4)
	t_pop.add_icon_item(ICON_SLOPE_COLOR, "Auto Color Slopes...", 5)
	t_pop.add_icon_item(get_icon("res://addons/simple_terrain/icons/foliage_library.svg"), "Foliage & Prop Library...", 6)
	t_pop.id_pressed.connect(_on_terrain_menu_selected)

	var e_pop: PopupMenu = export_menu_btn.get_popup()
	e_pop.clear()
	e_pop.add_icon_item(ICON_SAVE_DATA, "Save Terrain Data (*.res, *.tres)...", 0)
	e_pop.add_icon_item(ICON_EXPORT_GLTF, "Export Terrain as glTF (*.glb, *.gltf)...", 1)
	e_pop.add_icon_item(ICON_SAVE_MESH, "Export Terrain Mesh (*.tres, *.res)...", 2)
	e_pop.add_icon_item(ICON_SAVE_TEXTURE, "Export Terrain Texture (*.png)...", 3)
	e_pop.id_pressed.connect(_on_export_menu_selected)

	if new_tex_option.item_count == 0:
		new_tex_option.add_item("512 x 512", 512)
		new_tex_option.add_item("1024 x 1024", 1024)
		new_tex_option.add_item("2048 x 2048", 2048)
		new_tex_option.select(1)


func _connect_signals() -> void:
	view_btn.pressed.connect(func() -> void: set_mode(ToolMode.VIEW))
	sculpt_btn.pressed.connect(func() -> void: set_mode(ToolMode.SCULPT))
	paint_btn.pressed.connect(func() -> void: set_mode(ToolMode.PAINT))
	foliage_btn.pressed.connect(func() -> void:
		set_mode(ToolMode.FOLIAGE)
		open_asset_dock_requested.emit(0)
	)

	sculpt_raise_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.RAISE))
	sculpt_lower_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.LOWER))
	sculpt_smooth_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.SMOOTH))
	sculpt_flatten_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.FLATTEN))
	sculpt_noise_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.NOISE))
	sculpt_terrace_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.TERRACE))
	sculpt_ramp_btn.pressed.connect(func() -> void: set_sculpt_submode(SimpleTerrain3D.SculptMode.RAMP))
	ramp_apply_btn.pressed.connect(func() -> void: ramp_apply_requested.emit())
	ramp_clear_btn.pressed.connect(func() -> void: ramp_clear_requested.emit())
	sculpt_mask_btn.pressed.connect(_open_mask_popup)
	sculpt_mask_angle_spin.value_changed.connect(func(_v: float) -> void: _notify_mask_changed())
	terrace_step_scrubber.value_changed.connect(func(_val: float) -> void: _notify_sculpt_changed())

	sculpt_size_scrubber.value_changed.connect(func(_val: float) -> void: _notify_sculpt_changed())
	sculpt_strength_scrubber.value_changed.connect(func(_val: float) -> void: _notify_sculpt_changed())
	sculpt_falloff_btn.pressed.connect(_cycle_sculpt_falloff)
	flatten_height_scrubber.value_changed.connect(func(_val: float) -> void: _notify_sculpt_changed())
	pick_height_btn.toggled.connect(_on_pick_height_toggled)

	sculpt_dynamics_btn.pressed.connect(func() -> void: _open_dynamics_popup(sculpt_dynamics_btn, true))
	paint_dynamics_btn.pressed.connect(func() -> void: _open_dynamics_popup(paint_dynamics_btn, false))
	reset_dynamics_btn.pressed.connect(_on_reset_dynamics_pressed)

	sculpt_spacing_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())
	sculpt_jitter_pos_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())
	sculpt_jitter_angle_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())
	paint_spacing_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())
	paint_jitter_pos_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())
	paint_jitter_angle_spin.value_changed.connect(func(_v: float) -> void: _update_dynamics_indicators())

	mask_clear_btn.pressed.connect(func() -> void:
		set_active_sculpt_mask(null, "None", "")
		if mask_popup != null:
			mask_popup.hide()
	)
	mask_palette_btn.pressed.connect(func() -> void:
		if mask_popup != null:
			mask_popup.hide()
		open_asset_dock_requested.emit(1)
	)

	mask_btn_rock.pressed.connect(func() -> void: _load_stencil_preset("rock_cliff.png", "Rock Cliff"))
	mask_btn_cobble.pressed.connect(func() -> void: _load_stencil_preset("cobblestone.png", "Cobblestone"))
	mask_btn_gravel.pressed.connect(func() -> void: _load_stencil_preset("dirt_gravel.png", "Dirt Gravel"))
	mask_btn_grass.pressed.connect(func() -> void: _load_stencil_preset("grass_blades.png", "Grass Blades"))
	mask_btn_sand.pressed.connect(func() -> void: _load_stencil_preset("sand_ripples.png", "Sand Ripples"))
	mask_btn_cracked.pressed.connect(func() -> void: _load_stencil_preset("cracked_earth.png", "Cracked Earth"))
	mask_btn_soft.pressed.connect(func() -> void: _load_stencil_preset("soft_radial.png", "Soft Radial"))
	mask_btn_splatter.pressed.connect(func() -> void: _load_stencil_preset("splatter_grunge.png", "Splatter Grunge"))

	pattern_preview_btn.pressed.connect(_open_pattern_flyout)
	flyout_pattern_clear_btn.pressed.connect(_on_flyout_pattern_clear_pressed)
	flyout_tiling_spin.value_changed.connect(func(v: float) -> void: set_pattern_settings(v, current_pattern_angle))
	flyout_angle_spin.value_changed.connect(func(v: float) -> void: set_pattern_settings(current_pattern_tiling, v))
	flyout_open_palette_btn.pressed.connect(_on_flyout_open_palette_pressed)

	pat_btn_rock.pressed.connect(func() -> void: _load_pattern_preset("rock_cliff.png", "Rock Cliff"))
	pat_btn_cobble.pressed.connect(func() -> void: _load_pattern_preset("cobblestone.png", "Cobblestone"))
	pat_btn_gravel.pressed.connect(func() -> void: _load_pattern_preset("dirt_gravel.png", "Dirt Gravel"))
	pat_btn_grass.pressed.connect(func() -> void: _load_pattern_preset("grass_blades.png", "Grass Blades"))
	pat_btn_sand.pressed.connect(func() -> void: _load_pattern_preset("sand_ripples.png", "Sand Ripples"))
	pat_btn_cracked.pressed.connect(func() -> void: _load_pattern_preset("cracked_earth.png", "Cracked Earth"))
	pat_btn_soft.pressed.connect(func() -> void: _load_pattern_preset("soft_radial.png", "Soft Radial"))
	pat_btn_splatter.pressed.connect(func() -> void: _load_pattern_preset("splatter_grunge.png", "Splatter Grunge"))

	brush_shape_btn.pressed.connect(_open_brush_flyout)
	flyout_brush_angle_spin.value_changed.connect(_on_brush_angle_changed)
	flyout_open_palette_brush_btn.pressed.connect(_on_flyout_open_palette_brush_pressed)

	brush_btn_circle.pressed.connect(func() -> void: select_brush_shape("circle_gradient"))
	brush_btn_square.pressed.connect(func() -> void: select_brush_shape("square"))
	brush_btn_patch.pressed.connect(func() -> void: select_brush_shape("patch"))
	brush_btn_dots.pressed.connect(func() -> void: select_brush_shape("small_dots"))
	brush_btn_cross.pressed.connect(func() -> void: select_brush_shape("x_gradient"))

	slope_limit_btn.pressed.connect(func() -> void: _open_slope_limit_popup(slope_limit_btn))
	sculpt_slope_limit_btn.pressed.connect(func() -> void: _open_slope_limit_popup(sculpt_slope_limit_btn))
	slope_min_spin.value_changed.connect(_on_slope_spin_changed)
	slope_max_spin.value_changed.connect(_on_slope_spin_changed)
	slope_preset_all_btn.pressed.connect(func() -> void: set_slope_limits(0.0, 90.0))
	slope_preset_flat_btn.pressed.connect(func() -> void: set_slope_limits(0.0, 30.0))
	slope_preset_cliffs_btn.pressed.connect(func() -> void: set_slope_limits(35.0, 90.0))
	slope_reset_btn.pressed.connect(func() -> void: set_slope_limits(0.0, 90.0))
	custom_brush_file_dialog.file_selected.connect(_on_custom_brush_file_selected)

	paint_size_scrubber.value_changed.connect(func(_val: float) -> void: _notify_paint_changed())
	paint_strength_scrubber.value_changed.connect(func(_val: float) -> void: _notify_paint_changed())
	paint_falloff_btn.pressed.connect(_cycle_paint_falloff)

	foliage_paint_btn.pressed.connect(func() -> void:
		set_foliage_submode(SimpleTerrain3D.FoliageBrushMode.PAINT)
	)
	foliage_erase_btn.pressed.connect(func() -> void: set_foliage_submode(SimpleTerrain3D.FoliageBrushMode.ERASE))
	foliage_select_btn.pressed.connect(func() -> void: set_foliage_submode(SimpleTerrain3D.FoliageBrushMode.SELECT))

	foliage_pos_x_spin.value_changed.connect(func(_v: float) -> void: _on_inst_spin_changed())
	foliage_pos_y_spin.value_changed.connect(func(_v: float) -> void: _on_inst_spin_changed())
	foliage_pos_z_spin.value_changed.connect(func(_v: float) -> void: _on_inst_spin_changed())
	foliage_yaw_spin.value_changed.connect(func(_v: float) -> void: _on_inst_spin_changed())
	foliage_scale_spin.value_changed.connect(func(_v: float) -> void: _on_inst_spin_changed())

	foliage_align_surface_btn.pressed.connect(func() -> void:
		if _selected_inst_idx >= 0:
			foliage_instance_align_requested.emit(_selected_inst_layer, _selected_inst_idx)
	)
	foliage_delete_inst_btn.pressed.connect(func() -> void:
		if _selected_inst_idx >= 0:
			foliage_instance_delete_requested.emit(_selected_inst_layer, _selected_inst_idx)
	)
	foliage_deselect_btn.pressed.connect(func() -> void:
		foliage_instance_deselect_requested.emit()
	)

	foliage_size_scrubber.value_changed.connect(func(_val: float) -> void: _notify_foliage_changed())

	resize_terrain_dialog.confirmed.connect(_on_resize_terrain_confirmed)
	new_terrain_dialog.confirmed.connect(_on_new_terrain_confirmed)
	noise_dialog.generate_noise_requested.connect(func(noise: FastNoiseLite, amp: float, flatten_edges: bool) -> void:
		generate_noise_requested.emit(noise, amp, flatten_edges)
	)

	save_mesh_dialog.file_selected.connect(func(path: String) -> void: save_mesh_requested.emit(path))
	save_gltf_dialog.file_selected.connect(func(path: String) -> void: export_gltf_requested.emit(path))
	save_texture_dialog.file_selected.connect(func(path: String) -> void: save_texture_requested.emit(path))
	save_data_dialog.file_selected.connect(func(path: String) -> void: save_data_requested.emit(path))
	save_data_warning_btn.pressed.connect(func() -> void: open_save_data_dialog())

	paint_color_picker.pressed.connect(func() -> void:
		set_paint_submode(SimpleTerrain3D.PaintMode.COLOR)
		if is_eraser_active:
			eraser_btn.button_pressed = false
	)
	paint_color_picker.color_changed.connect(func(_col: Color) -> void:
		set_paint_submode(SimpleTerrain3D.PaintMode.COLOR)
		if is_eraser_active:
			eraser_btn.button_pressed = false
		_notify_paint_changed()
	)
	asset_dock_btn.pressed.connect(func() -> void:
		if asset_dock_btn.button_pressed:
			open_asset_dock_requested.emit(0 if current_mode == ToolMode.FOLIAGE else 1)
		else:
			close_asset_dock_requested.emit()
	)

	eraser_btn.toggled.connect(_on_eraser_toggled)
	wireframe_btn.toggled.connect(func(active: bool) -> void: wireframe_toggled.emit(active))
	hud_btn.toggled.connect(func(active: bool) -> void: hud_toggled.emit(active))
	axis_lock_btn.pressed.connect(func() -> void: axis_lock_cycle_requested.emit())

	sculpt_auto_slope_btn.toggled.connect(func(active: bool) -> void:
		auto_slope_sculpt_toggled.emit(active)
		if slope_dialog != null:
			slope_dialog.set_auto_sculpt_active(active)
	)
	paint_auto_slope_btn.pressed.connect(open_slope_dialog)
	slope_dialog.apply_slope_requested.connect(func(
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
		apply_slope_requested.emit(
			cliff_mode,
			cliff_color,
			cliff_texture,
			cliff_image,
			cliff_tiling,
			threshold_deg,
			blend_deg,
			keep_flat_paint,
			ground_color,
			auto_slope_sculpt
		)
	)
	slope_dialog.auto_slope_sculpt_toggled.connect(func(active: bool) -> void:
		set_auto_slope_sculpt_active(active)
		auto_slope_sculpt_toggled.emit(active)
	)

	help_btn.pressed.connect(func() -> void: shortcuts_dialog.popup_centered(Vector2i(560, 460)))


func set_wireframe_active(active: bool) -> void:
	if wireframe_btn != null and wireframe_btn.button_pressed != active:
		wireframe_btn.button_pressed = active


func set_hud_active(active: bool) -> void:
	if hud_btn != null and hud_btn.button_pressed != active:
		hud_btn.button_pressed = active


func set_axis_lock_state(lock_str: String) -> void:
	if axis_lock_btn != null:
		if lock_str != "None":
			axis_lock_btn.tooltip_text = "Axis Lock: %s [Shortcut: X/Z to change, C to clear]" % lock_str
			axis_lock_btn.modulate = Color(1.0, 0.85, 0.3)
		else:
			axis_lock_btn.tooltip_text = "Cycle Axis Lock Constraint (X / Z / Off) [Shortcut: X or Z, Clear: C]"
			axis_lock_btn.modulate = Color.WHITE


func set_mode(mode: ToolMode) -> void:
	current_mode = mode
	_update_ui_state()
	mode_changed.emit(current_mode)
	if current_mode == ToolMode.SCULPT:
		_notify_sculpt_changed()
	elif current_mode == ToolMode.PAINT:
		_notify_paint_changed()
	elif current_mode == ToolMode.FOLIAGE:
		_notify_foliage_changed()


func set_sculpt_submode(submode: int) -> void:
	current_sculpt_submode = submode
	sculpt_raise_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.RAISE)
	sculpt_lower_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.LOWER)
	sculpt_smooth_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.SMOOTH)
	sculpt_flatten_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.FLATTEN)
	sculpt_noise_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.NOISE)
	if sculpt_terrace_btn != null:
		sculpt_terrace_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.TERRACE)
	if sculpt_ramp_btn != null:
		sculpt_ramp_btn.button_pressed = (submode == SimpleTerrain3D.SculptMode.RAMP)

	flatten_box.visible = (submode == SimpleTerrain3D.SculptMode.FLATTEN)
	if terrace_box != null:
		terrace_box.visible = (submode == SimpleTerrain3D.SculptMode.TERRACE)
	var is_ramp: bool = (submode == SimpleTerrain3D.SculptMode.RAMP)
	if ramp_box != null:
		ramp_box.visible = is_ramp
	if context_sub_bar != null:
		context_sub_bar.visible = is_ramp
	_notify_sculpt_changed()


func set_paint_submode(submode: int) -> void:
	current_paint_submode = submode
	if pattern_preview_btn != null:
		pattern_preview_btn.button_pressed = (submode == SimpleTerrain3D.PaintMode.TEXTURE)
	_notify_paint_changed()


func _update_ui_state() -> void:
	view_btn.button_pressed = (current_mode == ToolMode.VIEW)
	sculpt_btn.button_pressed = (current_mode == ToolMode.SCULPT)
	paint_btn.button_pressed = (current_mode == ToolMode.PAINT)
	foliage_btn.button_pressed = (current_mode == ToolMode.FOLIAGE)

	var has_tool_options: bool = (current_mode == ToolMode.SCULPT or current_mode == ToolMode.PAINT or current_mode == ToolMode.FOLIAGE)
	if row_separator != null:
		row_separator.visible = has_tool_options
	if tool_options_row != null:
		tool_options_row.visible = has_tool_options

	sculpt_container.visible = (current_mode == ToolMode.SCULPT)
	paint_container.visible = (current_mode == ToolMode.PAINT)
	foliage_container.visible = (current_mode == ToolMode.FOLIAGE)

	sculpt_raise_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.RAISE)
	sculpt_lower_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.LOWER)
	sculpt_smooth_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.SMOOTH)
	sculpt_flatten_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.FLATTEN)
	sculpt_noise_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.NOISE)
	if sculpt_terrace_btn != null:
		sculpt_terrace_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.TERRACE)
	if sculpt_ramp_btn != null:
		sculpt_ramp_btn.button_pressed = (current_sculpt_submode == SimpleTerrain3D.SculptMode.RAMP)

	if pattern_preview_btn != null:
		pattern_preview_btn.button_pressed = (current_paint_submode == SimpleTerrain3D.PaintMode.TEXTURE)

	foliage_paint_btn.button_pressed = (current_foliage_submode == SimpleTerrain3D.FoliageBrushMode.PAINT)
	foliage_erase_btn.button_pressed = (current_foliage_submode == SimpleTerrain3D.FoliageBrushMode.ERASE)
	foliage_select_btn.button_pressed = (current_foliage_submode == SimpleTerrain3D.FoliageBrushMode.SELECT)

	foliage_brush_box.visible = (current_foliage_submode != SimpleTerrain3D.FoliageBrushMode.SELECT)
	foliage_instance_box.visible = (current_foliage_submode == SimpleTerrain3D.FoliageBrushMode.SELECT)

	flatten_box.visible = (current_sculpt_submode == SimpleTerrain3D.SculptMode.FLATTEN)
	if terrace_box != null:
		terrace_box.visible = (current_sculpt_submode == SimpleTerrain3D.SculptMode.TERRACE)
	var is_ramp_active: bool = (current_mode == ToolMode.SCULPT and current_sculpt_submode == SimpleTerrain3D.SculptMode.RAMP)
	if ramp_box != null:
		ramp_box.visible = is_ramp_active
	if context_sub_bar != null:
		context_sub_bar.visible = is_ramp_active

	_update_dynamics_indicators()


func set_current_terrain_info(size: Vector2, res: Vector2i) -> void:
	current_terrain_size = size
	current_terrain_res = res


func open_resize_dialog() -> void:
	if resize_size_x_spin != null:
		resize_size_x_spin.value = current_terrain_size.x
	if resize_size_z_spin != null:
		resize_size_z_spin.value = current_terrain_size.y
	if resize_res_x_spin != null:
		resize_res_x_spin.value = current_terrain_res.x
	if resize_res_z_spin != null:
		resize_res_z_spin.value = current_terrain_res.y
	resize_terrain_dialog.popup_centered(Vector2i(420, 240))


func _on_resize_terrain_confirmed() -> void:
	var size: Vector2 = Vector2(float(resize_size_x_spin.value), float(resize_size_z_spin.value))
	var res: Vector2i = Vector2i(int(resize_res_x_spin.value), int(resize_res_z_spin.value))
	resize_terrain_requested.emit(size, res)


func _on_terrain_menu_selected(id: int) -> void:
	match id:
		0:
			open_resize_dialog()
		1:
			if new_size_x_spin != null:
				new_size_x_spin.value = current_terrain_size.x
			if new_size_z_spin != null:
				new_size_z_spin.value = current_terrain_size.y
			if new_res_x_spin != null:
				new_res_x_spin.value = current_terrain_res.x
			if new_res_z_spin != null:
				new_res_z_spin.value = current_terrain_res.y
			new_terrain_dialog.popup_centered(Vector2i(380, 290))
		2:
			noise_dialog.open_dialog()
		3:
			flatten_all_requested.emit()
		4:
			clear_texture_requested.emit()
		5:
			open_slope_dialog()
		6:
			open_foliage_dialog()


func _on_export_menu_selected(id: int) -> void:
	match id:
		0:
			open_save_data_dialog()
		1:
			save_gltf_dialog.popup_centered(Vector2i(900, 580))
		2:
			save_mesh_dialog.popup_centered(Vector2i(900, 580))
		3:
			save_texture_dialog.popup_centered(Vector2i(900, 580))


func set_embedded_warning(is_embedded: bool) -> void:
	if save_data_warning_btn != null:
		save_data_warning_btn.visible = is_embedded


func open_save_data_dialog(default_name: String = "terrain_data.res") -> void:
	if save_data_dialog != null:
		save_data_dialog.current_file = default_name
		save_data_dialog.popup_centered(Vector2i(900, 580))


func _set_paint_color(color: Color) -> void:
	if is_eraser_active:
		eraser_btn.button_pressed = false
	paint_color_picker.color = color
	_notify_paint_changed()


func _on_eraser_toggled(active: bool) -> void:
	is_eraser_active = active
	if active:
		previous_paint_color = paint_color_picker.color
		paint_color_picker.color = SimpleTerrainData.DEFAULT_BASE_COLOR
	else:
		paint_color_picker.color = previous_paint_color
	_notify_paint_changed()


func _on_pick_height_toggled(active: bool) -> void:
	is_picking_height = active
	pick_height_mode_toggled.emit(active)


func set_flatten_target_height(h: float) -> void:
	if flatten_height_scrubber != null:
		flatten_height_scrubber.value = h
	if is_picking_height:
		pick_height_btn.button_pressed = false
	_notify_sculpt_changed()


func _on_pattern_selected(img: Image, p_name: String, path: String) -> void:
	if current_mode == ToolMode.SCULPT:
		set_active_sculpt_mask(img, p_name, path)
	else:
		set_active_pattern(img, p_name, path)


func set_active_pattern(img: Image, p_name: String, path: String) -> void:
	loaded_stamp_image = img
	if img != null and not img.is_empty():
		loaded_stamp_texture = ImageTexture.create_from_image(img)
	else:
		loaded_stamp_texture = null
	if pattern_preview_rect != null:
		pattern_preview_rect.texture = loaded_stamp_texture
	if pattern_preview_btn != null:
		pattern_preview_btn.tooltip_text = "Active Pattern: %s\nClick for Quick Stamp Flyout / Dock" % (p_name if not p_name.is_empty() else "None")
	if flyout_pattern_preview_rect != null:
		flyout_pattern_preview_rect.texture = loaded_stamp_texture
	if flyout_pattern_name_label != null:
		flyout_pattern_name_label.text = p_name if not p_name.is_empty() else "None (No Texture)"
	if not path.is_empty():
		SimpleTerrainSettings.save_last_pattern_path(path)
	_notify_paint_changed()


func _open_pattern_flyout() -> void:
	if pattern_flyout_popup == null or pattern_preview_btn == null:
		return
	if flyout_pattern_preview_rect != null:
		flyout_pattern_preview_rect.texture = loaded_stamp_texture
	if flyout_pattern_name_label != null:
		flyout_pattern_name_label.text = pattern_preview_btn.tooltip_text.split("\n")[0].replace("Active Pattern: ", "")
	if flyout_tiling_spin != null:
		flyout_tiling_spin.set_value_no_signal(current_pattern_tiling)
	if flyout_angle_spin != null:
		flyout_angle_spin.set_value_no_signal(current_pattern_angle)
	var btn_pos: Vector2 = pattern_preview_btn.global_position
	var btn_sz: Vector2 = pattern_preview_btn.size
	var popup_pos: Vector2i = Vector2i(int(btn_pos.x), int(btn_pos.y + btn_sz.y + 4.0))
	pattern_flyout_popup.popup(Rect2i(popup_pos, pattern_flyout_popup.size))


func _load_pattern_preset(pattern_file: String, pattern_title: String) -> void:
	var path: String = "res://addons/simple_terrain/patterns/" + pattern_file
	var real_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(real_path):
		var img: Image = Image.load_from_file(real_path)
		if img != null and not img.is_empty():
			set_active_pattern(img, pattern_title, path)
			if flyout_pattern_preview_rect != null:
				flyout_pattern_preview_rect.texture = loaded_stamp_texture
			if flyout_pattern_name_label != null:
				flyout_pattern_name_label.text = pattern_title


func _on_flyout_pattern_clear_pressed() -> void:
	set_active_pattern(null, "None", "")
	if flyout_pattern_preview_rect != null:
		flyout_pattern_preview_rect.texture = null
	if flyout_pattern_name_label != null:
		flyout_pattern_name_label.text = "None (No Texture)"
	if pattern_flyout_popup != null:
		pattern_flyout_popup.hide()


func _on_flyout_open_palette_pressed() -> void:
	if pattern_flyout_popup != null:
		pattern_flyout_popup.hide()
	open_asset_dock_requested.emit(1)


func _open_brush_flyout() -> void:
	if brush_flyout_popup == null or brush_shape_btn == null:
		return
	if flyout_brush_preview_rect != null:
		flyout_brush_preview_rect.texture = current_brush_texture
	if flyout_brush_name_label != null:
		flyout_brush_name_label.text = current_brush_name
	if flyout_brush_angle_spin != null:
		flyout_brush_angle_spin.set_value_no_signal(current_brush_angle)
	var btn_pos: Vector2 = brush_shape_btn.global_position
	var btn_sz: Vector2 = brush_shape_btn.size
	var popup_pos: Vector2i = Vector2i(int(btn_pos.x), int(btn_pos.y + btn_sz.y + 4.0))
	brush_flyout_popup.popup(Rect2i(popup_pos, brush_flyout_popup.size))


func _on_brush_angle_changed(value: float) -> void:
	set_brush_angle(value)


func _on_flyout_open_palette_brush_pressed() -> void:
	if brush_flyout_popup != null:
		brush_flyout_popup.hide()
	open_asset_dock_requested.emit(1)


func _open_slope_limit_popup(anchor_btn: Button) -> void:
	if slope_limit_popup == null or anchor_btn == null:
		return
	if slope_min_spin != null:
		slope_min_spin.set_value_no_signal(current_min_slope_deg)
	if slope_max_spin != null:
		slope_max_spin.set_value_no_signal(current_max_slope_deg)
	var btn_pos: Vector2 = anchor_btn.global_position
	var btn_sz: Vector2 = anchor_btn.size
	var popup_pos: Vector2i = Vector2i(int(btn_pos.x), int(btn_pos.y + btn_sz.y + 4.0))
	slope_limit_popup.popup(Rect2i(popup_pos, slope_limit_popup.size))


func _on_slope_spin_changed(_val: float) -> void:
	var min_deg: float = float(slope_min_spin.value) if slope_min_spin != null else 0.0
	var max_deg: float = float(slope_max_spin.value) if slope_max_spin != null else 90.0
	if min_deg > max_deg:
		if slope_min_spin != null and slope_min_spin.has_focus():
			max_deg = min_deg
			if slope_max_spin != null:
				slope_max_spin.set_value_no_signal(max_deg)
		elif slope_max_spin != null and slope_max_spin.has_focus():
			min_deg = max_deg
			if slope_min_spin != null:
				slope_min_spin.set_value_no_signal(min_deg)
	set_slope_limits(min_deg, max_deg)


func select_brush_shape(brush_id: String, emit_signal_change: bool = true) -> void:
	if current_brush_id == brush_id and current_brush_image != null and current_brush_texture != null:
		if emit_signal_change:
			brush_shape_changed.emit(current_brush_image, deg_to_rad(current_brush_angle), current_brush_id)
		return

	var brushes: Array[Dictionary] = SimpleTerrainSettings.get_all_brushes()
	var found: Dictionary = {}
	for b: Dictionary in brushes:
		if b.get("id", "") == brush_id:
			found = b
			break
	if found.is_empty() and not brushes.is_empty():
		found = brushes[0]

	if found.is_empty():
		return

	current_brush_id = str(found.get("id", "circle_gradient"))
	current_brush_name = str(found.get("name", "Circle Gradient"))
	current_brush_path = str(found.get("path", ""))

	var img: Image = null
	if current_brush_path.begins_with("res://") and ResourceLoader.exists(current_brush_path):
		var res: Resource = ResourceLoader.load(current_brush_path)
		if res is Texture2D:
			img = (res as Texture2D).get_image()
			if img != null:
				img = img.duplicate()
	if img == null and FileAccess.file_exists(ProjectSettings.globalize_path(current_brush_path)):
		img = Image.new()
		if img.load(ProjectSettings.globalize_path(current_brush_path)) == OK:
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)

	if img != null:
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		current_brush_image = img
		current_brush_texture = ImageTexture.create_from_image(img)
	else:
		current_brush_image = null
		current_brush_texture = null

	if brush_shape_rect != null:
		brush_shape_rect.texture = current_brush_texture
	if brush_shape_btn != null:
		brush_shape_btn.tooltip_text = "Brush Shape: %s\nClick to change footprint shape & rotation" % current_brush_name
	if flyout_brush_preview_rect != null:
		flyout_brush_preview_rect.texture = current_brush_texture
	if flyout_brush_name_label != null:
		flyout_brush_name_label.text = current_brush_name

	SimpleTerrainSettings.save_last_brush_id(current_brush_id)
	if emit_signal_change:
		brush_shape_changed.emit(current_brush_image, deg_to_rad(current_brush_angle), current_brush_id)
	if current_mode == ToolMode.PAINT:
		_notify_paint_changed()
	elif current_mode == ToolMode.SCULPT:
		_notify_sculpt_changed()


func set_brush_angle(angle_deg: float, emit_signal_change: bool = true) -> void:
	if absf(current_brush_angle - angle_deg) < 0.001:
		return
	current_brush_angle = angle_deg
	if flyout_brush_angle_spin != null:
		flyout_brush_angle_spin.set_value_no_signal(angle_deg)
	if emit_signal_change:
		brush_shape_changed.emit(current_brush_image, deg_to_rad(current_brush_angle), current_brush_id)
	if current_mode == ToolMode.PAINT:
		_notify_paint_changed()
	elif current_mode == ToolMode.SCULPT:
		_notify_sculpt_changed()


func set_slope_limits(min_deg: float, max_deg: float, emit_signal_change: bool = true) -> void:
	var new_min: float = clampf(minf(min_deg, max_deg), 0.0, 90.0)
	var new_max: float = clampf(maxf(min_deg, max_deg), 0.0, 90.0)
	if absf(current_min_slope_deg - new_min) < 0.01 and absf(current_max_slope_deg - new_max) < 0.01:
		return
	current_min_slope_deg = new_min
	current_max_slope_deg = new_max
	if slope_min_spin != null:
		slope_min_spin.set_value_no_signal(current_min_slope_deg)
	if slope_max_spin != null:
		slope_max_spin.set_value_no_signal(current_max_slope_deg)

	var is_constrained: bool = current_min_slope_deg > 0.1 or current_max_slope_deg < 89.9
	var tint: Color = Color(0.45, 0.82, 1.0) if is_constrained else Color.WHITE
	var tip: String = "Slope Limit: [%.0f° - %.0f°]\nClick to constrain painting/sculpting by surface angle" % [current_min_slope_deg, current_max_slope_deg]
	if slope_limit_btn != null:
		slope_limit_btn.modulate = tint
		slope_limit_btn.tooltip_text = tip
	if sculpt_slope_limit_btn != null:
		sculpt_slope_limit_btn.modulate = tint
		sculpt_slope_limit_btn.tooltip_text = tip

	SimpleTerrainSettings.save_slope_limits(current_min_slope_deg, current_max_slope_deg)
	if emit_signal_change:
		slope_limits_changed.emit(current_min_slope_deg, current_max_slope_deg)


func _restore_brush_if_available() -> void:
	var last_id: String = SimpleTerrainSettings.get_last_brush_id()
	if last_id.is_empty():
		last_id = "circle_gradient"
	select_brush_shape(last_id, false)


func open_custom_brush_dialog() -> void:
	if custom_brush_file_dialog != null:
		custom_brush_file_dialog.popup_centered(Vector2i(650, 480))


func _on_custom_brush_file_selected(path: String) -> void:
	var brush_name: String = path.get_file().get_basename().capitalize().replace("_", " ")
	var brush_id: String = SimpleTerrainSettings.register_custom_brush(path, brush_name)
	select_brush_shape(brush_id)


func get_brush_image() -> Image:
	return current_brush_image


func get_brush_angle() -> float:
	return deg_to_rad(current_brush_angle)


func get_brush_texture() -> Texture2D:
	return current_brush_texture


func get_brush_id() -> String:
	return current_brush_id


func get_min_slope_deg() -> float:
	return current_min_slope_deg


func get_max_slope_deg() -> float:
	return current_max_slope_deg


func _open_dynamics_popup(anchor_btn: Button, is_sculpt: bool) -> void:
	if dynamics_popup == null:
		return
	if sculpt_dynamics_box != null:
		sculpt_dynamics_box.visible = is_sculpt
	if paint_dynamics_box != null:
		paint_dynamics_box.visible = not is_sculpt
	var btn_pos: Vector2 = anchor_btn.global_position
	var btn_sz: Vector2 = anchor_btn.size
	var popup_pos: Vector2i = Vector2i(int(btn_pos.x), int(btn_pos.y + btn_sz.y + 4.0))
	dynamics_popup.popup(Rect2i(popup_pos, dynamics_popup.size))


func _open_mask_popup() -> void:
	if mask_popup == null or sculpt_mask_btn == null:
		return
	var btn_pos: Vector2 = sculpt_mask_btn.global_position
	var btn_sz: Vector2 = sculpt_mask_btn.size
	var popup_pos: Vector2i = Vector2i(int(btn_pos.x), int(btn_pos.y + btn_sz.y + 4.0))
	mask_popup.popup(Rect2i(popup_pos, mask_popup.size))


func _on_reset_dynamics_pressed() -> void:
	if current_mode == ToolMode.SCULPT:
		if sculpt_spacing_spin != null:
			sculpt_spacing_spin.value = 15.0
		if sculpt_jitter_pos_spin != null:
			sculpt_jitter_pos_spin.value = 0.0
		if sculpt_jitter_angle_spin != null:
			sculpt_jitter_angle_spin.value = 0.0
	else:
		if paint_spacing_spin != null:
			paint_spacing_spin.value = 15.0
		if paint_jitter_pos_spin != null:
			paint_jitter_pos_spin.value = 0.0
		if paint_jitter_angle_spin != null:
			paint_jitter_angle_spin.value = 0.0
	_update_dynamics_indicators()


func _update_dynamics_indicators() -> void:
	if sculpt_dynamics_btn != null and sculpt_jitter_pos_spin != null and sculpt_jitter_angle_spin != null and sculpt_spacing_spin != null:
		var has_dyn: bool = sculpt_jitter_pos_spin.value > 0.0 or sculpt_jitter_angle_spin.value > 0.0 or absf(sculpt_spacing_spin.value - 15.0) > 0.001
		sculpt_dynamics_btn.modulate = Color(0.45, 0.82, 1.0) if has_dyn else Color.WHITE
	if paint_dynamics_btn != null and paint_jitter_pos_spin != null and paint_jitter_angle_spin != null and paint_spacing_spin != null:
		var has_dyn: bool = paint_jitter_pos_spin.value > 0.0 or paint_jitter_angle_spin.value > 0.0 or absf(paint_spacing_spin.value - 15.0) > 0.001
		paint_dynamics_btn.modulate = Color(0.45, 0.82, 1.0) if has_dyn else Color.WHITE


func _load_stencil_preset(pattern_file: String, pattern_title: String) -> void:
	var path: String = "res://addons/simple_terrain/patterns/" + pattern_file
	var real_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(real_path):
		var img: Image = Image.load_from_file(real_path)
		if img != null and not img.is_empty():
			set_active_sculpt_mask(img, pattern_title, path)
	if mask_popup != null:
		mask_popup.hide()


func set_active_sculpt_mask(img: Image, mask_name: String, _path: String = "") -> void:
	loaded_mask_image = img
	if img != null and not img.is_empty():
		loaded_mask_texture = ImageTexture.create_from_image(img)
	else:
		loaded_mask_texture = null

	if sculpt_mask_rect != null:
		sculpt_mask_rect.texture = loaded_mask_texture
	if mask_preview_rect != null:
		mask_preview_rect.texture = loaded_mask_texture
	if mask_name_label != null:
		mask_name_label.text = mask_name if img != null else "None (No Mask)"
	if sculpt_mask_btn != null:
		sculpt_mask_btn.tooltip_text = "Sculpt Stencil: %s\nClick to configure mask or rotation" % mask_name
		if loaded_mask_image == null:
			sculpt_mask_btn.icon = ICON_SCULPT_MASK
			sculpt_mask_btn.modulate = Color.WHITE
		else:
			sculpt_mask_btn.icon = null
			sculpt_mask_btn.modulate = Color(0.45, 0.82, 1.0)
	_notify_mask_changed()


func _notify_mask_changed() -> void:
	var ang: float = deg_to_rad(sculpt_mask_angle_spin.value) if sculpt_mask_angle_spin != null else 0.0
	sculpt_mask_changed.emit(loaded_mask_image, ang)


func _on_new_terrain_confirmed() -> void:
	var size: Vector2 = Vector2(float(new_size_x_spin.value), float(new_size_z_spin.value))
	var res: Vector2i = Vector2i(int(new_res_x_spin.value), int(new_res_z_spin.value))
	var tex_dim: int = new_tex_option.get_selected_id()
	if tex_dim <= 0:
		tex_dim = 1024
	var tex_size: Vector2i = Vector2i(tex_dim, tex_dim)
	var base_col: Color = new_base_color_picker.color

	create_terrain_requested.emit(size, res, tex_size, base_col)


func _notify_sculpt_changed() -> void:
	var submode: int = current_sculpt_submode
	var radius: float = float(sculpt_size_scrubber.value) if sculpt_size_scrubber != null else 5.0
	var strength: float = float(sculpt_strength_scrubber.value) if sculpt_strength_scrubber != null else 1.0
	var falloff: float = float(current_sculpt_falloff)
	var target_h: float = float(flatten_height_scrubber.value) if flatten_height_scrubber != null else 0.0
	sculpt_settings_changed.emit(submode, radius, strength, falloff, target_h)


func _notify_paint_changed() -> void:
	var submode: int = current_paint_submode
	var color: Color = paint_color_picker.color
	var tiling: float = current_pattern_tiling
	var angle: float = current_pattern_angle
	var radius: float = float(paint_size_scrubber.value) if paint_size_scrubber != null else 5.0
	var strength: float = float(paint_strength_scrubber.value) if paint_strength_scrubber != null else 1.0
	var falloff: float = float(current_paint_falloff)
	paint_settings_changed.emit(submode, color, loaded_stamp_image, tiling, angle, radius, strength, falloff)


func set_pattern_settings(tiling: float, angle: float) -> void:
	current_pattern_tiling = tiling
	current_pattern_angle = angle
	_notify_paint_changed()


func adjust_brush_radius(delta_val: float) -> void:
	if current_mode == ToolMode.SCULPT:
		if sculpt_size_scrubber != null:
			sculpt_size_scrubber.value = clampf(sculpt_size_scrubber.value + delta_val, sculpt_size_scrubber.min_value, sculpt_size_scrubber.max_value)
	elif current_mode == ToolMode.PAINT:
		if paint_size_scrubber != null:
			paint_size_scrubber.value = clampf(paint_size_scrubber.value + delta_val, paint_size_scrubber.min_value, paint_size_scrubber.max_value)
	elif current_mode == ToolMode.FOLIAGE:
		if foliage_size_scrubber != null:
			foliage_size_scrubber.value = clampf(foliage_size_scrubber.value + delta_val, foliage_size_scrubber.min_value, foliage_size_scrubber.max_value)


func adjust_brush_strength(delta_val: float) -> void:
	if current_mode == ToolMode.SCULPT:
		if sculpt_strength_scrubber != null:
			sculpt_strength_scrubber.value = clampf(sculpt_strength_scrubber.value + delta_val, sculpt_strength_scrubber.min_value, sculpt_strength_scrubber.max_value)
	elif current_mode == ToolMode.PAINT:
		if paint_strength_scrubber != null:
			paint_strength_scrubber.value = clampf(paint_strength_scrubber.value + delta_val, paint_strength_scrubber.min_value, paint_strength_scrubber.max_value)
	elif current_mode == ToolMode.FOLIAGE:
		var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
		if lyr != null:
			lyr.density = clampf(lyr.density + delta_val, 1.0, 50.0)
			if _current_terrain != null and _current_terrain.data != null:
				_current_terrain.data.emit_changed()
				if Engine.is_editor_hint():
					EditorInterface.mark_scene_as_unsaved()
			_notify_foliage_changed()


func get_sculpt_submode() -> int:
	return current_sculpt_submode


func get_sculpt_radius() -> float:
	return float(sculpt_size_scrubber.value) if sculpt_size_scrubber != null else 5.0


func get_sculpt_strength() -> float:
	return float(sculpt_strength_scrubber.value) if sculpt_strength_scrubber != null else 1.0


func get_sculpt_falloff() -> float:
	return float(current_sculpt_falloff)


func get_flatten_target_height() -> float:
	return float(flatten_height_scrubber.value) if flatten_height_scrubber != null else 0.0


func get_terrace_step() -> float:
	return float(terrace_step_scrubber.value) if terrace_step_scrubber != null else 2.0


func get_ramp_width() -> float:
	return float(ramp_width_scrubber.value) if ramp_width_scrubber != null else 6.0


func get_ramp_falloff() -> float:
	return float(ramp_falloff_scrubber.value) if ramp_falloff_scrubber != null else 2.0


func get_ramp_crown() -> float:
	return float(ramp_crown_scrubber.value) if ramp_crown_scrubber != null else 0.0


func get_sculpt_mask_image() -> Image:
	return loaded_mask_image


func get_sculpt_mask_angle() -> float:
	return deg_to_rad(sculpt_mask_angle_spin.value) if sculpt_mask_angle_spin != null else 0.0


func get_sculpt_spacing() -> float:
	return float(sculpt_spacing_spin.value) if sculpt_spacing_spin != null else 15.0


func get_sculpt_jitter_pos() -> float:
	return float(sculpt_jitter_pos_spin.value) if sculpt_jitter_pos_spin != null else 0.0


func get_sculpt_jitter_angle() -> float:
	return float(sculpt_jitter_angle_spin.value) if sculpt_jitter_angle_spin != null else 0.0


func get_paint_spacing() -> float:
	return float(paint_spacing_spin.value) if paint_spacing_spin != null else 15.0


func get_paint_jitter_pos() -> float:
	return float(paint_jitter_pos_spin.value) if paint_jitter_pos_spin != null else 0.0


func get_paint_jitter_angle() -> float:
	return float(paint_jitter_angle_spin.value) if paint_jitter_angle_spin != null else 0.0


func get_paint_submode() -> int:
	return current_paint_submode


func get_paint_color() -> Color:
	return paint_color_picker.color


func get_paint_radius() -> float:
	return float(paint_size_scrubber.value) if paint_size_scrubber != null else 5.0


func get_paint_strength() -> float:
	return float(paint_strength_scrubber.value) if paint_strength_scrubber != null else 1.0


func get_paint_falloff() -> float:
	return float(current_paint_falloff)


func get_paint_tiling() -> float:
	return current_pattern_tiling


func get_paint_angle() -> float:
	return current_pattern_angle


func open_slope_dialog() -> void:
	if slope_dialog != null:
		if _current_terrain != null:
			slope_dialog.init_from_terrain(_current_terrain)
		slope_dialog.popup_centered(Vector2i(420, 480))


func set_auto_slope_sculpt_active(active: bool) -> void:
	if sculpt_auto_slope_btn != null and sculpt_auto_slope_btn.button_pressed != active:
		sculpt_auto_slope_btn.button_pressed = active
	if slope_dialog != null:
		slope_dialog.set_auto_sculpt_active(active)


func set_foliage_submode(submode: int) -> void:
	current_foliage_submode = submode
	if foliage_paint_btn != null:
		foliage_paint_btn.button_pressed = (submode == SimpleTerrain3D.FoliageBrushMode.PAINT)
	if foliage_erase_btn != null:
		foliage_erase_btn.button_pressed = (submode == SimpleTerrain3D.FoliageBrushMode.ERASE)
	if foliage_select_btn != null:
		foliage_select_btn.button_pressed = (submode == SimpleTerrain3D.FoliageBrushMode.SELECT)
	if foliage_brush_box != null:
		foliage_brush_box.visible = (submode != SimpleTerrain3D.FoliageBrushMode.SELECT)
	if foliage_instance_box != null:
		foliage_instance_box.visible = (submode == SimpleTerrain3D.FoliageBrushMode.SELECT)
	_notify_foliage_changed()


func set_selected_foliage_instance(layer_idx: int, instance_idx: int, xform: Transform3D, layer_name: String) -> void:
	_selected_inst_layer = layer_idx
	_selected_inst_idx = instance_idx
	_selected_inst_transform = xform

	if foliage_selected_label == null:
		return

	if instance_idx >= 0:
		foliage_selected_label.text = "#%d (%s)" % [instance_idx, layer_name]
		_updating_inst_spins = true
		foliage_pos_x_spin.value = xform.origin.x
		foliage_pos_y_spin.value = xform.origin.y
		foliage_pos_z_spin.value = xform.origin.z

		var rot_deg: Vector3 = xform.basis.get_euler() * (180.0 / PI)
		foliage_yaw_spin.value = rot_deg.y

		var sc: Vector3 = xform.basis.get_scale()
		foliage_scale_spin.value = sc.x
		_updating_inst_spins = false

		foliage_pos_x_spin.editable = true
		foliage_pos_y_spin.editable = true
		foliage_pos_z_spin.editable = true
		foliage_yaw_spin.editable = true
		foliage_scale_spin.editable = true
		foliage_align_surface_btn.disabled = false
		foliage_delete_inst_btn.disabled = false
		foliage_deselect_btn.disabled = false
	else:
		foliage_selected_label.text = "Click object to select"
		foliage_pos_x_spin.editable = false
		foliage_pos_y_spin.editable = false
		foliage_pos_z_spin.editable = false
		foliage_yaw_spin.editable = false
		foliage_scale_spin.editable = false
		foliage_align_surface_btn.disabled = true
		foliage_delete_inst_btn.disabled = true
		foliage_deselect_btn.disabled = true


func _on_inst_spin_changed() -> void:
	if _updating_inst_spins or _selected_inst_idx < 0:
		return

	var new_pos: Vector3 = Vector3(
		foliage_pos_x_spin.value,
		foliage_pos_y_spin.value,
		foliage_pos_z_spin.value
	)
	var yaw_rad: float = deg_to_rad(foliage_yaw_spin.value)
	var sc: float = maxf(foliage_scale_spin.value, 0.05)

	var basis: Basis = Basis().rotated(Vector3.UP, yaw_rad).scaled(Vector3(sc, sc, sc))
	var new_xform: Transform3D = Transform3D(basis, new_pos)
	_selected_inst_transform = new_xform

	foliage_instance_transform_changed.emit(_selected_inst_layer, _selected_inst_idx, new_xform)


func open_foliage_dialog() -> void:
	open_asset_dock_requested.emit(0)


func set_terrain(terrain: SimpleTerrain3D) -> void:
	_current_terrain = terrain
	_restore_pattern_if_available()


func set_asset_dock_active(active: bool) -> void:
	if asset_dock_btn != null and asset_dock_btn.button_pressed != active:
		asset_dock_btn.set_block_signals(true)
		asset_dock_btn.button_pressed = active
		asset_dock_btn.set_block_signals(false)


func set_foliage_layer_index(idx: int) -> void:
	current_foliage_layer_idx = idx
	_notify_foliage_changed()


func update_foliage_layers(layers: Array[SimpleTerrainFoliageLayer], selected_idx: int = -1) -> void:
	if layers.is_empty():
		current_foliage_layer_idx = -1
	else:
		if selected_idx >= 0 and selected_idx < layers.size():
			current_foliage_layer_idx = selected_idx
		elif current_foliage_layer_idx < 0 or current_foliage_layer_idx >= layers.size():
			current_foliage_layer_idx = 0
	_notify_foliage_changed()


func update_foliage_instance_count(_count: int) -> void:
	pass


func _notify_foliage_changed() -> void:
	var submode: int = current_foliage_submode
	var layer_idx: int = current_foliage_layer_idx
	var radius: float = float(foliage_size_scrubber.value) if foliage_size_scrubber != null else 4.0
	var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
	var density: float = lyr.density if lyr != null else 12.0
	var min_spacing: float = lyr.min_spacing if lyr != null else 0.25
	var min_scale: float = lyr.min_scale if lyr != null else 0.8
	var max_scale: float = lyr.max_scale if lyr != null else 1.3
	var align_norm: float = lyr.align_to_normal if lyr != null else 0.5
	var max_slope: float = lyr.max_slope_deg if lyr != null else 40.0
	var height_off: float = lyr.height_offset if lyr != null else -0.05
	var rand_yaw: bool = lyr.random_yaw if lyr != null else true
	var rand_tilt: float = lyr.random_tilt_deg if lyr != null else 5.0

	foliage_settings_changed.emit(
		submode,
		layer_idx,
		radius,
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


func _get_active_foliage_layer() -> SimpleTerrainFoliageLayer:
	if _current_terrain != null and _current_terrain.data != null:
		var layers: Array[SimpleTerrainFoliageLayer] = _current_terrain.data.foliage_layers
		if current_foliage_layer_idx >= 0 and current_foliage_layer_idx < layers.size():
			return layers[current_foliage_layer_idx]
	return null


func _restore_pattern_if_available() -> void:
	if loaded_stamp_image != null:
		return
	var last_pat: String = SimpleTerrainSettings.get_last_pattern_path()
	if last_pat.is_empty():
		last_pat = "res://addons/simple_terrain/patterns/rock_cliff.png"
	if not last_pat.is_empty():
		var img: Image = null
		if last_pat.begins_with("res://") and ResourceLoader.exists(last_pat):
			var res: Resource = ResourceLoader.load(last_pat)
			if res is Texture2D:
				img = (res as Texture2D).get_image()
				if img != null:
					img = img.duplicate()
		if img == null and FileAccess.file_exists(last_pat):
			img = Image.new()
			if img.load(last_pat) == OK:
				if img.is_compressed():
					img.decompress()
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
		if img != null:
			var title: String = last_pat.get_file().get_basename().capitalize().replace("_", " ")
			set_active_pattern(img, title, last_pat)


func get_foliage_submode() -> int:
	return current_foliage_submode


func get_foliage_layer_index() -> int:
	return current_foliage_layer_idx


func get_foliage_radius() -> float:
	return float(foliage_size_scrubber.value) if foliage_size_scrubber != null else 4.0


func get_foliage_density() -> float:
	var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
	return lyr.density if lyr != null else 12.0


func get_foliage_spacing() -> float:
	var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
	return lyr.min_spacing if lyr != null else 0.25


func get_foliage_align() -> float:
	var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
	return lyr.align_to_normal if lyr != null else 0.5


func get_foliage_max_slope() -> float:
	var lyr: SimpleTerrainFoliageLayer = _get_active_foliage_layer()
	return lyr.max_slope_deg if lyr != null else 40.0
