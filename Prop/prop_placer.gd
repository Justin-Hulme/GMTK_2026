class_name PropPlacer
extends RefCounted

const SUBGRID_SIZE := 32
const TILE_GRID_SIZE := 8
const SUBCELLS_PER_TILE := 4
const SOURCE_ID := 0
const LARGE_PROPS := [
	{"atlas": Vector2i(1, 0), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(6, 0), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(8, 0), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(10, 2), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(8, 2), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(6, 2), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(4, 2), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(4, 4), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(0, 4), "size": Vector2i(2, 2)},
	{"atlas": Vector2i(2, 4), "size": Vector2i(2, 2)},
]
const TALL_PROPS := [
	{"atlas": Vector2i(0, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(3, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(4, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(5, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(10, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(13, 0), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(3, 2), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(2, 10), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(1, 10), "size": Vector2i(1, 2)},
	{"atlas": Vector2i(0, 10), "size": Vector2i(1, 2)},
]
const SMALL_PROPS := [
	{"atlas": Vector2i(11, 0), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(11, 1), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(12, 0), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(12, 2), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(2, 2), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(1, 2), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(1, 8), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(1, 9), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(2, 8), "size": Vector2i(1, 1)},
	{"atlas": Vector2i(3, 10), "size": Vector2i(1, 1)},
]


static func populate_generated_rooms(root_node: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for child in root_node.get_children():
		if child is Node2D:
			_populate_room(child as Node2D, rng)


static func _populate_room(room_node: Node2D, rng: RandomNumberGenerator) -> void:
	if not room_node.has_meta("prop_grid"):
		return
	var prop_layer := room_node.get_node_or_null("PropLayer") as TileMapLayer
	var floor_layer := room_node.get_node_or_null("TileMapLayer") as TileMapLayer
	if prop_layer == null:
		return
	if floor_layer == null:
		return

	var grid_data: Dictionary = room_node.get_meta("prop_grid")
	var cells: Array = grid_data.get("cells", [])
	if cells.is_empty():
		return
	var occupied := _create_occupied_grid(prop_layer)

	if _is_deadend_room(room_node):
		_try_place_prop(prop_layer, floor_layer, cells, occupied, LARGE_PROPS, rng)
		if rng.randf() < 0.6:
			_try_place_prop(prop_layer, floor_layer, cells, occupied, TALL_PROPS, rng)

	var candidates := _collect_candidates(cells, floor_layer, Vector2i.ONE, occupied)
	if candidates.is_empty():
		return

	candidates.shuffle()
	var target_count := 1 if room_node.name.begins_with("corridor_") else 3
	target_count = mini(target_count, candidates.size())
	for i in range(target_count):
		var tile_cell: Vector2i = candidates[i]
		var prop: Dictionary = SMALL_PROPS[rng.randi_range(0, SMALL_PROPS.size() - 1)]
		if _can_place_footprint(cells, floor_layer, tile_cell, prop.size, occupied):
			_place_prop(prop_layer, tile_cell, prop, occupied)


static func _collect_candidates(cells: Array, floor_layer: TileMapLayer, footprint: Vector2i, occupied: Array) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var used_cells: Array[Vector2i] = floor_layer.get_used_cells()
	if used_cells.is_empty():
		return candidates

	var min_x := used_cells[0].x
	var max_x := used_cells[0].x
	var min_y := used_cells[0].y
	var max_y := used_cells[0].y
	for tile_cell in used_cells:
		min_x = mini(min_x, tile_cell.x)
		max_x = maxi(max_x, tile_cell.x)
		min_y = mini(min_y, tile_cell.y)
		max_y = maxi(max_y, tile_cell.y)

	for tile_cell in used_cells:
		if tile_cell.x <= min_x or tile_cell.x >= max_x or tile_cell.y <= min_y or tile_cell.y >= max_y:
			continue
		if not _can_place_footprint(cells, floor_layer, tile_cell, footprint, occupied):
			continue
		candidates.append(tile_cell)
	return candidates


static func _try_place_prop(prop_layer: TileMapLayer, floor_layer: TileMapLayer, cells: Array, occupied: Array, prop_pool: Array, _rng: RandomNumberGenerator) -> bool:
	if prop_pool.is_empty():
		return false
	var shuffled_props := prop_pool.duplicate()
	shuffled_props.shuffle()
	for prop in shuffled_props:
		var candidates := _collect_candidates(cells, floor_layer, prop.size, occupied)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		_place_prop(prop_layer, candidates[0], prop, occupied)
		return true
	return false


static func _place_prop(prop_layer: TileMapLayer, tile_cell: Vector2i, prop: Dictionary, occupied: Array) -> void:
	prop_layer.set_cell(tile_cell, SOURCE_ID, prop.atlas, 0)
	_mark_occupied(occupied, tile_cell, prop.size)


static func _can_place_footprint(cells: Array, floor_layer: TileMapLayer, tile_cell: Vector2i, footprint: Vector2i, occupied: Array) -> bool:
	for y in range(tile_cell.y, tile_cell.y + footprint.y):
		for x in range(tile_cell.x, tile_cell.x + footprint.x):
			if x < 0 or y < 0 or x >= TILE_GRID_SIZE or y >= TILE_GRID_SIZE:
				return false
			if occupied[y][x]:
				return false
			if not _tile_is_open_floor(floor_layer, Vector2i(x, y)):
				return false
			if not _tile_chunk_is_empty(cells, x, y):
				return false
	return true


static func _tile_chunk_is_empty(cells: Array, tile_x: int, tile_y: int) -> bool:
	var start_x := tile_x * SUBCELLS_PER_TILE
	var start_y := tile_y * SUBCELLS_PER_TILE
	for y in range(start_y, start_y + SUBCELLS_PER_TILE):
		for x in range(start_x, start_x + SUBCELLS_PER_TILE):
			if cells[y][x] != PropGridBuilder.CellState.EMPTY:
				return false
	return true


static func _tile_is_open_floor(floor_layer: TileMapLayer, tile_cell: Vector2i) -> bool:
	var source_id := floor_layer.get_cell_source_id(tile_cell)
	if source_id == -1:
		return false
	var tile_set := floor_layer.tile_set
	if tile_set == null:
		return false
	var atlas_coords := floor_layer.get_cell_atlas_coords(tile_cell)
	var alternative := floor_layer.get_cell_alternative_tile(tile_cell)
	var source := tile_set.get_source(source_id)
	if source == null or not source.has_method("get_tile_data"):
		return false
	var tile_data = source.get_tile_data(atlas_coords, alternative)
	if tile_data == null:
		return false
	return tile_data.get_collision_polygons_count(0) == 0


static func _create_occupied_grid(prop_layer: TileMapLayer) -> Array:
	var occupied := []
	for y in range(TILE_GRID_SIZE):
		var row := []
		row.resize(TILE_GRID_SIZE)
		for x in range(TILE_GRID_SIZE):
			row[x] = false
		occupied.append(row)
	for cell in prop_layer.get_used_cells():
		if cell.x >= 0 and cell.y >= 0 and cell.x < TILE_GRID_SIZE and cell.y < TILE_GRID_SIZE:
			occupied[cell.y][cell.x] = true
	return occupied


static func _mark_occupied(occupied: Array, tile_cell: Vector2i, footprint: Vector2i) -> void:
	for y in range(tile_cell.y, tile_cell.y + footprint.y):
		for x in range(tile_cell.x, tile_cell.x + footprint.x):
			occupied[y][x] = true


static func _is_deadend_room(room_node: Node2D) -> bool:
	if room_node.name.begins_with("corridor_"):
		return false
	return room_node.name.contains("room_office") or room_node.name.contains("room_printers") or room_node.name.contains("room_bathroom")
