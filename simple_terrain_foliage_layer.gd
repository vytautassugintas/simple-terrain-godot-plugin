@tool
class_name SimpleTerrainFoliageLayer
extends Resource

## Custom resource representing a foliage or prop scattering layer in SimpleTerrain3D.
## Stores layer geometry, material, placement rules, and placed instance transforms.

const BINBUN_PRESET_NAMES: Array[String] = [
	"Binbun Grass 01 (Basic Green)",
	"Binbun Grass 02 (Fuzzy Lush)",
	"Binbun Grass 03 (Vibrant Meadow)",
	"Binbun Grass 04 (Golden Straw)",
	"Binbun Grass 05 (Dense Forest)",
	"Binbun Grass 06 (Stylized Pixel Green)",
	"Binbun Grass 07 (Autumn Meadow)",
	"Binbun Grass 08 (Soft Sprout)",
	"Binbun Grass 09 (Dry Savanna)",
	"Binbun Grass 10 (Deep Emerald)",
]

@export var layer_id: String = ""
@export var name: String = "Grass 01"
var layer_name: String:
	get: return name
	set(val): name = val
@export var source_scene_path: String = ""
@export var mesh: Mesh = null
@export var material: Material = null
@export var cast_shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
@export var visible: bool = true

@export_group("Instances")
@export var transforms: Array[Transform3D] = []

@export_group("Brush Placement Defaults")
@export_range(1.0, 50.0, 1.0) var density: float = 12.0
@export_range(0.05, 50.0, 0.05) var min_spacing: float = 0.25
@export_range(0.1, 5.0, 0.05) var min_scale: float = 0.8
@export_range(0.1, 5.0, 0.05) var max_scale: float = 1.3
@export var random_yaw: bool = true
@export_range(0.0, 1.0, 0.05) var align_to_normal: float = 0.5
@export_range(0.0, 45.0, 1.0) var random_tilt_deg: float = 5.0
@export_range(-2.0, 2.0, 0.01) var height_offset: float = -0.05
@export_range(5.0, 85.0, 1.0) var max_slope_deg: float = 40.0


func get_instance_count() -> int:
	return transforms.size()


func clear() -> void:
	transforms.clear()
	emit_changed()


func clone() -> SimpleTerrainFoliageLayer:
	var copy: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.new()
	copy.layer_id = layer_id
	copy.name = name
	copy.source_scene_path = source_scene_path
	copy.mesh = mesh
	copy.material = material
	copy.cast_shadow = cast_shadow
	copy.visible = visible
	copy.density = density
	copy.min_spacing = min_spacing
	copy.min_scale = min_scale
	copy.max_scale = max_scale
	copy.random_yaw = random_yaw
	copy.align_to_normal = align_to_normal
	copy.random_tilt_deg = random_tilt_deg
	copy.height_offset = height_offset
	copy.max_slope_deg = max_slope_deg
	copy.transforms = transforms.duplicate()
	return copy


static func create_default_grass_mesh(width: float = 0.4, height: float = 0.4) -> QuadMesh:
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, height)
	qm.subdivide_width = 2
	qm.subdivide_depth = 2
	qm.center_offset = Vector3(0.0, height * 0.5, 0.0)
	return qm


static func create_binbun_grass_preset(variant_index: int) -> SimpleTerrainFoliageLayer:
	var idx: int = clampi(variant_index, 1, 10)
	var layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.new()
	layer.layer_id = "binbun_grass_%02d" % idx
	if idx - 1 < BINBUN_PRESET_NAMES.size():
		layer.name = BINBUN_PRESET_NAMES[idx - 1]
	else:
		layer.name = "Binbun Grass %02d" % idx

	layer.mesh = create_default_grass_mesh(0.4, 0.4)
	var mat_path: String = "res://assets/asset_packs/BinbunGrass/src/materials/grass_%02d/grass_%02d.tres" % [idx, idx]
	if ResourceLoader.exists(mat_path):
		layer.material = load(mat_path) as Material
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.density = 14.0
	layer.min_spacing = 0.22
	layer.min_scale = 0.85
	layer.max_scale = 1.35
	layer.random_yaw = true
	layer.align_to_normal = 0.5
	layer.random_tilt_deg = 6.0
	layer.height_offset = -0.05
	layer.max_slope_deg = 42.0
	return layer


static func create_custom_layer(p_name: String, p_mesh: Mesh = null, p_mat: Material = null) -> SimpleTerrainFoliageLayer:
	var layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.new()
	layer.layer_id = "custom_" + str(Time.get_ticks_msec())
	layer.name = p_name
	layer.mesh = p_mesh if p_mesh != null else create_default_grass_mesh()
	layer.material = p_mat
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.density = 10.0
	layer.min_spacing = 0.3
	layer.min_scale = 0.8
	layer.max_scale = 1.2
	layer.random_yaw = true
	layer.align_to_normal = 0.5
	layer.random_tilt_deg = 5.0
	layer.height_offset = 0.0
	layer.max_slope_deg = 40.0
	return layer


static func extract_mesh_from_resource(res: Resource) -> Mesh:
	if res == null:
		return null
	if res is Mesh:
		return res as Mesh
	if res is PackedScene:
		var root: Node = (res as PackedScene).instantiate()
		if root == null:
			return null
		var mesh_instances: Array[MeshInstance3D] = []
		_find_mesh_instances(root, mesh_instances)

		if mesh_instances.is_empty():
			root.queue_free()
			return null

		if mesh_instances.size() == 1:
			var mi: MeshInstance3D = mesh_instances[0]
			var single_mesh: Mesh = mi.mesh
			var xform: Transform3D = _get_relative_transform(root, mi)
			if single_mesh != null and (xform != Transform3D.IDENTITY or mi.material_override != null):
				var copy_mesh: ArrayMesh = ArrayMesh.new()
				for s: int in range(single_mesh.get_surface_count()):
					var st: SurfaceTool = SurfaceTool.new()
					st.create_from(single_mesh, s)
					if xform != Transform3D.IDENTITY:
						st.transform(xform)
					var mat: Material = mi.material_override
					if mat == null:
						mat = single_mesh.surface_get_material(s)
					st.set_material(mat)
					copy_mesh = st.commit(copy_mesh)
				root.queue_free()
				return copy_mesh
			root.queue_free()
			return single_mesh

		var combined: ArrayMesh = ArrayMesh.new()
		for mi: MeshInstance3D in mesh_instances:
			if mi.mesh == null:
				continue
			var xform: Transform3D = _get_relative_transform(root, mi)
			for s: int in range(mi.mesh.get_surface_count()):
				var st: SurfaceTool = SurfaceTool.new()
				st.create_from(mi.mesh, s)
				if xform != Transform3D.IDENTITY:
					st.transform(xform)
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				st.set_material(mat)
				combined = st.commit(combined)

		root.queue_free()
		return combined
	return null


static func load_mesh_from_path(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	return extract_mesh_from_resource(res)


static func create_from_file(path: String) -> SimpleTerrainFoliageLayer:
	var m: Mesh = load_mesh_from_path(path)
	if m == null:
		return null
	var layer: SimpleTerrainFoliageLayer = SimpleTerrainFoliageLayer.new()
	layer.source_scene_path = path
	layer.mesh = m
	var base_name: String = path.get_file().get_basename()
	layer.layer_id = "layer_" + base_name.to_lower() + "_" + str(Time.get_ticks_msec())
	layer.name = base_name

	var aabb: AABB = m.get_aabb()
	var h_size: float = maxf(aabb.size.x, aabb.size.z)
	if h_size > 1.2:
		layer.min_spacing = minf(maxf(roundf(h_size * 0.35 * 10.0) / 10.0, 0.5), 2.5)
		layer.density = maxf(roundf(12.0 / layer.min_spacing), 2.0)
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		layer.align_to_normal = 0.25
		layer.random_tilt_deg = 3.0
		layer.min_scale = 0.85
		layer.max_scale = 1.25
		layer.height_offset = 0.0
		layer.max_slope_deg = 50.0
	else:
		layer.min_spacing = 0.25
		layer.density = 12.0
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.align_to_normal = 0.5
		layer.random_tilt_deg = 5.0
		layer.min_scale = 0.8
		layer.max_scale = 1.3
		layer.height_offset = -0.05
		layer.max_slope_deg = 45.0

	return layer


static func _find_mesh_instances(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out_list.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_mesh_instances(child, out_list)


static func _get_relative_transform(root_node: Node, target_node: Node) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var curr: Node = target_node
	while curr != null and curr != root_node:
		if curr is Node3D:
			xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform
