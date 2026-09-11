@tool
class_name TerrainAssetDock
extends PanelContainer

## Non-modal asset dock for SimpleTerrain3D.
## Provides real-time foliage layer management, preset library browsing,
## 3D model importing, texture pattern palette, and persistent configuration.

signal foliage_layer_selected(layer_index: int)
signal foliage_layer_add_requested(layer: SimpleTerrainFoliageLayer)
signal foliage_layer_delete_requested(layer_index: int)
signal foliage_layer_clear_requested(layer_index: int)
signal foliage_layer_visibility_changed(layer_index: int, is_visible: bool)
signal foliage_settings_changed(layer_index: int, layer: SimpleTerrainFoliageLayer)

signal pattern_selected(image: Image, pattern_name: String, source_path: String)
signal pattern_settings_changed(tiling: float, angle: float)
signal brush_shape_selected(image: Image, angle_rad: float, brush_id: String)
signal slope_limits_changed(min_slope_deg: float, max_slope_deg: float)
signal dock_close_requested()

const CARD_FOLIAGE_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_foliage_card.tscn")
const CARD_PATTERN_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_pattern_card.tscn")
const CARD_BRUSH_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_brush_card.tscn")
const ACTIVE_LAYER_ROW_SCENE: PackedScene = preload("res://addons/simple_terrain/ui/terrain_active_layer_row.tscn")
const FOLIAGE_PRESETS_DIR: String = "res://addons/simple_terrain/foliage_presets"
const BUILTIN_PATTERNS_DIR: String = "res://addons/simple_terrain/patterns"

enum DockTab { FOLIAGE, TEXTURES }

var current_terrain: SimpleTerrain3D = null
var current_tab: DockTab = DockTab.FOLIAGE
var selected_foliage_layer_idx: int = -1
var selected_preset_layer: SimpleTerrainFoliageLayer = null
var selected_pattern_path: String = ""
var selected_brush_id: String = "circle_gradient"

# Foliage cards & active rows
var _foliage_cards: Array[TerrainFoliageCard] = []
var _active_layer_rows: Array[TerrainActiveLayerRow] = []
var _pattern_cards: Array[TerrainPatternCard] = []
var _brush_cards: Array[TerrainBrushCard] = []
var _updating_controls: bool = false

# UI References
@onready var tab_foliage_btn: Button = %TabFoliageBtn
@onready var tab_textures_btn: Button = %TabTexturesBtn
@onready var search_edit: LineEdit = %SearchEdit
@onready var category_option: OptionButton = %CategoryOption
@onready var import_btn: Button = %ImportBtn
@onready var refresh_btn: Button = %RefreshBtn
@onready var close_btn: Button = %CloseBtn

@onready var foliage_view: Control = %FoliageView
@onready var texture_view: Control = %TextureView

# Foliage Tab Controls
@onready var active_layers_list: VBoxContainer = %ActiveLayersList
@onready var layers_count_label: Label = %LayersCountLabel
@onready var add_layer_btn: Button = %AddLayerBtn
@onready var foliage_grid: HFlowContainer = %FoliageGrid

@onready var layer_props_box: VBoxContainer = %LayerPropsBox
@onready var density_toggle_btn: Button = %DensityToggleBtn
@onready var density_container: VBoxContainer = %DensityContainer
@onready var transform_toggle_btn: Button = %TransformToggleBtn
@onready var transform_container: VBoxContainer = %TransformContainer
@onready var surface_toggle_btn: Button = %SurfaceToggleBtn
@onready var surface_container: VBoxContainer = %SurfaceContainer
@onready var dock_density_spin: SpinBox = %DockDensitySpin
@onready var dock_spacing_spin: SpinBox = %DockSpacingSpin
@onready var dock_scale_min_spin: SpinBox = %DockScaleMinSpin
@onready var dock_scale_max_spin: SpinBox = %DockScaleMaxSpin
@onready var dock_align_spin: SpinBox = %DockAlignSpin
@onready var dock_slope_spin: SpinBox = %DockSlopeSpin
@onready var dock_tilt_spin: SpinBox = %DockTiltSpin
@onready var dock_height_spin: SpinBox = %DockHeightSpin
@onready var dock_shadow_option: OptionButton = %DockShadowOption
@onready var dock_mesh_label: Label = %DockMeshLabel
@onready var dock_save_preset_btn: Button = %DockSavePresetBtn
@onready var dock_clear_inst_btn: Button = %DockClearInstBtn

# Texture Tab Controls
@onready var dock_import_brush_btn: Button = %DockImportBrushBtn
@onready var brush_grid: HFlowContainer = %BrushGrid
@onready var dock_brush_preview_rect: TextureRect = %DockBrushPreviewRect
@onready var dock_brush_name_label: Label = %DockBrushNameLabel
@onready var dock_brush_angle_spin: SpinBox = %DockBrushAngleSpin

@onready var dock_slope_min_spin: SpinBox = %DockSlopeMinSpin
@onready var dock_slope_max_spin: SpinBox = %DockSlopeMaxSpin
@onready var dock_slope_preset_all: Button = %DockSlopePresetAll
@onready var dock_slope_preset_flat: Button = %DockSlopePresetFlat
@onready var dock_slope_preset_cliffs: Button = %DockSlopePresetCliffs
@onready var dock_slope_reset_btn: Button = %DockSlopeResetBtn

@onready var texture_grid: HFlowContainer = %TextureGrid
@onready var dock_pattern_preview_rect: TextureRect = %DockPatternPreviewRect
@onready var dock_pattern_name_label: Label = %DockPatternNameLabel
@onready var dock_tiling_spin: SpinBox = %DockTilingSpin
@onready var dock_angle_spin: SpinBox = %DockAngleSpin

# File Dialogs
@onready var model_file_dialog: FileDialog = %ModelFileDialog
@onready var texture_file_dialog: FileDialog = %TextureFileDialog
@onready var brush_file_dialog: FileDialog = %BrushFileDialog
@onready var save_preset_file_dialog: FileDialog = %SavePresetFileDialog


func _ready() -> void:
	_connect_top_bar()
	_connect_foliage_controls()
	_connect_texture_controls()
	_setup_shadow_options()
	_setup_category_options()
	_populate_all()


func set_terrain(terrain: SimpleTerrain3D) -> void:
	current_terrain = terrain
	_update_active_layers()
	if current_terrain != null and current_terrain.data != null:
		if selected_foliage_layer_idx < 0 and not current_terrain.data.foliage_layers.is_empty():
			select_active_layer(0)
		elif selected_foliage_layer_idx >= current_terrain.data.foliage_layers.size():
			select_active_layer(maxi(0, current_terrain.data.foliage_layers.size() - 1))
		else:
			_update_layer_inspector()


func select_tab(tab: int) -> void:
	current_tab = tab as DockTab
	tab_foliage_btn.button_pressed = (current_tab == DockTab.FOLIAGE)
	tab_textures_btn.button_pressed = (current_tab == DockTab.TEXTURES)
	foliage_view.visible = (current_tab == DockTab.FOLIAGE)
	texture_view.visible = (current_tab == DockTab.TEXTURES)
	if current_tab == DockTab.FOLIAGE:
		import_btn.text = "+ Import 3D Model..."
		category_option.show()
	else:
		import_btn.text = "+ Import Texture..."
		category_option.hide()
	_filter_items()


func select_active_layer(idx: int) -> void:
	selected_foliage_layer_idx = idx
	for i: int in range(_active_layer_rows.size()):
		_active_layer_rows[i].is_active = (i == idx)
	_update_layer_inspector()
	foliage_layer_selected.emit(idx)


func _connect_top_bar() -> void:
	tab_foliage_btn.pressed.connect(func() -> void: select_tab(0))
	tab_textures_btn.pressed.connect(func() -> void: select_tab(1))
	search_edit.text_changed.connect(func(_t: String) -> void: _filter_items())
	category_option.item_selected.connect(func(_idx: int) -> void: _filter_items())
	import_btn.pressed.connect(_on_import_btn_pressed)
	refresh_btn.pressed.connect(_populate_all)
	if close_btn != null:
		close_btn.pressed.connect(func() -> void: dock_close_requested.emit())


func _setup_shadow_options() -> void:
	if dock_shadow_option != null and dock_shadow_option.item_count == 0:
		var pop: PopupMenu = dock_shadow_option.get_popup()
		if pop != null:
			pop.add_theme_font_size_override("font_size", 22)
		dock_shadow_option.add_item("Off (Fastest)", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		dock_shadow_option.add_item("On", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		dock_shadow_option.add_item("Shadows Only", GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


func _setup_category_options() -> void:
	if category_option != null and category_option.item_count == 0:
		var pop: PopupMenu = category_option.get_popup()
		if pop != null:
			pop.add_theme_font_size_override("font_size", 22)
		category_option.add_item("All Foliage", 0)
		category_option.add_item("Grass (Binbun)", 1)
		category_option.add_item("Imported Models", 2)
		category_option.add_item("Saved Presets", 3)


func _connect_foliage_controls() -> void:
	if add_layer_btn != null:
		add_layer_btn.pressed.connect(_on_add_selected_preset_to_terrain)

	if density_toggle_btn != null and density_container != null:
		density_toggle_btn.pressed.connect(func() -> void:
			_toggle_section(density_toggle_btn, density_container, "SCATTER DENSITY")
		)
	if transform_toggle_btn != null and transform_container != null:
		transform_toggle_btn.pressed.connect(func() -> void:
			_toggle_section(transform_toggle_btn, transform_container, "TRANSFORM VARIATION")
		)
	if surface_toggle_btn != null and surface_container != null:
		surface_toggle_btn.pressed.connect(func() -> void:
			_toggle_section(surface_toggle_btn, surface_container, "SURFACE CONSTRAINTS")
		)

	if dock_density_spin != null:
		dock_density_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_spacing_spin != null:
		dock_spacing_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_scale_min_spin != null:
		dock_scale_min_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_scale_max_spin != null:
		dock_scale_max_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_align_spin != null:
		dock_align_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_slope_spin != null:
		dock_slope_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_tilt_spin != null:
		dock_tilt_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_height_spin != null:
		dock_height_spin.value_changed.connect(_on_layer_prop_changed)
	if dock_shadow_option != null:
		dock_shadow_option.item_selected.connect(func(_i: int) -> void: _on_layer_prop_changed(0.0))

	if dock_save_preset_btn != null:
		dock_save_preset_btn.pressed.connect(_on_save_preset_pressed)
	if dock_clear_inst_btn != null:
		dock_clear_inst_btn.pressed.connect(_on_clear_active_layer_instances)

	if model_file_dialog != null:
		model_file_dialog.file_selected.connect(_on_model_file_selected)
	if save_preset_file_dialog != null:
		save_preset_file_dialog.file_selected.connect(_on_save_preset_file_selected)


func _connect_texture_controls() -> void:
	if dock_tiling_spin != null:
		dock_tiling_spin.value_changed.connect(func(v: float) -> void:
			pattern_settings_changed.emit(v, float(dock_angle_spin.value))
		)
	if dock_angle_spin != null:
		dock_angle_spin.value_changed.connect(func(v: float) -> void:
			pattern_settings_changed.emit(float(dock_tiling_spin.value), v)
		)
	if texture_file_dialog != null:
		texture_file_dialog.file_selected.connect(_on_texture_file_selected)

	if dock_import_brush_btn != null:
		dock_import_brush_btn.pressed.connect(func() -> void:
			if brush_file_dialog != null:
				brush_file_dialog.popup_centered(Vector2i(1050, 700))
		)
	if brush_file_dialog != null:
		brush_file_dialog.file_selected.connect(_on_brush_file_selected)
	if dock_brush_angle_spin != null:
		dock_brush_angle_spin.value_changed.connect(_on_brush_angle_changed)

	if dock_slope_min_spin != null:
		dock_slope_min_spin.value_changed.connect(_on_dock_slope_changed)
	if dock_slope_max_spin != null:
		dock_slope_max_spin.value_changed.connect(_on_dock_slope_changed)
	if dock_slope_preset_all != null:
		dock_slope_preset_all.pressed.connect(func() -> void: set_dock_slope_limits(0.0, 90.0))
	if dock_slope_preset_flat != null:
		dock_slope_preset_flat.pressed.connect(func() -> void: set_dock_slope_limits(0.0, 30.0))
	if dock_slope_preset_cliffs != null:
		dock_slope_preset_cliffs.pressed.connect(func() -> void: set_dock_slope_limits(35.0, 90.0))
	if dock_slope_reset_btn != null:
		dock_slope_reset_btn.pressed.connect(func() -> void: set_dock_slope_limits(0.0, 90.0))


func _populate_all() -> void:
	_populate_foliage_presets()
	_populate_brushes()
	_populate_textures()
	_update_active_layers()
	var slopes: Vector2 = SimpleTerrainSettings.get_slope_limits()
	if dock_slope_min_spin != null:
		dock_slope_min_spin.set_value_no_signal(slopes.x)
	if dock_slope_max_spin != null:
		dock_slope_max_spin.set_value_no_signal(slopes.y)
	_restore_last_state()


func _populate_foliage_presets() -> void:
	if foliage_grid == null:
		return
	for child: Node in foliage_grid.get_children():
		child.queue_free()
	_foliage_cards.clear()

	# 1. Built-in BinbunGrass presets (1..10)
	for i: int in range(1, 11):
		var layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.create_binbun_grass_preset(i)
		var preview_tex: Texture2D = null
		var thumb_path: String = "res://assets/asset_packs/BinbunGrass/src/palette/palette_%02d.tres" % i
		if ResourceLoader.exists(thumb_path):
			preview_tex = load(thumb_path) as Texture2D
		_add_foliage_card(layer, preview_tex, "grass")

	# 2. Saved presets from disk
	_ensure_presets_dir()
	var dir: DirAccess = DirAccess.open(FOLIAGE_PRESETS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path: String = FOLIAGE_PRESETS_DIR.path_join(file_name)
				var res: Resource = ResourceLoader.load(full_path)
				if res is SimpleTerrainFoliageLayer:
					var layer: SimpleTerrainFoliageLayer = res as SimpleTerrainFoliageLayer
					var category: String = "imported" if not layer.source_scene_path.is_empty() else "preset"
					_add_foliage_card(layer, null, category)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 3. Custom models from project registry
	var custom_models: Array[Dictionary] = SimpleTerrainSettings.get_imported_models()
	for model_info: Dictionary in custom_models:
		var mpath: String = model_info.get("path", "")
		if not mpath.is_empty() and ResourceLoader.exists(mpath):
			# Ensure it has a card if not already added
			var already_added: bool = false
			for c: TerrainFoliageCard in _foliage_cards:
				if c.foliage_layer != null and c.foliage_layer.source_scene_path == mpath:
					already_added = true
					break
			if not already_added:
				var layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.create_from_file(mpath)
				if layer != null:
					_add_foliage_card(layer, null, "imported")

	_filter_items()


func _add_foliage_card(layer: SimpleTerrainFoliageLayer, preview: Texture2D, category: String) -> void:
	var card: TerrainFoliageCard = CARD_FOLIAGE_SCENE.instantiate() as TerrainFoliageCard
	card.set_meta("category", category)
	card.card_selected.connect(_on_preset_card_selected)
	card.card_double_clicked.connect(_on_preset_card_double_clicked)
	foliage_grid.add_child(card)
	card.setup(layer, preview)
	_foliage_cards.append(card)

	# Request thumbnail preview if missing
	if preview == null and Engine.is_editor_hint():
		var path_to_preview: String = ""
		if not layer.source_scene_path.is_empty() and ResourceLoader.exists(layer.source_scene_path):
			path_to_preview = layer.source_scene_path
		elif layer.mesh != null and not layer.mesh.resource_path.is_empty() and ResourceLoader.exists(layer.mesh.resource_path):
			path_to_preview = layer.mesh.resource_path
		if not path_to_preview.is_empty():
			var ei: Object = Engine.get_singleton("EditorInterface")
			if ei != null and ei.has_method("get_resource_previewer"):
				var previewer: Object = ei.get_resource_previewer()
				if previewer != null and previewer.has_method("queue_resource_preview"):
					previewer.queue_resource_preview(path_to_preview, self, "_on_foliage_preview_ready", card)


func _on_foliage_preview_ready(_path: String, preview: Texture2D, thumb: Texture2D, userdata: Variant) -> void:
	var card: TerrainFoliageCard = userdata as TerrainFoliageCard
	if card != null and is_instance_valid(card):
		var tex: Texture2D = preview if preview != null else thumb
		if tex != null and card.foliage_layer != null:
			card.setup(card.foliage_layer, tex)


func _populate_textures() -> void:
	if texture_grid == null:
		return
	for child: Node in texture_grid.get_children():
		child.queue_free()
	_pattern_cards.clear()

	# 1. Built-in patterns
	var dir: DirAccess = DirAccess.open(BUILTIN_PATTERNS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var ext: String = file_name.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					var full_path: String = BUILTIN_PATTERNS_DIR.path_join(file_name)
					var title: String = file_name.get_basename().capitalize().replace("_", " ")
					_add_texture_card(title, full_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	# 2. Registered custom patterns
	var custom_pats: Array[Dictionary] = SimpleTerrainSettings.get_custom_patterns()
	for entry: Dictionary in custom_pats:
		var p_path: String = entry.get("path", "")
		var p_name: String = entry.get("name", p_path.get_file().get_basename())
		if not p_path.is_empty():
			_add_texture_card(p_name, p_path)

	_filter_items()


func _add_texture_card(title: String, path: String) -> void:
	var img: Image = null
	var tex: Texture2D = null

	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res as Texture2D
			img = tex.get_image()
			if img != null:
				img = img.duplicate()

	if img == null:
		img = Image.new()
		var err: Error = img.load(path)
		if err != OK:
			return
		if img.is_compressed():
			img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		tex = ImageTexture.create_from_image(img)

	var card: TerrainPatternCard = CARD_PATTERN_SCENE.instantiate() as TerrainPatternCard
	card.card_selected.connect(_on_texture_card_selected)
	card.card_double_clicked.connect(_on_texture_card_selected)
	texture_grid.add_child(card)
	card.setup(title, path, img, tex)
	_pattern_cards.append(card)


func _update_active_layers() -> void:
	if active_layers_list == null:
		return
	for child: Node in active_layers_list.get_children():
		child.queue_free()
	_active_layer_rows.clear()

	if current_terrain == null or current_terrain.data == null:
		if layers_count_label != null:
			layers_count_label.text = "(0)"
		return

	var layers: Array[SimpleTerrainFoliageLayer] = current_terrain.data.foliage_layers
	if layers_count_label != null:
		layers_count_label.text = "(%d)" % layers.size()

	for i: int in range(layers.size()):
		var layer: SimpleTerrainFoliageLayer = layers[i]
		var row: TerrainActiveLayerRow = ACTIVE_LAYER_ROW_SCENE.instantiate() as TerrainActiveLayerRow
		row.selected.connect(_on_active_row_selected)
		row.visibility_toggled.connect(_on_active_row_visibility_toggled)
		row.delete_requested.connect(_on_active_row_delete_requested)
		active_layers_list.add_child(row)
		row.setup(i, layer.name, layer.get_instance_count(), layer.visible, (i == selected_foliage_layer_idx))
		_active_layer_rows.append(row)


func _update_layer_inspector() -> void:
	if current_terrain == null or current_terrain.data == null:
		return
	var layers: Array[SimpleTerrainFoliageLayer] = current_terrain.data.foliage_layers
	if selected_foliage_layer_idx < 0 or selected_foliage_layer_idx >= layers.size():
		return

	var layer: SimpleTerrainFoliageLayer = layers[selected_foliage_layer_idx]
	_updating_controls = true
	if dock_density_spin != null: dock_density_spin.value = layer.density
	if dock_spacing_spin != null: dock_spacing_spin.value = layer.min_spacing
	if dock_scale_min_spin != null: dock_scale_min_spin.value = layer.min_scale
	if dock_scale_max_spin != null: dock_scale_max_spin.value = layer.max_scale
	if dock_align_spin != null: dock_align_spin.value = layer.align_to_normal
	if dock_slope_spin != null: dock_slope_spin.value = layer.max_slope_deg
	if dock_tilt_spin != null: dock_tilt_spin.value = layer.random_tilt_deg
	if dock_height_spin != null: dock_height_spin.value = layer.height_offset

	if dock_shadow_option != null:
		for i: int in range(dock_shadow_option.item_count):
			if dock_shadow_option.get_item_id(i) == layer.cast_shadow:
				dock_shadow_option.select(i)
				break

	if dock_mesh_label != null:
		var mname: String = layer.source_scene_path.get_file() if not layer.source_scene_path.is_empty() else "Built-in QuadMesh"
		dock_mesh_label.text = "Model: " + mname
	_updating_controls = false


func _on_layer_prop_changed(_unused: float = 0.0) -> void:
	if _updating_controls or current_terrain == null or current_terrain.data == null:
		return
	var layers: Array[SimpleTerrainFoliageLayer] = current_terrain.data.foliage_layers
	if selected_foliage_layer_idx < 0 or selected_foliage_layer_idx >= layers.size():
		return

	var layer: SimpleTerrainFoliageLayer = layers[selected_foliage_layer_idx]
	if dock_density_spin != null: layer.density = float(dock_density_spin.value)
	if dock_spacing_spin != null: layer.min_spacing = float(dock_spacing_spin.value)
	if dock_scale_min_spin != null: layer.min_scale = float(dock_scale_min_spin.value)
	if dock_scale_max_spin != null: layer.max_scale = float(dock_scale_max_spin.value)
	if dock_align_spin != null: layer.align_to_normal = float(dock_align_spin.value)
	if dock_slope_spin != null: layer.max_slope_deg = float(dock_slope_spin.value)
	if dock_tilt_spin != null: layer.random_tilt_deg = float(dock_tilt_spin.value)
	if dock_height_spin != null: layer.height_offset = float(dock_height_spin.value)
	if dock_shadow_option != null:
		layer.cast_shadow = dock_shadow_option.get_selected_id() as GeometryInstance3D.ShadowCastingSetting

	current_terrain.data.emit_changed()
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

	foliage_settings_changed.emit(selected_foliage_layer_idx, layer)


func _on_active_row_selected(idx: int) -> void:
	select_active_layer(idx)


func _on_active_row_visibility_toggled(idx: int, is_visible: bool) -> void:
	if current_terrain != null:
		current_terrain.set_foliage_layer_visible(idx, is_visible)
		foliage_layer_visibility_changed.emit(idx, is_visible)


func _on_active_row_delete_requested(idx: int) -> void:
	foliage_layer_delete_requested.emit(idx)


func _on_clear_active_layer_instances() -> void:
	if selected_foliage_layer_idx >= 0:
		foliage_layer_clear_requested.emit(selected_foliage_layer_idx)


func _on_preset_card_selected(card: TerrainFoliageCard) -> void:
	selected_preset_layer = card.foliage_layer
	for c: TerrainFoliageCard in _foliage_cards:
		c.button_pressed = (c == card)


func _on_preset_card_double_clicked(card: TerrainFoliageCard) -> void:
	if card.foliage_layer != null:
		foliage_layer_add_requested.emit(card.foliage_layer.clone())


func _on_add_selected_preset_to_terrain() -> void:
	if selected_preset_layer != null:
		foliage_layer_add_requested.emit(selected_preset_layer.clone())


func _on_texture_card_selected(card: TerrainPatternCard) -> void:
	selected_pattern_path = card.pattern_path
	if dock_pattern_preview_rect != null:
		dock_pattern_preview_rect.texture = card.pattern_texture
	if dock_pattern_name_label != null:
		dock_pattern_name_label.text = card.pattern_name

	for c: TerrainPatternCard in _pattern_cards:
		c.button_pressed = (c == card)

	SimpleTerrainSettings.save_last_pattern_path(card.pattern_path)
	pattern_selected.emit(card.pattern_image, card.pattern_name, card.pattern_path)


func _on_import_btn_pressed() -> void:
	if current_tab == DockTab.FOLIAGE:
		if model_file_dialog != null:
			model_file_dialog.title = "Import 3D Model / Preset for Foliage"
			model_file_dialog.popup_centered(Vector2i(1050, 700))
	else:
		if texture_file_dialog != null:
			texture_file_dialog.title = "Import Texture / Stamp Pattern"
			texture_file_dialog.popup_centered(Vector2i(1050, 700))


func _on_model_file_selected(path: String) -> void:
	var layer: SimpleTerrainFoliageLayer = null
	if path.ends_with(".tres") or path.ends_with(".res"):
		var res: Resource = ResourceLoader.load(path)
		if res is SimpleTerrainFoliageLayer:
			layer = (res as SimpleTerrainFoliageLayer).clone()
	if layer == null:
		layer = SimpleTerrainFoliageLayer.create_from_file(path)

	if layer == null:
		printerr("[TerrainAssetDock] Failed to load 3D model from: ", path)
		return

	# Automatically save as a permanent preset in FOLIAGE_PRESETS_DIR
	_ensure_presets_dir()
	var safe_name: String = layer.name.to_lower().replace(" ", "_").replace("(", "").replace(")", "")
	var save_path: String = FOLIAGE_PRESETS_DIR.path_join(safe_name + ".tres")
	var preset_copy: SimpleTerrainFoliageLayer = layer.clone()
	preset_copy.transforms.clear()
	ResourceSaver.save(preset_copy, save_path)

	# Register in project settings
	SimpleTerrainSettings.register_imported_model(layer.name, path)

	_populate_foliage_presets()

	# Also automatically add to current terrain
	foliage_layer_add_requested.emit(layer.clone())


func _on_texture_file_selected(path: String) -> void:
	var title: String = path.get_file().get_basename().capitalize().replace("_", " ")
	SimpleTerrainSettings.register_custom_pattern(title, path)
	_populate_textures()

	# Select the newly imported pattern
	for c: TerrainPatternCard in _pattern_cards:
		if c.pattern_path == path:
			_on_texture_card_selected(c)
			break


func _on_save_preset_pressed() -> void:
	if current_terrain == null or current_terrain.data == null:
		return
	var layers: Array[SimpleTerrainFoliageLayer] = current_terrain.data.foliage_layers
	if selected_foliage_layer_idx < 0 or selected_foliage_layer_idx >= layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = layers[selected_foliage_layer_idx]
	_ensure_presets_dir()
	if save_preset_file_dialog != null:
		var safe_name: String = layer.name.to_lower().replace(" ", "_").replace("(", "").replace(")", "") + ".tres"
		save_preset_file_dialog.current_file = safe_name
		save_preset_file_dialog.popup_centered(Vector2i(980, 650))


func _on_save_preset_file_selected(path: String) -> void:
	if current_terrain == null or current_terrain.data == null:
		return
	var layers: Array[SimpleTerrainFoliageLayer] = current_terrain.data.foliage_layers
	if selected_foliage_layer_idx < 0 or selected_foliage_layer_idx >= layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = layers[selected_foliage_layer_idx]
	var copy: SimpleTerrainFoliageLayer = layer.clone()
	copy.transforms.clear()
	var err: Error = ResourceSaver.save(copy, path)
	if err == OK:
		print("[TerrainAssetDock] Saved foliage preset: ", path)
		_populate_foliage_presets()


func _filter_items() -> void:
	var q: String = search_edit.text.strip_edges().to_lower()
	var cat_id: int = category_option.get_selected_id()

	if current_tab == DockTab.FOLIAGE:
		for card: TerrainFoliageCard in _foliage_cards:
			if card.foliage_layer == null:
				continue
			var matches_q: bool = q.is_empty() or q in card.foliage_layer.name.to_lower()
			var card_cat: String = card.get_meta("category", "")
			var matches_cat: bool = true
			match cat_id:
				1: matches_cat = (card_cat == "grass")
				2: matches_cat = (card_cat == "imported")
				3: matches_cat = (card_cat == "preset")
			card.visible = matches_q and matches_cat
	else:
		for card: TerrainPatternCard in _pattern_cards:
			var matches_q: bool = q.is_empty() or q in card.pattern_name.to_lower()
			card.visible = matches_q
		for card: TerrainBrushCard in _brush_cards:
			var matches_q: bool = q.is_empty() or q in card.brush_name.to_lower()
			card.visible = matches_q


func _restore_last_state() -> void:
	var last_pat: String = SimpleTerrainSettings.get_last_pattern_path()
	if not last_pat.is_empty():
		for card: TerrainPatternCard in _pattern_cards:
			if card.pattern_path == last_pat:
				_on_texture_card_selected(card)
				break

	var last_brush: String = SimpleTerrainSettings.get_last_brush_id()
	if last_brush.is_empty():
		last_brush = "circle_gradient"
	select_brush_by_id(last_brush, false)


func _populate_brushes() -> void:
	if brush_grid == null:
		return
	for child: Node in brush_grid.get_children():
		child.queue_free()
	_brush_cards.clear()

	var all_brushes: Array[Dictionary] = SimpleTerrainSettings.get_all_brushes()
	for b_data: Dictionary in all_brushes:
		var b_id: String = b_data.get("id", "")
		var b_name: String = b_data.get("name", "")
		var b_path: String = b_data.get("path", "")
		_add_brush_card(b_id, b_name, b_path)


func _add_brush_card(b_id: String, b_name: String, path: String) -> void:
	var img: Image = null
	var tex: Texture2D = null

	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			tex = res as Texture2D
			img = tex.get_image()
			if img != null:
				img = img.duplicate()

	if img == null:
		var real_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(real_path):
			img = Image.new()
			if img.load(real_path) == OK:
				if img.is_compressed():
					img.decompress()
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				tex = ImageTexture.create_from_image(img)

	if img == null or tex == null:
		return

	var card: TerrainBrushCard = CARD_BRUSH_SCENE.instantiate() as TerrainBrushCard
	brush_grid.add_child(card)
	card.setup(b_id, b_name, path, img, tex)
	card.card_selected.connect(_on_brush_card_selected)
	_brush_cards.append(card)

	if selected_brush_id == b_id:
		card.button_pressed = true


func _on_brush_card_selected(card: TerrainBrushCard) -> void:
	_select_brush_card(card, true)


func _select_brush_card(card: TerrainBrushCard, emit_signal_change: bool = true) -> void:
	selected_brush_id = card.brush_id
	if dock_brush_preview_rect != null:
		dock_brush_preview_rect.texture = card.brush_texture
	if dock_brush_name_label != null:
		dock_brush_name_label.text = card.brush_name

	for c: TerrainBrushCard in _brush_cards:
		c.button_pressed = (c == card)

	SimpleTerrainSettings.save_last_brush_id(card.brush_id)
	if emit_signal_change:
		var angle_rad: float = deg_to_rad(float(dock_brush_angle_spin.value)) if dock_brush_angle_spin != null else 0.0
		brush_shape_selected.emit(card.brush_image, angle_rad, card.brush_id)


func _on_brush_angle_changed(value: float) -> void:
	for c: TerrainBrushCard in _brush_cards:
		if c.brush_id == selected_brush_id:
			brush_shape_selected.emit(c.brush_image, deg_to_rad(value), c.brush_id)
			break


func _on_brush_file_selected(path: String) -> void:
	var b_name: String = path.get_file().get_basename().capitalize().replace("_", " ")
	var b_id: String = SimpleTerrainSettings.register_custom_brush(path, b_name)
	_populate_brushes()
	select_brush_by_id(b_id, true)


func select_brush_by_id(b_id: String, emit_signal_change: bool = true) -> void:
	for c: TerrainBrushCard in _brush_cards:
		if c.brush_id == b_id:
			_select_brush_card(c, emit_signal_change)
			return


func _on_dock_slope_changed(_v: float) -> void:
	var min_deg: float = float(dock_slope_min_spin.value) if dock_slope_min_spin != null else 0.0
	var max_deg: float = float(dock_slope_max_spin.value) if dock_slope_max_spin != null else 90.0
	if min_deg > max_deg:
		if dock_slope_min_spin != null and dock_slope_min_spin.has_focus():
			max_deg = min_deg
			if dock_slope_max_spin != null:
				dock_slope_max_spin.set_value_no_signal(max_deg)
		elif dock_slope_max_spin != null and dock_slope_max_spin.has_focus():
			min_deg = max_deg
			if dock_slope_min_spin != null:
				dock_slope_min_spin.set_value_no_signal(min_deg)
	SimpleTerrainSettings.save_slope_limits(min_deg, max_deg)
	slope_limits_changed.emit(min_deg, max_deg)


func set_dock_slope_limits(min_deg: float, max_deg: float, emit_signal_change: bool = true) -> void:
	var cl_min: float = clampf(minf(min_deg, max_deg), 0.0, 90.0)
	var cl_max: float = clampf(maxf(min_deg, max_deg), 0.0, 90.0)
	var cur_min: float = float(dock_slope_min_spin.value) if dock_slope_min_spin != null else -1.0
	var cur_max: float = float(dock_slope_max_spin.value) if dock_slope_max_spin != null else -1.0
	if absf(cur_min - cl_min) < 0.01 and absf(cur_max - cl_max) < 0.01:
		return
	if dock_slope_min_spin != null:
		dock_slope_min_spin.set_value_no_signal(cl_min)
	if dock_slope_max_spin != null:
		dock_slope_max_spin.set_value_no_signal(cl_max)
	SimpleTerrainSettings.save_slope_limits(cl_min, cl_max)
	if emit_signal_change:
		slope_limits_changed.emit(cl_min, cl_max)


func _ensure_presets_dir() -> void:
	if not DirAccess.dir_exists_absolute(FOLIAGE_PRESETS_DIR):
		DirAccess.make_dir_recursive_absolute(FOLIAGE_PRESETS_DIR)


# Drag & drop handling from FileSystem dock
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and (data as Dictionary).has("files"):
		var files: PackedStringArray = (data as Dictionary)["files"] as PackedStringArray
		for f: String in files:
			var ext: String = f.get_extension().to_lower()
			if ext in ["glb", "gltf", "tscn", "obj", "res", "tres", "png", "jpg", "jpeg", "webp"]:
				return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and (data as Dictionary).has("files"):
		var files: PackedStringArray = (data as Dictionary)["files"] as PackedStringArray
		for f: String in files:
			var ext: String = f.get_extension().to_lower()
			if ext in ["glb", "gltf", "tscn", "obj", "res", "tres"]:
				_on_model_file_selected(f)
			elif ext in ["png", "jpg", "jpeg", "webp"]:
				_on_texture_file_selected(f)


func _toggle_section(btn: Button, container: VBoxContainer, title: String) -> void:
	container.visible = not container.visible
	btn.text = ("▾ " if container.visible else "▸ ") + title
