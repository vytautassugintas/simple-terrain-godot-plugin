@tool
class_name SimpleTerrainFoliageSpatialGrid
extends RefCounted

## Lightweight 2D spatial hash grid for fast nearest-neighbor checks and radius queries during foliage scattering.

var cell_size: float = 2.0
var _grid: Dictionary = {} # Vector2i -> Array[int]
var _positions: Array[Vector2] = []


func _init(p_cell_size: float = 2.0) -> void:
	cell_size = maxf(p_cell_size, 0.5)


func clear() -> void:
	_grid.clear()
	_positions.clear()


func build(transforms: Array[Transform3D]) -> void:
	clear()
	_positions.resize(transforms.size())
	for i: int in range(transforms.size()):
		var p2: Vector2 = Vector2(transforms[i].origin.x, transforms[i].origin.z)
		_positions[i] = p2
		var cell: Vector2i = _get_cell(p2)
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(i)


func add_instance(idx: int, pos_xz: Vector2) -> void:
	if idx >= _positions.size():
		_positions.resize(idx + 1)
	_positions[idx] = pos_xz
	var cell: Vector2i = _get_cell(pos_xz)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(idx)


func is_too_close(pos_xz: Vector2, min_dist: float) -> bool:
	var min_dist_sq: float = min_dist * min_dist
	var center_cell: Vector2i = _get_cell(pos_xz)
	var radius_cells: int = int(ceil(min_dist / cell_size))

	for cz: int in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
		for cx: int in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
			var cell: Vector2i = Vector2i(cx, cz)
			var indices: Variant = _grid.get(cell, null)
			if indices == null:
				continue
			var cell_arr: Array = indices as Array
			for idx_var: Variant in cell_arr:
				var idx: int = int(idx_var)
				if idx >= 0 and idx < _positions.size():
					if _positions[idx].distance_squared_to(pos_xz) < min_dist_sq:
						return true
	return false


func query_radius(pos_xz: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var r2: float = radius * radius
	var center_cell: Vector2i = _get_cell(pos_xz)
	var cell_radius: int = int(ceil(radius / cell_size))

	for cz: int in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for cx: int in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			var cell: Vector2i = Vector2i(cx, cz)
			var indices: Variant = _grid.get(cell, null)
			if indices == null:
				continue
			var cell_arr: Array = indices as Array
			for idx_var: Variant in cell_arr:
				var idx: int = int(idx_var)
				if idx >= 0 and idx < _positions.size():
					if _positions[idx].distance_squared_to(pos_xz) <= r2:
						result.append(idx)
	return result


func _get_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell_size)), int(floor(p.y / cell_size)))
