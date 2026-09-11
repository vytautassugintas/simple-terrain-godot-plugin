@tool
class_name SimpleTerrain3D
extends Node3D

## Simple 3D terrain node for sizing, sculpting, texture painting, and exporting meshes and textures.

signal terrain_modified()
signal terrain_rebuilt()
signal foliage_modified(layer_index: int)

enum SculptMode {
	RAISE,
	LOWER,
	SMOOTH,
	FLATTEN,
	NOISE,
	TERRACE,
	RAMP,
}

enum PaintMode {
	COLOR,
	TEXTURE,
}

enum FalloffType {
	SMOOTH = 0,
	LINEAR = 1,
	SPHERICAL = 2,
	FLAT = 3,
}

enum FoliageBrushMode {
	PAINT,
	ERASE,
	SELECT,
}

enum WireframeMode {
	TRIANGLES,
	QUADS,
}

enum SlopeCliffMode {
	COLOR,
	TEXTURE,
}

const DEFAULT_TERRAIN_SIZE: Vector2 = Vector2(64.0, 64.0)
const DEFAULT_RESOLUTION: Vector2i = Vector2i(64, 64)
const DEFAULT_TEXTURE_SIZE: Vector2i = Vector2i(1024, 1024)
const DEFAULT_BASE_COLOR: Color = Color(0.31, 0.52, 0.22, 1.0)
const DEFAULT_WIREFRAME_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)

@export_group("Terrain")
@export var terrain_size: Vector2:
	get:
		return data.terrain_size if data != null else DEFAULT_TERRAIN_SIZE
	set(value):
		set_terrain_size(value)

@export var resolution: Vector2i:
	get:
		return data.resolution if data != null else DEFAULT_RESOLUTION
	set(value):
		set_resolution(value)

@export var data: SimpleTerrainData:
	set(new_data):
		if data != null and is_instance_valid(data):
			if data.terrain_resized.is_connected(_on_data_terrain_resized):
				data.terrain_resized.disconnect(_on_data_terrain_resized)
		data = new_data
		if data != null:
			if not data.terrain_resized.is_connected(_on_data_terrain_resized):
				data.terrain_resized.connect(_on_data_terrain_resized)
		_cached_wireframe_indices.clear()
		if is_inside_tree():
			_load_or_create_data()
			rebuild_mesh()
			rebuild_all_foliage()
		update_configuration_warnings()

@export_group("Auto Slope Coloring")
@export var auto_slope_on_sculpt: bool = false
@export var slope_cliff_mode: SlopeCliffMode = SlopeCliffMode.TEXTURE
@export var slope_cliff_color: Color = Color(0.45, 0.45, 0.45, 1.0)
@export var slope_cliff_texture: Texture2D = null:
	set(value):
		slope_cliff_texture = value
		update_configuration_warnings()
@export_range(0.1, 64.0, 0.1) var slope_cliff_tiling: float = 4.0
@export_range(5.0, 85.0, 1.0) var slope_threshold_deg: float = 35.0
@export_range(1.0, 45.0, 1.0) var slope_blend_deg: float = 10.0
@export var slope_keep_flat_paint: bool = true
@export var slope_ground_color: Color = Color(0.28, 0.52, 0.22, 1.0)

@export_group("Display")
@export var show_wireframe: bool = false:
	set(value):
		show_wireframe = value
		_update_wireframe_visibility()

@export var wireframe_color: Color = DEFAULT_WIREFRAME_COLOR:
	set(value):
		wireframe_color = value
		_update_wireframe_material()

@export var wireframe_mode: WireframeMode = WireframeMode.TRIANGLES:
	set(value):
		wireframe_mode = value
		_cached_wireframe_indices.clear()
		if _is_wireframe_active():
			_update_wireframe()

@export var wireframe_in_game: bool = false:
	set(value):
		wireframe_in_game = value
		_update_wireframe_visibility()

@export_group("Collision")
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		if _static_body != null:
			_static_body.process_mode = Node.PROCESS_MODE_INHERIT if collision_enabled else Node.PROCESS_MODE_DISABLED
			if not collision_enabled and _collision_shape != null:
				_collision_shape.shape = null
			elif collision_enabled:
				update_collision()

@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		collision_layer = value
		if _static_body != null:
			_static_body.collision_layer = collision_layer

@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		if _static_body != null:
			_static_body.collision_mask = collision_mask

var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _wireframe_mesh_instance: MeshInstance3D
var _foliage_root: Node3D
var _foliage_multimeshes: Array[MultiMeshInstance3D] = []
var _foliage_grids: Array[SimpleTerrainFoliageSpatialGrid] = []

var _mesh: ArrayMesh
var _wireframe_mesh: ArrayMesh
var _image: Image
var _image_texture: ImageTexture
var _material: StandardMaterial3D
var _wireframe_material: StandardMaterial3D

var _cached_wireframe_indices: PackedInt32Array = PackedInt32Array()
var _cached_wireframe_res: Vector2i = Vector2i.ZERO
var _cached_wireframe_mode: WireframeMode = WireframeMode.TRIANGLES


func _ready() -> void:
	_ensure_internal_nodes()
	_load_or_create_data()
	rebuild_mesh()
	rebuild_all_foliage()
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if data == null:
		warnings.append("No SimpleTerrainData resource assigned. Create or assign a terrain data resource.")
	elif is_data_embedded():
		warnings.append("Terrain data is currently embedded inside the scene file, causing large scene files and editor save warnings.\nSave the terrain data to an external .res file using 'Save -> Save Terrain Data (*.res)...' on the terrain toolbar.")
	if is_slope_texture_embedded():
		warnings.append("Slope cliff texture is embedded inside the scene file as raw binary data, causing large scene files and save warnings.\nAssign a saved texture from the FileSystem or pattern library instead of an in-memory image.")
	return warnings


func is_data_embedded() -> bool:
	if data == null:
		return false
	return data.resource_path.is_empty() or "::" in data.resource_path


func is_slope_texture_embedded() -> bool:
	if slope_cliff_texture == null:
		return false
	return slope_cliff_texture.resource_path.is_empty() or "::" in slope_cliff_texture.resource_path


func _ensure_internal_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("TerrainMesh") as MeshInstance3D
		if _mesh_instance == null:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.name = "TerrainMesh"
			add_child(_mesh_instance)

	if _wireframe_mesh_instance == null:
		_wireframe_mesh_instance = get_node_or_null("TerrainWireframe") as MeshInstance3D
		if _wireframe_mesh_instance == null:
			_wireframe_mesh_instance = MeshInstance3D.new()
			_wireframe_mesh_instance.name = "TerrainWireframe"
			_wireframe_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_wireframe_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(_wireframe_mesh_instance)
	_wireframe_mesh_instance.visible = _is_wireframe_active()

	if _static_body == null:
		_static_body = get_node_or_null("TerrainCollision") as StaticBody3D
		if _static_body == null:
			_static_body = StaticBody3D.new()
			_static_body.name = "TerrainCollision"
			add_child(_static_body)

	_static_body.collision_layer = collision_layer
	_static_body.collision_mask = collision_mask
	if Engine.is_editor_hint():
		_static_body.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_static_body.process_mode = Node.PROCESS_MODE_INHERIT if collision_enabled else Node.PROCESS_MODE_DISABLED

	if _collision_shape == null:
		_collision_shape = _static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _collision_shape == null:
			_collision_shape = CollisionShape3D.new()
			_collision_shape.name = "CollisionShape3D"
			_static_body.add_child(_collision_shape)

	if _foliage_root == null:
		_foliage_root = get_node_or_null("TerrainFoliage") as Node3D
		if _foliage_root == null:
			_foliage_root = Node3D.new()
			_foliage_root.name = "TerrainFoliage"
			add_child(_foliage_root)


func _load_or_create_data() -> void:
	if data == null:
		data = SimpleTerrainData.new()
		data.init_default(DEFAULT_TERRAIN_SIZE, DEFAULT_RESOLUTION, DEFAULT_TEXTURE_SIZE, DEFAULT_BASE_COLOR)

	if not data.terrain_resized.is_connected(_on_data_terrain_resized):
		data.terrain_resized.connect(_on_data_terrain_resized)

	_image = data.load_image_from_data()
	if _image_texture == null or _image_texture.get_size() != Vector2(_image.get_size()):
		_image_texture = ImageTexture.create_from_image(_image)
	else:
		_image_texture.update(_image)

	_setup_material()


func _on_data_terrain_resized(_old_size: Vector2, _new_size: Vector2, _old_res: Vector2i, _new_res: Vector2i) -> void:
	_cached_wireframe_indices.clear()
	_image = data.load_image_from_data()
	if _image_texture == null or _image_texture.get_size() != Vector2(_image.get_size()):
		_image_texture = ImageTexture.create_from_image(_image)
	else:
		_image_texture.update(_image)
	_setup_material()
	rebuild_mesh()
	terrain_modified.emit()


func _setup_material() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.roughness = 0.85
		_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_material.albedo_texture = _image_texture
	if _mesh_instance != null:
		_mesh_instance.material_override = _material


func create_new_terrain(p_size: Vector2, p_res: Vector2i, p_tex_size: Vector2i, p_base_color: Color) -> void:
	_cached_wireframe_indices.clear()
	_ensure_internal_nodes()
	data = SimpleTerrainData.new()
	data.init_default(p_size, p_res, p_tex_size, p_base_color)
	_image = data.load_image_from_data()
	_image_texture = ImageTexture.create_from_image(_image)
	_setup_material()
	rebuild_mesh()


func set_terrain_size(p_size: Vector2) -> void:
	var clamped_size: Vector2 = Vector2(maxf(p_size.x, 0.1), maxf(p_size.y, 0.1))
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	if data.terrain_size == clamped_size:
		return
	data.resize_data(clamped_size, data.resolution)


func set_resolution(p_res: Vector2i) -> void:
	var clamped_res: Vector2i = Vector2i(maxi(p_res.x, 1), maxi(p_res.y, 1))
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	if data.resolution == clamped_res:
		return
	data.resize_data(data.terrain_size, clamped_res)


func resize_terrain(new_size: Vector2, new_res: Vector2i) -> void:
	_ensure_internal_nodes()
	if data == null:
		_load_or_create_data()
		data.init_default(new_size, new_res, DEFAULT_TEXTURE_SIZE, DEFAULT_BASE_COLOR)
		_image = data.load_image_from_data()
		_image_texture = ImageTexture.create_from_image(_image)
		_setup_material()
		rebuild_mesh()
		return
	data.resize_data(new_size, new_res)


func apply_resize_data(p_size: Vector2, p_res: Vector2i, p_heights: PackedFloat32Array, p_image_data: PackedByteArray) -> void:
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	data.terrain_size = p_size
	data.resolution = p_res
	data.height_data = p_heights.duplicate()
	data.image_data = p_image_data.duplicate()
	_cached_wireframe_indices.clear()
	_image = data.load_image_from_data()
	if _image_texture == null or _image_texture.get_size() != Vector2(_image.get_size()):
		_image_texture = ImageTexture.create_from_image(_image)
	else:
		_image_texture.update(_image)
	_setup_material()
	rebuild_mesh()
	terrain_modified.emit()


func rebuild_mesh() -> void:
	if data == null:
		return

	_ensure_internal_nodes()

	var arrays: Array = _build_mesh_arrays()
	if _mesh == null:
		_mesh = ArrayMesh.new()
	else:
		_mesh.clear_surfaces()

	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = _mesh
	_setup_material()
	update_collision()
	_update_wireframe(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL])
	terrain_rebuilt.emit()


func update_mesh_geometry() -> void:
	if data == null or _mesh_instance == null:
		return

	var arrays: Array = _build_mesh_arrays()
	if _mesh == null:
		_mesh = ArrayMesh.new()
	else:
		_mesh.clear_surfaces()

	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = _mesh
	if _is_wireframe_active():
		_update_wireframe(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL])
	terrain_modified.emit()


func update_collision() -> void:
	if not Engine.is_editor_hint() and not collision_enabled:
		return
	if _mesh == null or _collision_shape == null:
		return
	var trimesh: ConcavePolygonShape3D = _mesh.create_trimesh_shape()
	_collision_shape.shape = trimesh


func _build_mesh_arrays() -> Array:
	var num_x: int = data.resolution.x + 1
	var num_z: int = data.resolution.y + 1
	var total_verts: int = num_x * num_z

	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(total_verts)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(total_verts)
	var uvs: PackedVector2Array = PackedVector2Array()
	uvs.resize(total_verts)

	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	for iz: int in range(num_z):
		for ix: int in range(num_x):
			var idx: int = iz * num_x + ix
			var x: float = -half_x + float(ix) * dx
			var z: float = -half_z + float(iz) * dz
			var y: float = data.get_height(ix, iz)
			vertices[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(float(ix) / float(data.resolution.x), float(iz) / float(data.resolution.y))

			var h_l: float = data.get_height(ix - 1, iz)
			var h_r: float = data.get_height(ix + 1, iz)
			var h_d: float = data.get_height(ix, iz - 1)
			var h_u: float = data.get_height(ix, iz + 1)
			var tangent_x: Vector3 = Vector3(2.0 * dx, h_r - h_l, 0.0)
			var tangent_z: Vector3 = Vector3(0.0, h_u - h_d, 2.0 * dz)
			var n: Vector3 = tangent_z.cross(tangent_x).normalized()
			normals[idx] = n

	var total_indices: int = data.resolution.x * data.resolution.y * 6
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(total_indices)
	var cur_idx: int = 0
	for iz: int in range(data.resolution.y):
		for ix: int in range(data.resolution.x):
			var i0: int = iz * num_x + ix
			var i1: int = iz * num_x + (ix + 1)
			var i2: int = (iz + 1) * num_x + ix
			var i3: int = (iz + 1) * num_x + (ix + 1)

			indices[cur_idx] = i0
			indices[cur_idx + 1] = i1
			indices[cur_idx + 2] = i2
			indices[cur_idx + 3] = i1
			indices[cur_idx + 4] = i3
			indices[cur_idx + 5] = i2
			cur_idx += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func calculate_falloff(t: float, falloff_type: int = FalloffType.SMOOTH) -> float:
	match falloff_type:
		FalloffType.SMOOTH:
			return (cos(t * PI) + 1.0) * 0.5
		FalloffType.LINEAR:
			return 1.0 - t
		FalloffType.SPHERICAL:
			return sqrt(maxf(0.0, 1.0 - t * t))
		FalloffType.FLAT:
			return 1.0
		_:
			return (cos(t * PI) + 1.0) * 0.5


static func get_brush_falloff_weight(t: float, falloff_val: float) -> float:
	var ipreset: int = int(round(falloff_val))
	if absf(falloff_val - float(ipreset)) < 0.001 and ipreset >= 0 and ipreset <= 3:
		return calculate_falloff(t, ipreset)
	var cosine_falloff: float = (cos(t * PI) + 1.0) * 0.5
	var linear_falloff: float = 1.0 - t
	return lerpf(linear_falloff, cosine_falloff, clampf(falloff_val, 0.0, 1.0))


func sculpt(
	local_pos: Vector3,
	radius: float,
	strength: float,
	falloff: float,
	mode: SculptMode,
	delta: float,
	target_height: float = 0.0,
	step_size: float = 2.0,
	mask_image: Image = null,
	mask_angle: float = 0.0,
	mask_scale: float = 1.0,
	min_slope_deg: float = 0.0,
	max_slope_deg: float = 90.0
) -> void:
	if data == null:
		return

	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	var min_ix: int = data.clamp_x(int(floor((local_pos.x - radius + half_x) / dx)))
	var max_ix: int = data.clamp_x(int(ceil((local_pos.x + radius + half_x) / dx)))
	var min_iz: int = data.clamp_z(int(floor((local_pos.z - radius + half_z) / dz)))
	var max_iz: int = data.clamp_z(int(ceil((local_pos.z + radius + half_z) / dz)))

	var has_mask: bool = mask_image != null and not mask_image.is_empty()
	var mask_w: int = mask_image.get_width() if has_mask else 0
	var mask_h: int = mask_image.get_height() if has_mask else 0
	var cos_a: float = cos(-mask_angle) if has_mask else 1.0
	var sin_a: float = sin(-mask_angle) if has_mask else 0.0
	var inv_scale: float = 1.0 / maxf(mask_scale, 0.001) if has_mask else 1.0
	var check_slope: bool = (min_slope_deg > 0.01 or max_slope_deg < 89.99)

	var modified: bool = false

	for iz: int in range(min_iz, max_iz + 1):
		for ix: int in range(min_ix, max_ix + 1):
			var vx: float = -half_x + float(ix) * dx
			var vz: float = -half_z + float(iz) * dz
			var dist: float = Vector2(vx - local_pos.x, vz - local_pos.z).length()
			if dist > radius:
				continue

			if check_slope:
				var slope: float = get_slope_deg_at_local(vx, vz)
				if slope < min_slope_deg or slope > max_slope_deg:
					continue

			var t: float = dist / radius
			var w: float = get_brush_falloff_weight(t, falloff)

			if has_mask:
				var rel_x: float = (vx - local_pos.x) / radius
				var rel_z: float = (vz - local_pos.z) / radius
				var rot_x: float = (rel_x * cos_a - rel_z * sin_a) * inv_scale
				var rot_z: float = (rel_x * sin_a + rel_z * cos_a) * inv_scale
				var mu: float = rot_x * 0.5 + 0.5
				var mv: float = rot_z * 0.5 + 0.5
				if mu >= 0.0 and mu <= 1.0 and mv >= 0.0 and mv <= 1.0:
					var px: int = clampi(int(mu * float(mask_w - 1)), 0, mask_w - 1)
					var py: int = clampi(int(mv * float(mask_h - 1)), 0, mask_h - 1)
					var col: Color = mask_image.get_pixel(px, py)
					var stencil_val: float = col.a if (col.a < 0.999 or col.r == col.a) else (col.r * 0.299 + col.g * 0.587 + col.b * 0.114)
					w *= stencil_val
				else:
					w = 0.0

			if w <= 0.0001:
				continue

			var current_h: float = data.get_height(ix, iz)

			match mode:
				SculptMode.RAISE:
					data.set_height(ix, iz, current_h + strength * w * delta * 5.0)
					modified = true
				SculptMode.LOWER:
					data.set_height(ix, iz, current_h - strength * w * delta * 5.0)
					modified = true
				SculptMode.SMOOTH:
					var avg: float = (data.get_height(ix - 1, iz) + data.get_height(ix + 1, iz) + data.get_height(ix, iz - 1) + data.get_height(ix, iz + 1)) * 0.25
					var smooth_factor: float = clampf(strength * w * delta * 6.0, 0.0, 1.0)
					data.set_height(ix, iz, lerpf(current_h, avg, smooth_factor))
					modified = true
				SculptMode.FLATTEN:
					var flatten_factor: float = clampf(strength * w * delta * 6.0, 0.0, 1.0)
					data.set_height(ix, iz, lerpf(current_h, target_height, flatten_factor))
					modified = true
				SculptMode.NOISE:
					var seed_val: float = float(ix * 1337 + iz * 7331)
					var hash_noise: float = sin(seed_val * 0.123) * cos(seed_val * 0.321)
					data.set_height(ix, iz, current_h + hash_noise * strength * w * delta * 4.0)
					modified = true
				SculptMode.TERRACE:
					var step: float = maxf(step_size, 0.05)
					var target_step: float = roundf(current_h / step) * step
					var terrace_factor: float = clampf(strength * w * delta * 6.0, 0.0, 1.0)
					data.set_height(ix, iz, lerpf(current_h, target_step, terrace_factor))
					modified = true

	if modified:
		update_mesh_geometry()
		_conform_foliage_heights(local_pos.x - radius, local_pos.x + radius, local_pos.z - radius, local_pos.z + radius)
		if auto_slope_on_sculpt:
			var pad: float = radius + dx * 2.0
			apply_slope_coloring(
				slope_cliff_mode as int,
				slope_cliff_color,
				slope_cliff_texture.get_image() if slope_cliff_texture != null else null,
				slope_cliff_tiling,
				slope_threshold_deg,
				slope_blend_deg,
				true,
				slope_ground_color,
				Vector2(local_pos.x - pad, local_pos.z - pad),
				Vector2(local_pos.x + pad, local_pos.z + pad)
			)


func apply_ramp(
	point_a: Vector3,
	point_b: Vector3,
	width: float,
	falloff: float,
	crown: float = 0.0
) -> void:
	if data == null:
		return

	var a_2d: Vector2 = Vector2(point_a.x, point_a.z)
	var b_2d: Vector2 = Vector2(point_b.x, point_b.z)
	var dir_2d: Vector2 = b_2d - a_2d
	var ramp_length: float = dir_2d.length()
	if ramp_length < 0.01:
		return

	var u_dir: Vector2 = dir_2d / ramp_length
	var n_dir: Vector2 = Vector2(-u_dir.y, u_dir.x)
	var half_w: float = maxf(width * 0.5, 0.01)
	var total_half_extent: float = half_w + maxf(falloff, 0.0)

	var min_x: float = minf(a_2d.x, b_2d.x) - total_half_extent
	var max_x: float = maxf(a_2d.x, b_2d.x) + total_half_extent
	var min_z: float = minf(a_2d.y, b_2d.y) - total_half_extent
	var max_z: float = maxf(a_2d.y, b_2d.y) + total_half_extent

	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var half_terrain_x: float = data.terrain_size.x * 0.5
	var half_terrain_z: float = data.terrain_size.y * 0.5

	var min_ix: int = data.clamp_x(int(floor((min_x + half_terrain_x) / dx)))
	var max_ix: int = data.clamp_x(int(ceil((max_x + half_terrain_x) / dx)))
	var min_iz: int = data.clamp_z(int(floor((min_z + half_terrain_z) / dz)))
	var max_iz: int = data.clamp_z(int(ceil((max_z + half_terrain_z) / dz)))

	var modified: bool = false

	for iz: int in range(min_iz, max_iz + 1):
		for ix: int in range(min_ix, max_ix + 1):
			var vx: float = -half_terrain_x + float(ix) * dx
			var vz: float = -half_terrain_z + float(iz) * dz
			var v_pos: Vector2 = Vector2(vx, vz)
			var rel: Vector2 = v_pos - a_2d
			var t_along: float = rel.dot(u_dir)
			var dist_perp: float = absf(rel.dot(n_dir))

			if dist_perp > total_half_extent:
				continue
			if t_along < -falloff or t_along > ramp_length + falloff:
				continue

			var w_lat: float = 1.0
			if dist_perp > half_w:
				if falloff > 0.001:
					var t_lat: float = (dist_perp - half_w) / falloff
					w_lat = (cos(t_lat * PI) + 1.0) * 0.5
				else:
					w_lat = 0.0

			var w_long: float = 1.0
			if t_along < 0.0:
				if falloff > 0.001:
					var t_end: float = -t_along / falloff
					w_long = (cos(t_end * PI) + 1.0) * 0.5
				else:
					w_long = 0.0
			elif t_along > ramp_length:
				if falloff > 0.001:
					var t_end: float = (t_along - ramp_length) / falloff
					w_long = (cos(t_end * PI) + 1.0) * 0.5
				else:
					w_long = 0.0

			var total_w: float = w_lat * w_long
			if total_w <= 0.0001:
				continue

			var t_clamped: float = clampf(t_along / ramp_length, 0.0, 1.0)
			var h_base: float = lerpf(point_a.y, point_b.y, t_clamped)
			var crown_offset: float = 0.0
			if crown != 0.0 and dist_perp < half_w:
				var r: float = dist_perp / half_w
				crown_offset = crown * (1.0 - r * r)
			var target_h: float = h_base + crown_offset
			var cur_h: float = data.get_height(ix, iz)
			data.set_height(ix, iz, lerpf(cur_h, target_h, total_w))
			modified = true

	if modified:
		update_mesh_geometry()
		_conform_foliage_heights(min_x, max_x, min_z, max_z)
		update_collision()
		if auto_slope_on_sculpt:
			apply_slope_coloring(
				slope_cliff_mode as int,
				slope_cliff_color,
				slope_cliff_texture.get_image() if slope_cliff_texture != null else null,
				slope_cliff_tiling,
				slope_threshold_deg,
				slope_blend_deg,
				true,
				slope_ground_color,
				Vector2(min_x, min_z),
				Vector2(max_x, max_z)
			)
		terrain_modified.emit()


func paint_color(
	local_pos: Vector3,
	radius: float,
	strength: float,
	falloff: float,
	color: Color,
	brush_image: Image = null,
	brush_angle: float = 0.0,
	min_slope_deg: float = 0.0,
	max_slope_deg: float = 90.0,
	_delta: float = 0.0
) -> void:
	if data == null or _image == null:
		return

	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	var u: float = (local_pos.x + half_x) / data.terrain_size.x
	var v: float = (local_pos.z + half_z) / data.terrain_size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return

	var tw: int = _image.get_width()
	var th: int = _image.get_height()
	var center_px: float = u * float(tw)
	var center_py: float = v * float(th)
	var pixel_radius: float = (radius / data.terrain_size.x) * float(tw)
	if pixel_radius < 1.0:
		pixel_radius = 1.0

	var min_px: int = clampi(int(floor(center_px - pixel_radius)), 0, tw - 1)
	var max_px: int = clampi(int(ceil(center_px + pixel_radius)), 0, tw - 1)
	var min_py: int = clampi(int(floor(center_py - pixel_radius)), 0, th - 1)
	var max_py: int = clampi(int(ceil(center_py + pixel_radius)), 0, th - 1)

	var pr2: float = pixel_radius * pixel_radius
	var inv_pr: float = 1.0 / pixel_radius
	var modified: bool = false

	var has_brush: bool = (brush_image != null and not brush_image.is_empty())
	var brush_w: int = brush_image.get_width() if has_brush else 1
	var brush_h: int = brush_image.get_height() if has_brush else 1
	var brush_rot_rad: float = deg_to_rad(brush_angle)
	var b_cos: float = cos(brush_rot_rad)
	var b_sin: float = sin(brush_rot_rad)
	var check_slope: bool = (min_slope_deg > 0.01 or max_slope_deg < 89.99)

	for py: int in range(min_py, max_py + 1):
		var dy: float = float(py) - center_py
		var dy2: float = dy * dy
		if not has_brush and dy2 > pr2:
			continue

		for px: int in range(min_px, max_px + 1):
			var dx: float = float(px) - center_px

			if check_slope:
				var loc_x: float = (float(px) / float(tw)) * data.terrain_size.x - half_x
				var loc_z: float = (float(py) / float(th)) * data.terrain_size.y - half_z
				var slope: float = get_slope_deg_at_local(loc_x, loc_z)
				if slope < min_slope_deg or slope > max_slope_deg:
					continue

			var w: float = 0.0
			if has_brush:
				var rot_bx: float = dx * b_cos - dy * b_sin
				var rot_by: float = dx * b_sin + dy * b_cos
				var u_b: float = (rot_bx / pixel_radius) * 0.5 + 0.5
				var v_b: float = (rot_by / pixel_radius) * 0.5 + 0.5
				if u_b < 0.0 or u_b >= 1.0 or v_b < 0.0 or v_b >= 1.0:
					continue
				var bx: int = clampi(int(u_b * float(brush_w)), 0, brush_w - 1)
				var by: int = clampi(int(v_b * float(brush_h)), 0, brush_h - 1)
				var b_col: Color = brush_image.get_pixel(bx, by)
				var b_alpha: float = b_col.a if (b_col.a < 0.999 or b_col.r == b_col.a) else (b_col.r * 0.299 + b_col.g * 0.587 + b_col.b * 0.114)
				if b_alpha <= 0.001:
					continue
				w = clampf(b_alpha * strength, 0.0, 1.0)
			else:
				var d2: float = dx * dx + dy2
				if d2 > pr2:
					continue
				var d: float = sqrt(d2)
				var t: float = d * inv_pr
				w = clampf(get_brush_falloff_weight(t, falloff) * strength, 0.0, 1.0)

			if w <= 0.0001:
				continue

			var cur_color: Color = _image.get_pixel(px, py)
			var new_color: Color = cur_color.lerp(color, w)
			_image.set_pixel(px, py, new_color)
			modified = true

	if modified:
		_image_texture.update(_image)
		terrain_modified.emit()


func paint_texture(
	local_pos: Vector3,
	radius: float,
	strength: float,
	falloff: float,
	stamp_image: Image,
	tiling: float,
	angle: float = 0.0,
	brush_image: Image = null,
	brush_angle: float = 0.0,
	min_slope_deg: float = 0.0,
	max_slope_deg: float = 90.0,
	_delta: float = 0.0
) -> void:
	if data == null or _image == null or stamp_image == null or stamp_image.is_empty():
		return

	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	var u: float = (local_pos.x + half_x) / data.terrain_size.x
	var v: float = (local_pos.z + half_z) / data.terrain_size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return

	var tw: int = _image.get_width()
	var th: int = _image.get_height()
	var center_px: float = u * float(tw)
	var center_py: float = v * float(th)
	var pixel_radius: float = (radius / data.terrain_size.x) * float(tw)
	if pixel_radius < 1.0:
		pixel_radius = 1.0

	var min_px: int = clampi(int(floor(center_px - pixel_radius)), 0, tw - 1)
	var max_px: int = clampi(int(ceil(center_px + pixel_radius)), 0, tw - 1)
	var min_py: int = clampi(int(floor(center_py - pixel_radius)), 0, th - 1)
	var max_py: int = clampi(int(ceil(center_py + pixel_radius)), 0, th - 1)

	var stamp_w: int = stamp_image.get_width()
	var stamp_h: int = stamp_image.get_height()
	var pr2: float = pixel_radius * pixel_radius
	var inv_pr: float = 1.0 / pixel_radius
	var inv_tw: float = 1.0 / float(tw)
	var inv_th: float = 1.0 / float(th)
	var stamp_w_f: float = float(stamp_w)
	var stamp_h_f: float = float(stamp_h)
	var step_u: float = inv_tw * tiling * stamp_w_f
	var step_v: float = inv_th * tiling * stamp_h_f

	var rot_rad: float = deg_to_rad(angle)
	var cos_a: float = cos(rot_rad)
	var sin_a: float = sin(rot_rad)

	var has_brush: bool = (brush_image != null and not brush_image.is_empty())
	var brush_w: int = brush_image.get_width() if has_brush else 1
	var brush_h: int = brush_image.get_height() if has_brush else 1
	var brush_rot_rad: float = deg_to_rad(brush_angle)
	var b_cos: float = cos(brush_rot_rad)
	var b_sin: float = sin(brush_rot_rad)
	var check_slope: bool = (min_slope_deg > 0.01 or max_slope_deg < 89.99)

	var modified: bool = false

	for py: int in range(min_py, max_py + 1):
		var dy: float = float(py) - center_py
		var dy2: float = dy * dy
		if not has_brush and dy2 > pr2:
			continue

		for px: int in range(min_px, max_px + 1):
			var dx: float = float(px) - center_px

			if check_slope:
				var loc_x: float = (float(px) / float(tw)) * data.terrain_size.x - half_x
				var loc_z: float = (float(py) / float(th)) * data.terrain_size.y - half_z
				var slope: float = get_slope_deg_at_local(loc_x, loc_z)
				if slope < min_slope_deg or slope > max_slope_deg:
					continue

			var w: float = 0.0
			if has_brush:
				var rot_bx: float = dx * b_cos - dy * b_sin
				var rot_by: float = dx * b_sin + dy * b_cos
				var u_b: float = (rot_bx / pixel_radius) * 0.5 + 0.5
				var v_b: float = (rot_by / pixel_radius) * 0.5 + 0.5
				if u_b < 0.0 or u_b >= 1.0 or v_b < 0.0 or v_b >= 1.0:
					continue
				var bx: int = clampi(int(u_b * float(brush_w)), 0, brush_w - 1)
				var by: int = clampi(int(v_b * float(brush_h)), 0, brush_h - 1)
				var b_col: Color = brush_image.get_pixel(bx, by)
				var b_alpha: float = b_col.a if (b_col.a < 0.999 or b_col.r == b_col.a) else (b_col.r * 0.299 + b_col.g * 0.587 + b_col.b * 0.114)
				if b_alpha <= 0.001:
					continue
				w = clampf(b_alpha * strength, 0.0, 1.0)
			else:
				var d2: float = dx * dx + dy2
				if d2 > pr2:
					continue
				var d: float = sqrt(d2)
				var t: float = d * inv_pr
				w = clampf(get_brush_falloff_weight(t, falloff) * strength, 0.0, 1.0)

			if w <= 0.0001:
				continue

			var rot_dx: float = dx * cos_a - dy * sin_a
			var rot_dy: float = dx * sin_a + dy * cos_a

			var stamp_px: int = int((rot_dx + center_px) * step_u) % stamp_w
			if stamp_px < 0:
				stamp_px += stamp_w

			var stamp_py: int = int((rot_dy + center_py) * step_v) % stamp_h
			if stamp_py < 0:
				stamp_py += stamp_h

			var target_color: Color = stamp_image.get_pixel(stamp_px, stamp_py)
			var cur_color: Color = _image.get_pixel(px, py)
			var new_color: Color = cur_color.lerp(target_color, w)
			_image.set_pixel(px, py, new_color)
			modified = true

	if modified:
		_image_texture.update(_image)
		terrain_modified.emit()


func generate_from_noise(noise: FastNoiseLite, amplitude: float, flatten_edges: bool = true) -> void:
	if data == null or noise == null:
		return

	var num_x: int = data.resolution.x + 1
	var num_z: int = data.resolution.y + 1
	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	for iz: int in range(num_z):
		for ix: int in range(num_x):
			var vx: float = -half_x + float(ix) * dx
			var vz: float = -half_z + float(iz) * dz
			var h: float = noise.get_noise_2d(vx, vz) * amplitude

			if flatten_edges:
				var edge_x: float = cos((absf(vx) / half_x) * PI * 0.5)
				var edge_z: float = cos((absf(vz) / half_z) * PI * 0.5)
				h *= clampf(edge_x * edge_z, 0.0, 1.0)

			data.set_height(ix, iz, h)

	update_mesh_geometry()
	update_collision()
	terrain_modified.emit()


func flatten_all(target_height: float = 0.0) -> void:
	if data == null:
		return
	var total: int = data.height_data.size()
	for i: int in range(total):
		data.height_data[i] = target_height
	update_mesh_geometry()
	update_collision()
	terrain_modified.emit()


func clear_texture_to_color(base_color: Color) -> void:
	if data == null or _image == null:
		return
	_image.fill(base_color)
	_image_texture.update(_image)
	sync_image_data()
	terrain_modified.emit()


func sync_image_data() -> void:
	if data != null and _image != null and not _image.is_empty():
		data.save_image_to_data(_image)


func export_to_gltf(path: String) -> Error:
	if _mesh == null:
		return ERR_UNCONFIGURED

	var base_name: String = path.get_file().get_basename().strip_edges()
	if base_name.is_empty():
		base_name = name if not name.is_empty() else "terrain"

	var export_node: MeshInstance3D = MeshInstance3D.new()
	export_node.name = base_name
	export_node.mesh = _mesh

	var export_mat: StandardMaterial3D = StandardMaterial3D.new()
	export_mat.resource_name = base_name + "_material"
	export_mat.roughness = 0.85
	export_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	export_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if _image != null and not _image.is_empty():
		var export_tex: ImageTexture = ImageTexture.create_from_image(_image)
		export_tex.resource_name = base_name + "_albedo"
		export_mat.albedo_texture = export_tex
	elif _image_texture != null:
		var export_tex: Texture2D = _image_texture.duplicate()
		export_tex.resource_name = base_name + "_albedo"
		export_mat.albedo_texture = export_tex

	export_node.material_override = export_mat

	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = doc.append_from_scene(export_node, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)

	export_node.free()
	return err


func save_mesh_to_file(path: String) -> Error:
	if _mesh == null:
		return ERR_UNCONFIGURED
	return ResourceSaver.save(_mesh, path)


func save_texture_to_file(path: String) -> Error:
	if _image == null or _image.is_empty():
		return ERR_UNCONFIGURED
	return _image.save_png(path)


func save_data_to_file(path: String) -> Error:
	if data == null:
		return ERR_UNCONFIGURED
	if _image != null and not _image.is_empty():
		data.save_image_to_data(_image)
	data.take_over_path(path)
	var err: Error = ResourceSaver.save(data, path)
	if err == OK:
		data.resource_path = path
		update_configuration_warnings()
	return err


func get_mesh() -> ArrayMesh:
	return _mesh


func get_image() -> Image:
	return _image


func get_image_texture() -> ImageTexture:
	return _image_texture


func get_terrain_size() -> Vector2:
	return data.terrain_size if data != null else DEFAULT_TERRAIN_SIZE


func get_resolution() -> Vector2i:
	return data.resolution if data != null else DEFAULT_RESOLUTION


func get_texture_size() -> Vector2i:
	return data.texture_size if data != null else DEFAULT_TEXTURE_SIZE


func get_height_at_local(local_pos: Vector3) -> float:
	if data == null:
		return 0.0
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5
	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var ix: int = data.clamp_x(int(round((local_pos.x + half_x) / dx)))
	var iz: int = data.clamp_z(int(round((local_pos.z + half_z) / dz)))
	return data.get_height(ix, iz)


func get_height_bilinear(local_x: float, local_z: float) -> float:
	if data == null or data.height_data.is_empty() or data.resolution.x <= 0 or data.resolution.y <= 0:
		return 0.0
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5
	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)
	var gx: float = clampf((local_x + half_x) / dx, 0.0, float(data.resolution.x))
	var gz: float = clampf((local_z + half_z) / dz, 0.0, float(data.resolution.y))
	var ix0: int = clampi(int(floor(gx)), 0, data.resolution.x)
	var iz0: int = clampi(int(floor(gz)), 0, data.resolution.y)
	var ix1: int = mini(ix0 + 1, data.resolution.x)
	var iz1: int = mini(iz0 + 1, data.resolution.y)
	var fx: float = gx - float(ix0)
	var fz: float = gz - float(iz0)
	var h00: float = data.get_height(ix0, iz0)
	var h10: float = data.get_height(ix1, iz0)
	var h01: float = data.get_height(ix0, iz1)
	var h11: float = data.get_height(ix1, iz1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func get_normal_at_local(local_x: float, local_z: float) -> Vector3:
	if data == null or data.resolution.x <= 0 or data.resolution.y <= 0:
		return Vector3.UP
	var eps: float = maxf(data.terrain_size.x / float(data.resolution.x) * 0.5, 0.1)
	var hl: float = get_height_bilinear(local_x - eps, local_z)
	var hr: float = get_height_bilinear(local_x + eps, local_z)
	var hd: float = get_height_bilinear(local_x, local_z - eps)
	var hu: float = get_height_bilinear(local_x, local_z + eps)
	var tx: Vector3 = Vector3(2.0 * eps, hr - hl, 0.0)
	var tz: Vector3 = Vector3(0.0, hu - hd, 2.0 * eps)
	var n: Vector3 = tz.cross(tx).normalized()
	return n if n.length_squared() > 0.001 else Vector3.UP


func get_slope_deg_at_local(local_x: float, local_z: float) -> float:
	var n: Vector3 = get_normal_at_local(local_x, local_z)
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))


# --- Foliage MultiMesh Management ---

func get_foliage_layer_count() -> int:
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	return data.get_foliage_layer_count()


func get_foliage_layer(index: int) -> SimpleTerrainFoliageLayer:
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	return data.get_foliage_layer(index)


func get_foliage_layers() -> Array[SimpleTerrainFoliageLayer]:
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	return data.foliage_layers


func add_foliage_layer(layer: SimpleTerrainFoliageLayer) -> int:
	if layer == null:
		return -1
	if data == null:
		_ensure_internal_nodes()
		_load_or_create_data()
	var idx: int = data.add_foliage_layer(layer)
	sync_foliage_multimesh(idx)
	foliage_modified.emit(idx)
	return idx


func remove_foliage_layer(index: int) -> void:
	if data == null or index < 0 or index >= data.foliage_layers.size():
		return
	data.remove_foliage_layer(index)
	rebuild_all_foliage()
	foliage_modified.emit(-1)


func insert_foliage_layer(index: int, layer: SimpleTerrainFoliageLayer) -> void:
	if data == null or layer == null:
		return
	data.insert_foliage_layer(index, layer)
	rebuild_all_foliage()
	foliage_modified.emit(-1)


func set_layer_transforms(layer_index: int, new_transforms: Array[Transform3D]) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer != null:
		layer.transforms = new_transforms.duplicate()
		if layer_index < _foliage_grids.size() and _foliage_grids[layer_index] != null:
			_foliage_grids[layer_index].build(layer.transforms)
		sync_foliage_multimesh(layer_index)
		foliage_modified.emit(layer_index)


func get_layer_transforms(layer_index: int) -> Array[Transform3D]:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return []
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	return layer.transforms.duplicate() if layer != null else []


func rebuild_all_foliage() -> void:
	_ensure_internal_nodes()
	if _foliage_root == null:
		return

	for child: Node in _foliage_root.get_children():
		child.queue_free()
	_foliage_multimeshes.clear()
	_foliage_grids.clear()

	if data == null:
		return

	for i: int in range(data.foliage_layers.size()):
		sync_foliage_multimesh(i)


func rebuild_foliage_layer(layer_index: int) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	if layer_index < _foliage_grids.size() and _foliage_grids[layer_index] != null:
		var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
		if layer != null:
			_foliage_grids[layer_index].build(layer.transforms)
	sync_foliage_multimesh(layer_index)


func sync_foliage_multimesh(layer_index: int) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	_ensure_internal_nodes()
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null:
		return

	while _foliage_multimeshes.size() <= layer_index:
		_foliage_multimeshes.append(null)

	var mm_inst: MultiMeshInstance3D = _foliage_multimeshes[layer_index]
	var node_name: String = "FoliageLayer_%d" % layer_index
	if mm_inst == null or not is_instance_valid(mm_inst):
		mm_inst = _foliage_root.get_node_or_null(node_name) as MultiMeshInstance3D
		if mm_inst == null:
			mm_inst = MultiMeshInstance3D.new()
			mm_inst.name = node_name
			_foliage_root.add_child(mm_inst)
		_foliage_multimeshes[layer_index] = mm_inst

	mm_inst.visible = layer.visible
	mm_inst.cast_shadow = layer.cast_shadow
	mm_inst.material_override = layer.material

	var count: int = layer.transforms.size()
	var mm: MultiMesh = mm_inst.multimesh
	var target_mesh: Mesh = layer.mesh if layer.mesh != null else SimpleTerrainFoliageLayer.create_default_grass_mesh()
	if mm == null or mm.mesh != target_mesh:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = target_mesh
		mm_inst.multimesh = mm

	if mm.instance_count != count:
		mm.instance_count = count

	for i: int in range(count):
		mm.set_instance_transform(i, layer.transforms[i])


func get_foliage_multimesh_instance(layer_index: int) -> MultiMeshInstance3D:
	if layer_index >= 0 and layer_index < _foliage_multimeshes.size():
		return _foliage_multimeshes[layer_index]
	return null


func set_foliage_layer_visible(layer_index: int, is_visible: bool) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer != null:
		layer.visible = is_visible
		if layer_index < _foliage_multimeshes.size() and _foliage_multimeshes[layer_index] != null:
			_foliage_multimeshes[layer_index].visible = is_visible
		foliage_modified.emit(layer_index)


func find_closest_foliage_instance(
	layer_index: int,
	ray_origin: Vector3,
	ray_dir: Vector3,
	max_dist: float = 3.0
) -> Dictionary:
	var result: Dictionary = {
		"layer_index": -1,
		"instance_index": -1,
		"distance": INF,
		"hit_point": Vector3.ZERO
	}
	if data == null:
		return result

	var layers_to_check: Array[int] = []
	if layer_index >= 0 and layer_index < data.foliage_layers.size():
		layers_to_check.append(layer_index)
	elif layer_index == -1:
		for i: int in range(data.foliage_layers.size()):
			if data.foliage_layers[i].visible:
				layers_to_check.append(i)

	var terrain_gt: Transform3D = global_transform if is_inside_tree() else transform
	var closest_ray_dist: float = INF
	var closest_proj: float = INF

	for l_idx: int in layers_to_check:
		var layer: SimpleTerrainFoliageLayer = data.foliage_layers[l_idx]
		if layer == null or not layer.visible:
			continue

		var mesh_radius: float = 0.5
		if layer.mesh != null:
			var aabb: AABB = layer.mesh.get_aabb()
			mesh_radius = maxf(maxf(aabb.size.x, aabb.size.z) * 0.5, 0.4)

		for i: int in range(layer.transforms.size()):
			var local_xform: Transform3D = layer.transforms[i]
			var world_pos: Vector3 = terrain_gt * local_xform.origin

			var to_pt: Vector3 = world_pos - ray_origin
			var proj: float = to_pt.dot(ray_dir)
			if proj <= 0.0:
				continue

			var closest_on_ray: Vector3 = ray_origin + ray_dir * proj
			var dist: float = world_pos.distance_to(closest_on_ray)

			var effective_threshold: float = max_dist * maxf(local_xform.basis.get_scale().x, 0.5) * mesh_radius * 2.0
			effective_threshold = maxf(effective_threshold, 1.2)

			if dist < effective_threshold:
				if proj < closest_proj:
					closest_ray_dist = dist
					closest_proj = proj
					result["layer_index"] = l_idx
					result["instance_index"] = i
					result["distance"] = dist
					result["hit_point"] = world_pos
				elif is_equal_approx(proj, closest_proj) and dist < closest_ray_dist:
					closest_ray_dist = dist
					closest_proj = proj
					result["layer_index"] = l_idx
					result["instance_index"] = i
					result["distance"] = dist
					result["hit_point"] = world_pos

	return result


func get_foliage_instance_transform(layer_index: int, instance_index: int) -> Transform3D:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return Transform3D.IDENTITY
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null or instance_index < 0 or instance_index >= layer.transforms.size():
		return Transform3D.IDENTITY
	return layer.transforms[instance_index]


func set_foliage_instance_transform(layer_index: int, instance_index: int, new_xform: Transform3D) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null or instance_index < 0 or instance_index >= layer.transforms.size():
		return
	layer.transforms[instance_index] = new_xform

	# Update multimesh instance transform
	if layer_index < _foliage_multimeshes.size():
		var mm_inst: MultiMeshInstance3D = _foliage_multimeshes[layer_index]
		if mm_inst != null and mm_inst.multimesh != null and instance_index < mm_inst.multimesh.instance_count:
			mm_inst.multimesh.set_instance_transform(instance_index, new_xform)

	# Update spatial hash grid
	if layer_index < _foliage_grids.size() and _foliage_grids[layer_index] != null:
		_foliage_grids[layer_index].build(layer.transforms)

	foliage_modified.emit(layer_index)


func delete_foliage_instance(layer_index: int, instance_index: int) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null or instance_index < 0 or instance_index >= layer.transforms.size():
		return
	layer.transforms.remove_at(instance_index)
	rebuild_foliage_layer(layer_index)
	foliage_modified.emit(layer_index)


func align_foliage_instance_to_surface(layer_index: int, instance_index: int) -> Transform3D:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return Transform3D.IDENTITY
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null or instance_index < 0 or instance_index >= layer.transforms.size():
		return Transform3D.IDENTITY

	var xform: Transform3D = layer.transforms[instance_index]
	var cur_scale: Vector3 = xform.basis.get_scale()
	var cur_yaw: float = xform.basis.get_euler().y

	var terrain_h: float = get_height_at_local(xform.origin)
	xform.origin.y = terrain_h + layer.height_offset

	var norm: Vector3 = get_normal_at_local(xform.origin.x, xform.origin.z)
	var blended_up: Vector3 = Vector3.UP.slerp(norm, layer.align_to_normal).normalized()

	var basis: Basis = Basis()
	basis = basis.rotated(Vector3.UP, cur_yaw)

	var current_up: Vector3 = basis.y.normalized()
	if not current_up.is_equal_approx(blended_up):
		var axis: Vector3 = current_up.cross(blended_up)
		if axis.length_squared() > 0.0001:
			var angle: float = current_up.angle_to(blended_up)
			basis = Basis(axis.normalized(), angle) * basis

	basis = basis.scaled(cur_scale)
	xform.basis = basis

	set_foliage_instance_transform(layer_index, instance_index, xform)
	return xform


func _get_or_create_foliage_grid(layer_index: int) -> SimpleTerrainFoliageSpatialGrid:
	while _foliage_grids.size() <= layer_index:
		_foliage_grids.append(null)
	var grid: SimpleTerrainFoliageSpatialGrid = _foliage_grids[layer_index]
	if grid == null:
		grid = SimpleTerrainFoliageSpatialGrid.new(2.0)
		if data != null and layer_index >= 0 and layer_index < data.foliage_layers.size():
			var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
			if layer != null:
				grid.build(layer.transforms)
		_foliage_grids[layer_index] = grid
	return grid


func paint_foliage(
	local_pos: Vector3,
	radius: float,
	layer_index: int,
	density: float,
	min_spacing: float,
	min_scale: float,
	max_scale: float,
	align_to_normal: float,
	max_slope_deg: float,
	height_offset: float,
	random_yaw: bool,
	random_tilt_deg: float
) -> int:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return 0
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer == null:
		return 0

	var grid: SimpleTerrainFoliageSpatialGrid = _get_or_create_foliage_grid(layer_index)
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5

	# Ensure layer is visible so placed instances immediately show up
	if not layer.visible:
		set_foliage_layer_visible(layer_index, true)

	var target_count: int = maxi(int(density), 1)
	var added_count: int = 0
	var max_candidates: int = 20

	for item_i: int in range(target_count):
		var item_placed: bool = false
		for cand: int in range(max_candidates):
			var px: float
			var pz: float
			# On the first item and first candidate, place directly at cursor position!
			if item_i == 0 and cand == 0 and (target_count <= 2 or radius < 1.0):
				px = local_pos.x
				pz = local_pos.z
			else:
				var ang: float = randf() * TAU
				var dist: float = radius * sqrt(randf())
				px = local_pos.x + cos(ang) * dist
				pz = local_pos.z + sin(ang) * dist

			if px < -half_x or px > half_x or pz < -half_z or pz > half_z:
				continue

			var p2: Vector2 = Vector2(px, pz)
			if min_spacing > 0.05 and grid.is_too_close(p2, min_spacing):
				continue

			var norm: Vector3 = get_normal_at_local(px, pz)
			var slope_deg: float = rad_to_deg(acos(clampf(norm.y, -1.0, 1.0)))
			if slope_deg > max_slope_deg:
				continue

			var py: float = get_height_bilinear(px, pz) + height_offset

			# Orientation
			var up_vec: Vector3 = Vector3.UP.slerp(norm, clampf(align_to_normal, 0.0, 1.0)).normalized()
			var forward_vec: Vector3 = Vector3.FORWARD
			if absf(up_vec.dot(forward_vec)) > 0.99:
				forward_vec = Vector3.RIGHT
			var right_vec: Vector3 = up_vec.cross(forward_vec).normalized()
			forward_vec = right_vec.cross(up_vec).normalized()

			var b: Basis = Basis(right_vec, up_vec, forward_vec)
			if random_yaw:
				b = b.rotated(up_vec, randf() * TAU)
			if random_tilt_deg > 0.01:
				var tilt_axis: Vector3 = right_vec.rotated(up_vec, randf() * TAU).normalized()
				var tilt_angle: float = deg_to_rad(randf_range(-random_tilt_deg, random_tilt_deg))
				b = b.rotated(tilt_axis, tilt_angle)

			var s: float = randf_range(min_scale, max_scale)
			b = b.scaled(Vector3(s, s, s))

			var xform: Transform3D = Transform3D(b, Vector3(px, py, pz))
			layer.transforms.append(xform)
			grid.add_instance(layer.transforms.size() - 1, p2)
			added_count += 1
			item_placed = true
			break

		# If we couldn't place any more instances in this stroke due to spacing/density saturation, stop trying
		if not item_placed and added_count == 0 and target_count > 1 and item_i > 2:
			break

	if added_count > 0:
		sync_foliage_multimesh(layer_index)
		foliage_modified.emit(layer_index)

	return added_count


func erase_foliage(local_pos: Vector3, radius: float, layer_index: int = -1) -> int:
	if data == null:
		return 0

	var total_erased: int = 0
	var r2: float = radius * radius
	var p2: Vector2 = Vector2(local_pos.x, local_pos.z)

	var start_idx: int = 0
	var end_idx: int = data.foliage_layers.size()
	if layer_index >= 0 and layer_index < data.foliage_layers.size():
		start_idx = layer_index
		end_idx = layer_index + 1

	for l_idx: int in range(start_idx, end_idx):
		var layer: SimpleTerrainFoliageLayer = data.foliage_layers[l_idx]
		if layer == null or layer.transforms.is_empty():
			continue

		var new_transforms: Array[Transform3D] = []
		var erased_in_layer: int = 0

		for t: Transform3D in layer.transforms:
			var dx: float = t.origin.x - p2.x
			var dz: float = t.origin.z - p2.y
			if (dx * dx + dz * dz) <= r2:
				erased_in_layer += 1
			else:
				new_transforms.append(t)

		if erased_in_layer > 0:
			layer.transforms = new_transforms
			if l_idx < _foliage_grids.size() and _foliage_grids[l_idx] != null:
				_foliage_grids[l_idx].build(layer.transforms)
			sync_foliage_multimesh(l_idx)
			foliage_modified.emit(l_idx)
			total_erased += erased_in_layer

	return total_erased


func clear_foliage_layer(layer_index: int) -> void:
	if data == null or layer_index < 0 or layer_index >= data.foliage_layers.size():
		return
	var layer: SimpleTerrainFoliageLayer = data.foliage_layers[layer_index]
	if layer != null:
		layer.clear()
		if layer_index < _foliage_grids.size() and _foliage_grids[layer_index] != null:
			_foliage_grids[layer_index].clear()
		sync_foliage_multimesh(layer_index)
		foliage_modified.emit(layer_index)


func clear_all_foliage() -> void:
	if data == null:
		return
	for i: int in range(data.foliage_layers.size()):
		clear_foliage_layer(i)


func _conform_foliage_heights(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	if data == null:
		return
	for l_idx: int in range(data.foliage_layers.size()):
		var layer: SimpleTerrainFoliageLayer = data.foliage_layers[l_idx]
		if layer == null or layer.transforms.is_empty():
			continue
		var modified: bool = false
		for i: int in range(layer.transforms.size()):
			var x: float = layer.transforms[i].origin.x
			var z: float = layer.transforms[i].origin.z
			if x >= min_x and x <= max_x and z >= min_z and z <= max_z:
				var new_y: float = get_height_bilinear(x, z) + layer.height_offset
				layer.transforms[i].origin.y = new_y
				modified = true
		if modified:
			sync_foliage_multimesh(l_idx)
			foliage_modified.emit(l_idx)


func get_wireframe_mesh() -> ArrayMesh:
	return _wireframe_mesh


func set_wireframe_visible(p_visible: bool) -> void:
	show_wireframe = p_visible


func _is_wireframe_active() -> bool:
	if not show_wireframe:
		return false
	if Engine.is_editor_hint():
		return true
	return wireframe_in_game


func _update_wireframe_visibility() -> void:
	var active: bool = _is_wireframe_active()
	if _wireframe_mesh_instance != null:
		_wireframe_mesh_instance.visible = active
	if active and (_wireframe_mesh == null or _wireframe_mesh.get_surface_count() == 0):
		_update_wireframe()


func _update_wireframe_material() -> void:
	if _wireframe_material == null:
		_wireframe_material = StandardMaterial3D.new()
		_wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wireframe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wireframe_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_wireframe_material.render_priority = 1

	_wireframe_material.albedo_color = wireframe_color
	if _wireframe_mesh_instance != null:
		_wireframe_mesh_instance.material_override = _wireframe_material


func _get_wireframe_indices() -> PackedInt32Array:
	if (
		_cached_wireframe_res == data.resolution
		and _cached_wireframe_mode == wireframe_mode
		and not _cached_wireframe_indices.is_empty()
	):
		return _cached_wireframe_indices

	var num_x: int = data.resolution.x + 1
	var num_z: int = data.resolution.y + 1
	var res_x: int = data.resolution.x
	var res_z: int = data.resolution.y

	var line_count: int = num_z * res_x + res_z * num_x
	if wireframe_mode == WireframeMode.TRIANGLES:
		line_count += res_z * res_x

	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(line_count * 2)
	var idx: int = 0

	# Horizontal line segments (along X)
	for iz: int in range(num_z):
		var row_offset: int = iz * num_x
		for ix: int in range(res_x):
			indices[idx] = row_offset + ix
			indices[idx + 1] = row_offset + ix + 1
			idx += 2

	# Vertical line segments (along Z)
	for iz: int in range(res_z):
		var row_offset: int = iz * num_x
		var next_row_offset: int = (iz + 1) * num_x
		for ix: int in range(num_x):
			indices[idx] = row_offset + ix
			indices[idx + 1] = next_row_offset + ix
			idx += 2

	# Diagonal line segments for triangulation
	if wireframe_mode == WireframeMode.TRIANGLES:
		for iz: int in range(res_z):
			var row_offset: int = iz * num_x
			var next_row_offset: int = (iz + 1) * num_x
			for ix: int in range(res_x):
				indices[idx] = row_offset + ix + 1
				indices[idx + 1] = next_row_offset + ix
				idx += 2

	_cached_wireframe_indices = indices
	_cached_wireframe_res = data.resolution
	_cached_wireframe_mode = wireframe_mode
	return _cached_wireframe_indices


func _build_wireframe_arrays(base_vertices: PackedVector3Array, normals: PackedVector3Array) -> Array:
	var total_verts: int = base_vertices.size()
	var wire_verts: PackedVector3Array = PackedVector3Array()
	wire_verts.resize(total_verts)

	# Slight normal offset avoids Z-fighting against terrain triangles
	const NORMAL_OFFSET: float = 0.015
	for i: int in range(total_verts):
		wire_verts[i] = base_vertices[i] + normals[i] * NORMAL_OFFSET

	var line_indices: PackedInt32Array = _get_wireframe_indices()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = wire_verts
	arrays[Mesh.ARRAY_INDEX] = line_indices
	return arrays


func _update_wireframe(base_vertices: PackedVector3Array = PackedVector3Array(), normals: PackedVector3Array = PackedVector3Array()) -> void:
	if not _is_wireframe_active():
		if _wireframe_mesh_instance != null:
			_wireframe_mesh_instance.hide()
		return

	_ensure_internal_nodes()

	if base_vertices.is_empty() or normals.is_empty():
		var mesh_arrays: Array = _build_mesh_arrays()
		base_vertices = mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		normals = mesh_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array

	var wire_arrays: Array = _build_wireframe_arrays(base_vertices, normals)
	if _wireframe_mesh == null:
		_wireframe_mesh = ArrayMesh.new()
	else:
		_wireframe_mesh.clear_surfaces()

	_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, wire_arrays)
	_wireframe_mesh_instance.mesh = _wireframe_mesh
	_update_wireframe_material()
	_wireframe_mesh_instance.show()


func apply_auto_slope_coloring() -> void:
	var cliff_img: Image = null
	if slope_cliff_texture != null:
		cliff_img = slope_cliff_texture.get_image()
	apply_slope_coloring(
		slope_cliff_mode as int,
		slope_cliff_color,
		cliff_img,
		slope_cliff_tiling,
		slope_threshold_deg,
		slope_blend_deg,
		slope_keep_flat_paint,
		slope_ground_color
	)


func apply_slope_coloring(
	cliff_mode: int,
	cliff_color: Color,
	cliff_image: Image,
	cliff_tiling: float,
	threshold_deg: float,
	blend_deg: float,
	keep_flat_paint: bool,
	ground_color: Color,
	rect_min: Vector2 = Vector2(-INF, -INF),
	rect_max: Vector2 = Vector2(INF, INF)
) -> void:
	if data == null or _image == null:
		return

	var tw: int = _image.get_width()
	var th: int = _image.get_height()
	var half_x: float = data.terrain_size.x * 0.5
	var half_z: float = data.terrain_size.y * 0.5
	var dx: float = data.terrain_size.x / float(data.resolution.x)
	var dz: float = data.terrain_size.y / float(data.resolution.y)

	var rad_to_deg_factor: float = 180.0 / PI
	var min_angle: float = threshold_deg - blend_deg
	var max_angle: float = threshold_deg + blend_deg
	var inv_angle_range: float = 1.0 / (max_angle - min_angle) if max_angle > min_angle else 1.0

	var has_cliff_texture: bool = (cliff_mode == 1 and cliff_image != null and not cliff_image.is_empty())
	var cliff_w: int = cliff_image.get_width() if has_cliff_texture else 1
	var cliff_h: int = cliff_image.get_height() if has_cliff_texture else 1

	var is_partial: bool = (rect_min.x > -INF)
	var min_qx: int = 0
	var max_qx: int = data.resolution.x - 1
	var min_qz: int = 0
	var max_qz: int = data.resolution.y - 1

	if is_partial:
		min_qx = clampi(int(floor((rect_min.x + half_x) / dx)), 0, data.resolution.x - 1)
		max_qx = clampi(int(ceil((rect_max.x + half_x) / dx)), 0, data.resolution.x - 1)
		min_qz = clampi(int(floor((rect_min.y + half_z) / dz)), 0, data.resolution.y - 1)
		max_qz = clampi(int(ceil((rect_max.y + half_z) / dz)), 0, data.resolution.y - 1)

	# Precompute vertex slope angles for the active quads
	var v_start_x: int = min_qx
	var v_end_x: int = max_qx + 1
	var v_start_z: int = min_qz
	var v_end_z: int = max_qz + 1
	var v_span_x: int = v_end_x - v_start_x + 1
	var v_span_z: int = v_end_z - v_start_z + 1

	var vert_angles: PackedFloat32Array = PackedFloat32Array()
	vert_angles.resize(v_span_x * v_span_z)

	var two_dx: float = 2.0 * dx
	var two_dz: float = 2.0 * dz

	for vz: int in range(v_start_z, v_end_z + 1):
		var vz_offset: int = (vz - v_start_z) * v_span_x
		for vx: int in range(v_start_x, v_end_x + 1):
			var hl: float = data.get_height(vx - 1, vz)
			var hr: float = data.get_height(vx + 1, vz)
			var hd: float = data.get_height(vx, vz - 1)
			var hu: float = data.get_height(vx, vz + 1)

			var n: Vector3 = Vector3((hl - hr) / two_dx, 1.0, (hd - hu) / two_dz).normalized()
			var angle_deg: float = acos(clampf(n.y, -1.0, 1.0)) * rad_to_deg_factor
			vert_angles[vz_offset + (vx - v_start_x)] = angle_deg

	# Quad-level processing
	for qz: int in range(min_qz, max_qz + 1):
		var row0: int = (qz - v_start_z) * v_span_x
		var row1: int = (qz + 1 - v_start_z) * v_span_x

		var min_py: int = clampi(int(floor(float(qz) / float(data.resolution.y) * float(th))), 0, th - 1)
		var max_py: int = clampi(int(ceil(float(qz + 1) / float(data.resolution.y) * float(th))), 0, th - 1)

		for qx: int in range(min_qx, max_qx + 1):
			var col: int = qx - v_start_x
			var a00: float = vert_angles[row0 + col]
			var a10: float = vert_angles[row0 + col + 1]
			var a01: float = vert_angles[row1 + col]
			var a11: float = vert_angles[row1 + col + 1]

			var max_quad_angle: float = maxf(maxf(a00, a10), maxf(a01, a11))
			if keep_flat_paint and max_quad_angle <= min_angle:
				continue

			var min_px: int = clampi(int(floor(float(qx) / float(data.resolution.x) * float(tw))), 0, tw - 1)
			var max_px: int = clampi(int(ceil(float(qx + 1) / float(data.resolution.x) * float(tw))), 0, tw - 1)

			for py: int in range(min_py, max_py + 1):
				var ty: float = (float(py) + 0.5) / float(th) * float(data.resolution.y) - float(qz)
				ty = clampf(ty, 0.0, 1.0)
				var a_left: float = lerpf(a00, a01, ty)
				var a_right: float = lerpf(a10, a11, ty)

				for px: int in range(min_px, max_px + 1):
					var tx: float = (float(px) + 0.5) / float(tw) * float(data.resolution.x) - float(qx)
					tx = clampf(tx, 0.0, 1.0)
					var angle: float = lerpf(a_left, a_right, tx)

					if angle <= min_angle:
						if not keep_flat_paint:
							_image.set_pixel(px, py, ground_color)
						continue

					var cliff_sample: Color = cliff_color
					if has_cliff_texture:
						var uv_x: float = (float(px) / float(tw)) * cliff_tiling
						var uv_y: float = (float(py) / float(th)) * cliff_tiling
						var cx: int = int(floor(fposmod(uv_x, 1.0) * float(cliff_w)))
						var cy: int = int(floor(fposmod(uv_y, 1.0) * float(cliff_h)))
						cliff_sample = cliff_image.get_pixel(cx, cy)

					if angle >= max_angle:
						_image.set_pixel(px, py, cliff_sample)
					else:
						var factor: float = clampf((angle - min_angle) * inv_angle_range, 0.0, 1.0)
						var base: Color = _image.get_pixel(px, py) if keep_flat_paint else ground_color
						var blended: Color = base.lerp(cliff_sample, factor)
						_image.set_pixel(px, py, blended)

	if _image_texture == null or _image_texture.get_size() != Vector2(_image.get_size()):
		_image_texture = ImageTexture.create_from_image(_image)
		if _material != null:
			_material.albedo_texture = _image_texture
	else:
		_image_texture.update(_image)
	terrain_modified.emit()



