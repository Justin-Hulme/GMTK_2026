class_name PropGridBuilder
extends RefCounted

const GRID_SIZE := 32
const ROOM_LOCAL_SIZE := 128.0
const DOOR_CLEAR_RADIUS := 2
const DOOR_CLEAR_DEPTH := 5

enum CellState {
	EMPTY,
	FULL,
	MARGIN,
}


static func build_for_generated_rooms(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Node2D:
			_build_for_room(child as Node2D)


static func _build_for_room(room_node: Node2D) -> void:
	if not (room_node.name.begins_with("room_") or room_node.name.begins_with("corridor_")):
		return

	var tilemap := room_node.get_node_or_null("TileMapLayer") as TileMapLayer
	if tilemap == null:
		return

	var prop_layer := room_node.get_node_or_null("PropLayer") as TileMapLayer
	if prop_layer != null:
		prop_layer.clear()

	var grid := _create_empty_grid()
	_mark_collision_cells(grid, room_node, tilemap)
	_mark_no_prop_cells(grid, room_node.get_node_or_null("NoPropLayer") as TileMapLayer)
	var door_markers := _get_door_markers(room_node)
	for marker in door_markers:
		_mark_door_margin(grid, marker)
	if room_node.name.begins_with("corridor_"):
		_mark_corridor_margin(grid, door_markers)

	room_node.set_meta("prop_grid", {
		"grid_size": GRID_SIZE,
		"room_local_size": ROOM_LOCAL_SIZE,
		"cell_size": ROOM_LOCAL_SIZE / float(GRID_SIZE),
		"cells": grid,
	})


static func _create_empty_grid() -> Array:
	var grid := []
	for y in range(GRID_SIZE):
		var row := []
		row.resize(GRID_SIZE)
		for x in range(GRID_SIZE):
			row[x] = CellState.EMPTY
		grid.append(row)
	return grid


static func _mark_collision_cells(grid: Array, _room_node: Node2D, tilemap: TileMapLayer) -> void:
	var tile_set := tilemap.tile_set
	if tile_set == null:
		return
	for tile_cell in tilemap.get_used_cells():
		var source_id := tilemap.get_cell_source_id(tile_cell)
		if source_id == -1:
			continue
		var atlas_coords := tilemap.get_cell_atlas_coords(tile_cell)
		var alternative := tilemap.get_cell_alternative_tile(tile_cell)
		var source := tile_set.get_source(source_id)
		if source == null or not source.has_method("get_tile_data"):
			continue
		var tile_data = source.get_tile_data(atlas_coords, alternative)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(0) <= 0:
			continue
		_mark_tile_chunk_full(grid, tile_cell)


static func _mark_tile_chunk_full(grid: Array, tile_cell: Vector2i) -> void:
	var start_x := tile_cell.x * 4
	var start_y := tile_cell.y * 4
	for y in range(start_y, start_y + 4):
		for x in range(start_x, start_x + 4):
			if x < 0 or y < 0 or x >= GRID_SIZE or y >= GRID_SIZE:
				continue
			grid[y][x] = CellState.FULL


static func _mark_no_prop_cells(grid: Array, no_prop_layer: TileMapLayer) -> void:
	if no_prop_layer == null:
		return
	for tile_cell in no_prop_layer.get_used_cells():
		var start_x := tile_cell.x * 4
		var start_y := tile_cell.y * 4
		for y in range(start_y, start_y + 4):
			for x in range(start_x, start_x + 4):
				_mark_margin_cell(grid, Vector2i(x, y))


static func _get_door_markers(room_node: Node2D) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in room_node.get_children():
		if child is Marker2D and child.name.begins_with("door_"):
			markers.append(child as Marker2D)
	return markers


static func _mark_door_margin(grid: Array, marker: Marker2D) -> void:
	var direction := marker.name.trim_prefix("door_").to_upper().substr(0, 1)
	var center := _local_to_grid(marker.position)
	for depth in range(DOOR_CLEAR_DEPTH + 1):
		for lateral in range(-DOOR_CLEAR_RADIUS, DOOR_CLEAR_RADIUS + 1):
			var grid_pos := center
			match direction:
				"N":
					grid_pos.x += lateral
					grid_pos.y += depth
				"S":
					grid_pos.x += lateral
					grid_pos.y -= depth
				"E":
					grid_pos.x -= depth
					grid_pos.y += lateral
				"W":
					grid_pos.x += depth
					grid_pos.y += lateral
			_mark_margin_cell(grid, grid_pos)


static func _mark_corridor_margin(grid: Array, door_markers: Array[Marker2D]) -> void:
	if door_markers.size() < 2:
		return
	for i in range(door_markers.size()):
		for j in range(i + 1, door_markers.size()):
			_mark_line_margin(grid, _local_to_grid(door_markers[i].position), _local_to_grid(door_markers[j].position))


static func _mark_line_margin(grid: Array, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var delta := to_cell - from_cell
	var steps := maxi(abs(delta.x), abs(delta.y))
	if steps == 0:
		_mark_margin_brush(grid, from_cell, 1)
		return
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var point := Vector2(from_cell) + Vector2(delta) * t
		var current := Vector2i(roundi(point.x), roundi(point.y))
		_mark_margin_brush(grid, current, 1)


static func _mark_margin_brush(grid: Array, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			_mark_margin_cell(grid, Vector2i(x, y))


static func _mark_margin_cell(grid: Array, grid_pos: Vector2i) -> void:
	if grid_pos.x < 0 or grid_pos.y < 0 or grid_pos.x >= GRID_SIZE or grid_pos.y >= GRID_SIZE:
		return
	if grid[grid_pos.y][grid_pos.x] == CellState.EMPTY:
		grid[grid_pos.y][grid_pos.x] = CellState.MARGIN


static func _local_to_grid(local_pos: Vector2) -> Vector2i:
	var x := clampi(int(floor(local_pos.x / ROOM_LOCAL_SIZE * GRID_SIZE)), 0, GRID_SIZE - 1)
	var y := clampi(int(floor(local_pos.y / ROOM_LOCAL_SIZE * GRID_SIZE)), 0, GRID_SIZE - 1)
	return Vector2i(x, y)
