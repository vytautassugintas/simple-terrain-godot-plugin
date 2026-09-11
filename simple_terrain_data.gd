@tool
class_name SimpleTerrainData
extends Resource

## Data resource storing terrain dimensions, heightfield data, and painted texture bytes.

signal terrain_resized(old_size: Vector2, new_size: Vector2, old_res: Vector2i, new_res: Vector2i)

const DEFAULT_BASE_COLOR: Color = Color(0.31, 0.52, 0.22, 1.0) # Earthy grass green

@export var terrain_size: Vector2 = Vector2(64.0, 64.0):
	set(val):
		if val.x <= 0.0 or val.y <= 0.0:
			return
		if terrain_size == val:
			return
		if _is_resizing or height_data.is_empty():
			terrain_size = val
			return
		resize_data(val, resolution)

@export var resolution: Vector2i = Vector2i(64, 64):
	set(val):
		var clamped_val: Vector2i = Vector2i(maxi(val.x, 1), maxi(val.y, 1))
		if resolution == clamped_val:
			return
		if _is_resizing or height_data.is_empty():
			resolution = clamped_val
			return
		resize_data(terrain_size, clamped_val)

@export var texture_size: Vector2i = Vector2i(1024, 1024)
@export var height_data: PackedFloat32Array = PackedFloat32Array()
@export var image_data: PackedByteArray = PackedByteArray()
@export var foliage_layers: Array[SimpleTerrainFoliageLayer] = []

var _is_resizing: bool = false


func init_default(p_size: Vector2, p_res: Vector2i, p_tex_size: Vector2i, p_base_color: Color = DEFAULT_BASE_COLOR) -> void:
	_is_resizing = true
	terrain_size = p_size
	resolution = Vector2i(maxi(p_res.x, 1), maxi(p_res.y, 1))
	texture_size = p_tex_size

	var num_verts_x: int = resolution.x + 1
	var num_verts_z: int = resolution.y + 1
	var total_verts: int = num_verts_x * num_verts_z

	height_data.resize(total_verts)
	height_data.fill(0.0)

	var base_img: Image = Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	base_img.fill(p_base_color)
	save_image_to_data(base_img)
	_is_resizing = false
	emit_changed()


func resize_data(new_size: Vector2, new_res: Vector2i, base_color: Color = DEFAULT_BASE_COLOR) -> void:
	if _is_resizing:
		return

	new_size = Vector2(maxf(new_size.x, 0.1), maxf(new_size.y, 0.1))
	new_res = Vector2i(maxi(new_res.x, 1), maxi(new_res.y, 1))

	if terrain_size == new_size and resolution == new_res and not height_data.is_empty():
		return

	_is_resizing = true

	var old_size: Vector2 = terrain_size
	var old_res: Vector2i = resolution
	var old_heights: PackedFloat32Array = height_data.duplicate()

	var old_num_x: int = old_res.x + 1
	var old_num_z: int = old_res.y + 1
	var old_dx: float = old_size.x / float(old_res.x)
	var old_dz: float = old_size.y / float(old_res.y)
	var old_half_x: float = old_size.x * 0.5
	var old_half_z: float = old_size.y * 0.5

	var new_num_x: int = new_res.x + 1
	var new_num_z: int = new_res.y + 1
	var new_total_verts: int = new_num_x * new_num_z
	var new_dx: float = new_size.x / float(new_res.x)
	var new_dz: float = new_size.y / float(new_res.y)
	var new_half_x: float = new_size.x * 0.5
	var new_half_z: float = new_size.y * 0.5

	var new_heights: PackedFloat32Array = PackedFloat32Array()
	new_heights.resize(new_total_verts)

	var inv_old_dx: float = 1.0 / old_dx
	var inv_old_dz: float = 1.0 / old_dz
	const EPS: float = 0.0001

	if old_heights.size() == old_num_x * old_num_z and not old_heights.is_empty():
		for new_iz: int in range(new_num_z):
			var z: float = -new_half_z + float(new_iz) * new_dz
			var row_offset: int = new_iz * new_num_x
			for new_ix: int in range(new_num_x):
				var x: float = -new_half_x + float(new_ix) * new_dx

				# Check if (x, z) is outside old terrain bounds
				if x < -old_half_x - EPS or x > old_half_x + EPS or z < -old_half_z - EPS or z > old_half_z + EPS:
					new_heights[row_offset + new_ix] = 0.0
					continue

				# Bilinear interpolation in old heightfield
				var gx: float = clampf((x + old_half_x) * inv_old_dx, 0.0, float(old_res.x))
				var gz: float = clampf((z + old_half_z) * inv_old_dz, 0.0, float(old_res.y))

				var ix0: int = clampi(int(floor(gx)), 0, old_res.x)
				var iz0: int = clampi(int(floor(gz)), 0, old_res.y)
				var ix1: int = mini(ix0 + 1, old_res.x)
				var iz1: int = mini(iz0 + 1, old_res.y)

				var fx: float = gx - float(ix0)
				var fz: float = gz - float(iz0)

				var idx00: int = iz0 * old_num_x + ix0
				var idx10: int = iz0 * old_num_x + ix1
				var idx01: int = iz1 * old_num_x + ix0
				var idx11: int = iz1 * old_num_x + ix1

				var h00: float = old_heights[idx00]
				var h10: float = old_heights[idx10]
				var h01: float = old_heights[idx01]
				var h11: float = old_heights[idx11]

				var h_bottom: float = lerpf(h00, h10, fx)
				var h_top: float = lerpf(h01, h11, fx)
				new_heights[row_offset + new_ix] = lerpf(h_bottom, h_top, fz)
	else:
		new_heights.fill(0.0)

	# If terrain_size changed, resample texture additively so painted features don't stretch
	if new_size != old_size:
		var old_img: Image = load_image_from_data()
		if old_img != null and not old_img.is_empty():
			var tw: int = texture_size.x
			var th: int = texture_size.y
			var new_img: Image = Image.create(tw, th, false, Image.FORMAT_RGBA8)
			new_img.fill(base_color)

			var old_tw: int = old_img.get_width()
			var old_th: int = old_img.get_height()
			var inv_tw: float = 1.0 / float(tw)
			var inv_th: float = 1.0 / float(th)

			for py: int in range(th):
				var v_new: float = (float(py) + 0.5) * inv_th
				var z: float = -new_half_z + v_new * new_size.y
				if z < -old_half_z - EPS or z > old_half_z + EPS:
					continue
				var v_old: float = clampf((z + old_half_z) / old_size.y, 0.0, 1.0)
				var py_old: int = clampi(int(v_old * float(old_th)), 0, old_th - 1)

				for px: int in range(tw):
					var u_new: float = (float(px) + 0.5) * inv_tw
					var x: float = -new_half_x + u_new * new_size.x
					if x < -old_half_x - EPS or x > old_half_x + EPS:
						continue
					var u_old: float = clampf((x + old_half_x) / old_size.x, 0.0, 1.0)
					var px_old: int = clampi(int(u_old * float(old_tw)), 0, old_tw - 1)

					new_img.set_pixel(px, py, old_img.get_pixel(px_old, py_old))

			save_image_to_data(new_img)

	terrain_size = new_size
	resolution = new_res
	height_data = new_heights

	_is_resizing = false
	emit_changed()
	terrain_resized.emit(old_size, new_size, old_res, new_res)


func get_index(ix: int, iz: int) -> int:
	var num_verts_x: int = resolution.x + 1
	return iz * num_verts_x + ix


func clamp_x(ix: int) -> int:
	return clampi(ix, 0, resolution.x)


func clamp_z(iz: int) -> int:
	return clampi(iz, 0, resolution.y)


func get_height(ix: int, iz: int) -> float:
	var c_ix: int = clamp_x(ix)
	var c_iz: int = clamp_z(iz)
	var idx: int = get_index(c_ix, c_iz)
	if idx >= 0 and idx < height_data.size():
		return height_data[idx]
	return 0.0


func set_height(ix: int, iz: int, val: float) -> void:
	var c_ix: int = clamp_x(ix)
	var c_iz: int = clamp_z(iz)
	var idx: int = get_index(c_ix, c_iz)
	if idx >= 0 and idx < height_data.size():
		height_data[idx] = val


func save_image_to_data(img: Image) -> void:
	if img != null and not img.is_empty():
		image_data = img.save_png_to_buffer()


func load_image_from_data() -> Image:
	var img: Image = Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	if image_data.size() > 0:
		var err: Error = img.load_png_from_buffer(image_data)
		if err == OK:
			return img
	img.fill(DEFAULT_BASE_COLOR)
	return img


func get_foliage_layer_count() -> int:
	return foliage_layers.size()


func get_foliage_layer(index: int) -> SimpleTerrainFoliageLayer:
	if index >= 0 and index < foliage_layers.size():
		return foliage_layers[index]
	return null


func add_foliage_layer(layer: SimpleTerrainFoliageLayer) -> int:
	if layer == null:
		return -1
	foliage_layers.append(layer)
	emit_changed()
	return foliage_layers.size() - 1


func remove_foliage_layer(index: int) -> void:
	if index >= 0 and index < foliage_layers.size():
		foliage_layers.remove_at(index)
		emit_changed()


func insert_foliage_layer(index: int, layer: SimpleTerrainFoliageLayer) -> void:
	if layer == null:
		return
	var idx: int = clampi(index, 0, foliage_layers.size())
	foliage_layers.insert(idx, layer)
	emit_changed()


func clear_all_foliage() -> void:
	for layer: SimpleTerrainFoliageLayer in foliage_layers:
		if layer != null:
			layer.clear()
	emit_changed()
