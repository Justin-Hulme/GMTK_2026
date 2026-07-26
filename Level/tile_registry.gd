extends Node

var _tiles_by_path: Dictionary = {}
var _all_tiles: Array[TileDefinition] = []


func _enter_tree() -> void:
	var door_regex := RegEx.new()
	door_regex.compile('name\\s*=\\s*"door_([NSEW])"')
	
	_scan_path("res://Rooms/", door_regex)
	
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


func _scan_path(path: String, door_regex: RegEx) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("[TileRegistry] Cannot open directory: " + path)
		return
	
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		
		var full_path = path.path_join(file)
		_parse_scene(full_path, door_regex)
	
	for subdir in dir.get_directories():
		var sub_dir_path := path.path_join(subdir)
		_scan_path(sub_dir_path, door_regex)


func _parse_scene(scene_path: String, door_regex: RegEx) -> void:
	var text := FileAccess.get_file_as_string(scene_path)
	if not text or text.is_empty():
		push_error("[TileRegistry] Failed to read scene: " + scene_path)
		return
	
	var result := door_regex.search(text)
	if not result:
		push_warning("[TileRegistry] No door nodes found in: " + scene_path)
		return
	
	var tile := TileDefinition.new()
	tile.scene_path = scene_path
	tile.name = _name_from_scene(scene_path)
	
	for m in door_regex.search_all(text):
		match m.strings[1]:
			"N": tile.door_mask_n = 1
			"E": tile.door_mask_e = 1
			"S": tile.door_mask_s = 1
			"W": tile.door_mask_w = 1
	
	if tile.door_mask_n + tile.door_mask_e + tile.door_mask_s + tile.door_mask_w == 0:
		push_warning("[TileRegistry] Tile has no doors: " + scene_path)
		return
	
	_tiles_by_path[scene_path] = tile
	_all_tiles.append(tile)


func _name_from_scene(scene_path: String) -> StringName:
	var basename := scene_path.get_file().trim_suffix(".tscn")
	return basename.to_lower()
