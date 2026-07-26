extends Node

const ROOM_SCENE_PATHS := [
	"res://Rooms/deadends/room_bathroom.tscn",
	"res://Rooms/deadends/room_office.tscn",
	"res://Rooms/deadends/room_office_2.tscn",
	"res://Rooms/deadends/room_printers.tscn",
	"res://Rooms/fancy/room_spawn_1.tscn",
	"res://Rooms/fancy/room_exit_1.tscn",
	"res://Rooms/room_corridor_1.tscn",
	"res://Rooms/room_corridor_2.tscn",
	"res://Rooms/room_corridor_3_1.tscn",
	"res://Rooms/room_corridor_3_2.tscn",
	"res://Rooms/room_corridor_3_3.tscn",
	"res://Rooms/room_corridor_3_4.tscn",
	"res://Rooms/room_corridor_4_1.tscn",
	"res://Rooms/room_corridor_4_2.tscn",
	"res://Rooms/room_corridor_4_3.tscn",
	"res://Rooms/room_corridor_4_4.tscn",
	"res://Rooms/room_corridor_5.tscn",
]

var _tiles_by_path: Dictionary = {}
var _all_tiles: Array[TileDefinition] = []


func _enter_tree() -> void:
	for scene_path in ROOM_SCENE_PATHS:
		_parse_scene(scene_path)
	
	if _all_tiles.is_empty():
		push_error("[TileRegistry] No room tiles discovered in res://Rooms/")


func get_all_tiles() -> Array[TileDefinition]:
	return _all_tiles.duplicate()


func get_tile_by_scene_path(path: String) -> TileDefinition:
	return _tiles_by_path.get(path)


func get_spawn_tile() -> TileDefinition:
	for tile in _all_tiles:
		if "spawn" in tile.name:
			return tile
	push_error("[TileRegistry] No spawn tile found")
	return null


func get_exit_tile() -> TileDefinition:
	for tile in _all_tiles:
		if "exit" in tile.name:
			return tile
	push_error("[TileRegistry] No exit tile found")
	return null


func get_deadend_tiles() -> Array[TileDefinition]:
	var deadends: Array[TileDefinition] = []
	for tile in _all_tiles:
		var door_count := tile.door_mask_n + tile.door_mask_e + tile.door_mask_s + tile.door_mask_w
		if door_count == 1:
			deadends.append(tile)
	return deadends


func get_all_door_directions(tile: TileDefinition) -> Array[StringName]:
	var directions: Array[StringName] = []
	if tile.door_mask_n: directions.push_back(&"NORTH")
	if tile.door_mask_e: directions.push_back(&"RIGHT")
	if tile.door_mask_s: directions.push_back(&"SOUTH")
	if tile.door_mask_w: directions.push_back(&"LEFT")
	return directions


func _parse_scene(scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("[TileRegistry] Failed to load scene: " + scene_path)
		return

	var instance := scene.instantiate()
	if instance == null:
		push_error("[TileRegistry] Failed to instantiate scene: " + scene_path)
		return
	
	var doors := _extract_door_directions(instance)
	if doors.is_empty():
		push_warning("[TileRegistry] No door nodes found in: " + scene_path)
		return
	
	var tile := TileDefinition.new()
	tile.scene_path = scene_path
	tile.name = _name_from_scene(scene_path)
	
	for direction in doors:
		match direction:
			"N": tile.door_mask_n = 1
			"E": tile.door_mask_e = 1
			"S": tile.door_mask_s = 1
			"W": tile.door_mask_w = 1
	
	if tile.door_mask_n + tile.door_mask_e + tile.door_mask_s + tile.door_mask_w == 0:
		push_warning("[TileRegistry] Tile has no doors: " + scene_path)
		return
	
	_tiles_by_path[scene_path] = tile
	_all_tiles.append(tile)


func _extract_door_directions(root: Node) -> Array[String]:
	var doors: Array[String] = []
	_collect_door_directions(root, doors)
	return doors


func _collect_door_directions(node: Node, doors: Array[String]) -> void:
	var node_name := node.name.to_upper()
	if node_name.begins_with("DOOR_"):
		var direction := node_name.trim_prefix("DOOR_").substr(0, 1)
		if direction in ["N", "S", "E", "W"] and not doors.has(direction):
			doors.append(direction)
	for child in node.get_children():
		_collect_door_directions(child, doors)


func _name_from_scene(scene_path: String) -> StringName:
	var basename := scene_path.get_file().trim_suffix(".tscn")
	return basename.to_lower()
