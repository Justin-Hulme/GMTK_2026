extends RefCounted

const GRID_WIDTH := 10
const GRID_HEIGHT := 6
const MAX_ATTEMPTS := 50
const MIN_EXIT_DISTANCE := 6

var rng: RandomNumberGenerator
var grid: Array[Array] = []
var room_definitions: Array[Dictionary] = []
var spawn_def: Dictionary = {}
var exit_def: Dictionary = {}
var spawn_grid_pos := Vector2i(-1, -1)
var exit_grid_pos := Vector2i(-1, -1)
# Parallel arrays storing cell data for each grid position
var cell_doors: Array[Array] = []  # {n, e, s, w} or null if empty
var cell_file_paths: Array[Array] = []  # room file path or "" if empty
var corridor_cells: Array[Array] = []  # true if this cell is a corridor
var corridor_connections: Array[Array] = []  # {n, e, s, w} for each corridor cell


func generate(config: LevelConfig) -> Dictionary:
	_init_rng(config.seed)
	
	var attempts := 0
	
	while attempts < MAX_ATTEMPTS:
		attempts += 1
		
		# Reset state for each attempt
		grid.clear()
		cell_doors.clear()
		cell_file_paths.clear()
		for x in range(GRID_WIDTH):
			var col := []
			var doors_col := []
			var paths_col := []
			for y in range(GRID_HEIGHT):
				col.append(0)
				doors_col.append(null)
				paths_col.append("")
			grid.append(col)
			cell_doors.append(doors_col)
			cell_file_paths.append(paths_col)
			var corridor_col := []
			for y in range(GRID_HEIGHT):
				corridor_col.append(false)
			corridor_cells.append(corridor_col)
			var conn_col := []
			for y in range(GRID_HEIGHT):
				conn_col.append({ "n": false, "e": false, "s": false, "w": false })
			corridor_connections.append(conn_col)
		
		spawn_def = {}
		exit_def = {}
		room_definitions.clear()
		
		# Read rooms from deadends folder and extract door directions
		_read_room_files()
		
		if room_definitions.is_empty():
			print("[FloorGenerator] ERROR: No rooms found in res://Rooms/deadends/")
			return {"scene": null, "spawn_grid": Vector2i(0, 0)}
		
		# Read spawn and exit tiles
		_read_spawn_exit()
		
		if spawn_def.is_empty():
			print("[FloorGenerator] ERROR: No spawn tile found")
			return {"scene": null, "spawn_grid": Vector2i(0, 0)}
		
		if exit_def.is_empty():
			print("[FloorGenerator] ERROR: No exit tile found")
			return {"scene": null, "spawn_grid": Vector2i(0, 0)}
		
		# Place deadend rooms (two less than target to leave room for spawn/exit)
		var placed_count = _place_rooms(config.target_room_count - 2)
		
		if placed_count < config.target_room_count - 2:
			continue
		
		# Find positions for spawn and exit with matching doors
		spawn_grid_pos = Vector2i(-1, -1)
		exit_grid_pos = Vector2i(-1, -1)
		
		placed_count = _place_spawn_exit(placed_count, config.target_room_count)
		
		if placed_count < config.target_room_count:
			continue
		
		_print_grid()
		
		if not _validate_doors():
			continue
		
		print("[FloorGenerator] Validation passed after %d attempt(s)" % attempts)
		
		# Generate corridors connecting all rooms
		if not _generate_corridors():
			continue
		
		var root = _instantiate_visuals()
		
		return {
			"scene": root,
			"spawn_grid": spawn_grid_pos,
			"exit_grid": exit_grid_pos
	}
	
	print("[FloorGenerator] ERROR: Failed to generate valid floor after %d attempts" % MAX_ATTEMPTS)
	return {"scene": null, "spawn_grid": Vector2i(0, 0)}


func _init_rng(seed_val: int) -> void:
	rng = RandomNumberGenerator.new()
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val


# ===================== Read Room Files =====================

func _read_room_files() -> void:
	var dir := DirAccess.open("res://Rooms/deadends/")
	if not dir:
		print("[FloorGenerator] ERROR: Cannot open res://Rooms/deadends/")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var room_info = _parse_room_scene("res://Rooms/deadends/" + file_name)
			if room_info.file_path != "":
				room_definitions.append(room_info)
		
		file_name = dir.get_next()


func _read_spawn_exit() -> void:
	# Read spawn tile from known locations
	var spawn_paths := [
		"res://Rooms/fancy/room_spawn_1.tscn",
		"res://Rooms/room_spawn_1.tscn"
	]
	
	for path in spawn_paths:
		if FileAccess.file_exists(path):
			spawn_def = _parse_room_scene(path)
			break
	
	if spawn_def.is_empty() or ("file_path" in spawn_def and spawn_def.file_path == ""):
		print("[FloorGenerator] ERROR: Spawn tile not found")
		return
	
	# Read exit tile from known locations
	var exit_paths := [
		"res://Rooms/fancy/room_exit_1.tscn",
		"res://Rooms/room_exit_1.tscn"
	]
	
	for path in exit_paths:
		if FileAccess.file_exists(path):
			exit_def = _parse_room_scene(path)
			break
	
	if exit_def.is_empty() or ("file_path" in exit_def and exit_def.file_path == ""):
		print("[FloorGenerator] ERROR: Exit tile not found")


func _parse_room_scene(scene_path: String) -> Dictionary:
	var info := {
		"file_path": "",
		"name": "",
		"doors": [],  # Array of direction strings: "N", "S", "E", "W"
		"door_mask_n": 0,
		"door_mask_e": 0,
		"door_mask_s": 0,
		"door_mask_w": 0
	}
	
	if not FileAccess.file_exists(scene_path):
		return info
	
	var text := FileAccess.get_file_as_string(scene_path)
	if not text or text.is_empty():
		return info
	
	info.file_path = scene_path
	info.name = scene_path.get_file().trim_suffix(".tscn")
	
	# Dynamically extract door directions from node names like "door_W", "door_North"
	var regex := RegEx.new()
	regex.compile('name="door_([A-Za-z]+)"')
	var results := regex.search_all(text)
	
	for result in results:
		var direction = result.strings[1].to_upper().substr(0, 1)
		if direction in ["N", "S", "E", "W"]:
			info.doors.append(direction)
			match direction:
				"N": info.door_mask_n = 1
				"E": info.door_mask_e = 1
				"S": info.door_mask_s = 1
				"W": info.door_mask_w = 1
	
	return info


# ===================== Place Rooms =====================

func _place_rooms(target_count: int) -> int:
	var placed_count := 0
	
	# Collect all positions as flat arrays (x and y in parallel)
	var cx_list := []
	var cy_list := []
	
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] == 0:
				cx_list.append(x)
				cy_list.append(y)
	
	var total = cx_list.size()
	
	# Shuffle indices for variety
	for i in range(total - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp_x = cx_list[i]
		cx_list[i] = cx_list[j]
		cx_list[j] = temp_x
		var temp_y = cy_list[i]
		cy_list[i] = cy_list[j]
		cy_list[j] = temp_y
	
	# Place rooms greedily from shuffled candidates
	for i in range(total):
		if placed_count >= target_count:
			break
		
		var cx_val = cx_list[i]
		var cy_val = cy_list[i]
		
		# Pick a random room type (rooms can be reused)
		var room_def = room_definitions[rng.randi_range(0, room_definitions.size() - 1)]
		
		if _can_place_room(cx_val, cy_val, room_def):
			grid[cx_val][cy_val] = placed_count + 1
			cell_file_paths[cx_val][cy_val] = room_def.file_path
			
			# Store door masks for validation
			cell_doors[cx_val][cy_val] = {
				"n": room_def.door_mask_n,
				"e": room_def.door_mask_e,
				"s": room_def.door_mask_s,
				"w": room_def.door_mask_w
			}
			
			# Store placement info for instantiation
			room_def.grid_x = cx_val
			room_def.grid_y = cy_val
			room_def.placed_id = placed_count + 1
			
			print("[FloorGenerator] Placed '%s' at (%d,%d) doors=%s" % [room_def.name, cx_val, cy_val, str(room_def.doors)])
			
			placed_count += 1
	
	return placed_count


func _can_place_room(x: int, y: int, room_def: Dictionary) -> bool:
	# Cell must be empty (0)
	if grid[x][y] != 0:
		return false
	
	# All doors must face toward 0s ONLY (not borders, not other rooms)
	for door_dir in room_def.doors:
		var door_x = x
		var door_y = y
		
		match door_dir:
			"N": door_y -= 1
			"S": door_y += 1
			"W": door_x -= 1
			"E": door_x += 1
		
		if not _is_in_bounds(door_x, door_y):
			return false  # Door faces border
		
		if grid[door_x][door_y] != 0:
			return false  # Door faces a room (must face empty space only)
	
	# Also check that no neighbor has a door facing toward this new position
	var neighbor_dirs = {
		"north": {"dx": 0, "dy": -1, "door": "n"},
		"south": {"dx": 0, "dy": 1, "door": "s"},
		"west": {"dx": -1, "dy": 0, "door": "e"},
		"east": {"dx": 1, "dy": 0, "door": "w"}
	}
	
	for dir_key in neighbor_dirs:
		var d = neighbor_dirs[dir_key]
		var nx = x + d["dx"]
		var ny = y + d["dy"]
		
		if not _is_in_bounds(nx, ny):
			continue
		
		var neighbor_doors = cell_doors[nx][ny]
		if neighbor_doors == null:
			continue
		
		# Check if this neighbor has a door facing toward us
		match dir_key:
			"north":  # neighbor above → check its south door (s)
				if neighbor_doors.s > 0:
					return false
			"south":  # neighbor below → check its north door (n)
				if neighbor_doors.n > 0:
					return false
			"west":   # neighbor left → check its east door (e)
				if neighbor_doors.e > 0:
					return false
			"east":   # neighbor right → check its west door (w)
				if neighbor_doors.w > 0:
					return false
	
	return true


func _place_spawn_exit(placed_count: int, target_count: int) -> int:
	# Find positions for spawn and exit where doors face ONLY empty cells (0).
	
	var spawn_pos = _find_position_for_tile(spawn_def, placed_count + 1)
	if spawn_pos != null:
		grid[spawn_pos["x"]][spawn_pos["y"]] = placed_count + 1
		cell_file_paths[spawn_pos["x"]][spawn_pos["y"]] = spawn_def.file_path
		cell_doors[spawn_pos["x"]][spawn_pos["y"]] = {
			"n": spawn_def.door_mask_n,
			"e": spawn_def.door_mask_e,
			"s": spawn_def.door_mask_s,
			"w": spawn_def.door_mask_w
		}
		spawn_grid_pos.x = spawn_pos["x"]
		spawn_grid_pos.y = spawn_pos["y"]
		placed_count += 1
	
	var exit_pos = _find_position_for_tile(exit_def, placed_count + 1, spawn_grid_pos)
	if exit_pos != null:
		grid[exit_pos["x"]][exit_pos["y"]] = placed_count + 1
		cell_file_paths[exit_pos["x"]][exit_pos["y"]] = exit_def.file_path
		cell_doors[exit_pos["x"]][exit_pos["y"]] = {
			"n": exit_def.door_mask_n,
			"e": exit_def.door_mask_e,
			"s": exit_def.door_mask_s,
			"w": exit_def.door_mask_w
		}
		exit_grid_pos.x = exit_pos["x"]
		exit_grid_pos.y = exit_pos["y"]
		placed_count += 1
	
	return placed_count


func _find_position_for_tile(tile_def: Dictionary, next_id: int, origin_pos: Vector2i = Vector2i(-1, -1)) -> Variant:
	# Find a position where this tile's doors face ONLY empty cells (0).
	# Also ensure no neighbor has a door facing THIS position.
	
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != 0:
				continue

			if origin_pos != Vector2i(-1, -1):
				if abs(x - origin_pos.x) + abs(y - origin_pos.y) < MIN_EXIT_DISTANCE:
					continue
			
			var valid = true
			
			# Check that this tile's doors face only empty cells
			for door_dir in tile_def.doors:
				var neighbor_x = x
				var neighbor_y = y
				
				match door_dir:
					"N": neighbor_y -= 1
					"S": neighbor_y += 1
					"W": neighbor_x -= 1
					"E": neighbor_x += 1
				
				if not _is_in_bounds(neighbor_x, neighbor_y):
					valid = false
					break
				
				if grid[neighbor_x][neighbor_y] != 0:
					valid = false
					break
			
			if not valid:
				continue
			
			# Check that no neighbor has a door facing this position (using cell_doors)
			for d in _dirs:
				var nx = x + d.x
				var ny = y + d.y
				if not _is_in_bounds(nx, ny):
					continue
				
				var neighbor_doors = cell_doors[nx][ny]
				if neighbor_doors == null:
					continue
				
				# Check if this neighbor has a door facing us
				match Vector2i(d.x, d.y):
					Vector2i(0, -1):  # neighbor above → check its south door
						if neighbor_doors.s > 0:
							valid = false
							break
					Vector2i(0, 1):   # neighbor below → check its north door
						if neighbor_doors.n > 0:
							valid = false
							break
					Vector2i(-1, 0):  # neighbor left → check its east door
						if neighbor_doors.e > 0:
							valid = false
							break
					Vector2i(1, 0):   # neighbor right → check its west door
						if neighbor_doors.w > 0:
							valid = false
							break
			
			if valid:
				return {"x": x, "y": y}
	
	return null


const _dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


func _is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < GRID_WIDTH and y < GRID_HEIGHT


# ===================== Validation =====================

func _validate_doors() -> bool:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var doors = cell_doors[x][y]
			if doors == null:
				continue
			
			# Check each door direction faces only empty space (0) or is within bounds with no room facing it
			if doors.n and y - 1 < 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_N faces border" % [x, y])
				return false
			if doors.s and y + 1 >= GRID_HEIGHT:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_S faces border" % [x, y])
				return false
			if doors.w and x - 1 < 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_W faces border" % [x, y])
				return false
			if doors.e and x + 1 >= GRID_WIDTH:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_E faces border" % [x, y])
				return false
			
			# Doors must face empty space only (not other rooms)
			if doors.n and y - 1 >= 0 and grid[x][y - 1] != 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_N faces room" % [x, y])
				return false
			if doors.s and y + 1 < GRID_HEIGHT and grid[x][y + 1] != 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_S faces room" % [x, y])
				return false
			if doors.w and x - 1 >= 0 and grid[x - 1][y] != 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_W faces room" % [x, y])
				return false
			if doors.e and x + 1 < GRID_WIDTH and grid[x + 1][y] != 0:
				print("[FloorGenerator] VALIDATION FAIL: (%d,%d) door_E faces room" % [x, y])
				return false
	
	return true


# ===================== Visualization =====================

func _instantiate_visuals() -> Node2D:
	var root := Node2D.new()
	
	# Load corridor scenes based on door configurations
	var corridor_scenes := {}
	var corridor_dir := DirAccess.open("res://Rooms/")
	if corridor_dir:
		corridor_dir.list_dir_begin()
		var file_name = corridor_dir.get_next()
		while file_name != "":
			if file_name.begins_with("room_corridor_") and file_name.ends_with(".tscn"):
				var scene_path = "res://Rooms/" + file_name
				var loaded_scene = load(scene_path) as PackedScene
				if loaded_scene:
					# Extract door directions from the scene
					var doors := _extract_doors_from_scene(loaded_scene, scene_path)
					corridor_scenes[doors] = loaded_scene
			
			file_name = corridor_dir.get_next()
	
	# Instantiate rooms
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var file_path = cell_file_paths[x][y]
			if file_path.is_empty():
				continue
			
			var scene = load(file_path) as PackedScene
			if not scene:
				print("[FloorGenerator] Failed to load: " + file_path)
				continue
			
			var instance = scene.instantiate()
			instance.name = file_path.get_file().trim_suffix(".tscn") + "_%d_%d" % [x, y]
			instance.scale = Vector2(3, 3)
			instance.position = Vector2(x * 384.0, y * 384.0)
			root.add_child(instance)
	
	# Instantiate corridor scenes for cells marked as corridors
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not corridor_cells[x][y]:
				continue
			
			var file_path = cell_file_paths[x][y]
			if not file_path.is_empty():
				continue  # Skip room cells
			
			var doors_key := _get_corridor_doors_key(x, y)
			var scene = corridor_scenes.get(doors_key)
			
			if not scene:
				print("[FloorGenerator] Missing corridor scene for key '%s' at (%d,%d)" % [doors_key, x, y])
				continue
			
			if scene:
				var instance = scene.instantiate()
				instance.name = "corridor_%d_%d" % [x, y]
				instance.scale = Vector2(3, 3)
				instance.position = Vector2(x * 384.0, y * 384.0)
				root.add_child(instance)
	
	return root


func _extract_doors_from_scene(scene: PackedScene, scene_path: String) -> String:
	var text := FileAccess.get_file_as_string(scene_path)
	if not text or text.is_empty():
		return ""
	
	var regex := RegEx.new()
	regex.compile('name="door_([A-Za-z]+)"')
	var results := regex.search_all(text)
	
	var doors := []
	for result in results:
		var direction = result.strings[1].to_upper().substr(0, 1)
		if direction in ["N", "S", "E", "W"]:
			doors.append(direction)
	
	# Sort directions alphabetically for consistent key generation
	doors.sort()
	return ",".join(doors)


func _get_corridor_doors_key(x: int, y: int) -> String:
	var conn = corridor_connections[x][y]
	if conn == null:
		return ""
	var doors := []
	if conn.get("n", false):
		doors.append("N")
	if conn.get("e", false):
		doors.append("E")
	if conn.get("s", false):
		doors.append("S")
	if conn.get("w", false):
		doors.append("W")
	if doors.size() < 2:
		return ""
	doors.sort()
	return ",".join(doors)


func _print_grid() -> void:
	for y in range(GRID_HEIGHT):
		var line := ""
		for x in range(GRID_WIDTH):
			if grid[x][y] == 0 and corridor_cells[x][y]:
				line += " - ;"
			elif grid[x][y] == 0:
				line += " . ;"
			else:
				var idx = grid[x][y] - 1
				var name = "R%02d" % grid[x][y]
				if idx >= 0 and idx < room_definitions.size():
					name = room_definitions[idx].name.substr(0, 5) + "     ".substr(maxi(room_definitions[idx].name.length() - 4, 1))
				line += name + ";"
		print("[FloorGenerator] ", line)


# ===================== Corridor Generation =====================

func _generate_corridors() -> bool:
	print("[FloorGenerator] Starting corridor generation...")
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			corridor_cells[x][y] = false
			corridor_connections[x][y] = {"n": false, "e": false, "s": false, "w": false}

	var rooms := {}
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != 0:
				rooms["%d,%d" % [x, y]] = Vector2i(x, y)
	
	print("[FloorGenerator] Found %d rooms" % rooms.size())
	
	var spawn_key := "%d,%d" % [spawn_grid_pos.x, spawn_grid_pos.y]
	var exit_key := "%d,%d" % [exit_grid_pos.x, exit_grid_pos.y]
	if not rooms.has(spawn_key) or not rooms.has(exit_key):
		print("[FloorGenerator] ERROR: Could not find spawn/exit positions")
		return false

	var other_keys := []
	for rkey in rooms:
		if rkey != spawn_key and rkey != exit_key:
			other_keys.append(rkey)

	var tour_keys: Array = _solve_tsp_nearest_neighbor(spawn_key, other_keys, exit_key, rooms)
	print("[FloorGenerator] TSP tour length: %d" % tour_keys.size())
	for i in range(tour_keys.size()):
		var pos = rooms[tour_keys[i]]
		print("[FloorGenerator]   Step %d: (%d,%d)" % [i, pos.x, pos.y])

	for i in range(tour_keys.size()):
		var room_pos = rooms[tour_keys[i]] as Vector2i
		var access_pos = _get_room_access_cell(room_pos)
		if access_pos == Vector2i(-1, -1):
			print("[FloorGenerator] ERROR: No access cell for room at (%d,%d)" % [room_pos.x, room_pos.y])
			return false
		_add_connection_between(room_pos, access_pos)

	for i in range(tour_keys.size() - 1):
		var from_room = rooms[tour_keys[i]] as Vector2i
		var to_room = rooms[tour_keys[i + 1]] as Vector2i
		var from_access = _get_room_access_cell(from_room)
		var to_access = _get_room_access_cell(to_room)
		print("[FloorGenerator] Generating path: (%d,%d) -> (%d,%d)" % [from_room.x, from_room.y, to_room.x, to_room.y])
		var path_cells: Array = _generate_path_bfs(from_access, to_access)
		if path_cells.is_empty():
			print("[FloorGenerator] ERROR: No corridor path between access cells (%d,%d) and (%d,%d)" % [from_access.x, from_access.y, to_access.x, to_access.y])
			return false
		for j in range(path_cells.size() - 1):
			_add_connection_between(path_cells[j] as Vector2i, path_cells[j + 1] as Vector2i)

	_mark_corridor_doors()
	if not _validate_corridor_travel():
		print("[FloorGenerator] ERROR: Corridor travel validation failed")
		return false
	print("[FloorGenerator] Corridors generated")
	return true


func _get_direction(from: Vector2i, to: Vector2i) -> String:
	if to.x > from.x:
		return "e"
	elif to.x < from.x:
		return "w"
	elif to.y > from.y:
		return "s"
	else:
		return "n"


func _get_room_access_cell(room_pos: Vector2i) -> Vector2i:
	var doors = cell_doors[room_pos.x][room_pos.y]
	if doors == null:
		return Vector2i(-1, -1)
	var access := Vector2i(-1, -1)
	if doors.get("n", false):
		access = Vector2i(room_pos.x, room_pos.y - 1)
	elif doors.get("e", false):
		access = Vector2i(room_pos.x + 1, room_pos.y)
	elif doors.get("s", false):
		access = Vector2i(room_pos.x, room_pos.y + 1)
	elif doors.get("w", false):
		access = Vector2i(room_pos.x - 1, room_pos.y)
	if access == Vector2i(-1, -1):
		return access
	if not _is_in_bounds(access.x, access.y):
		return Vector2i(-1, -1)
	if grid[access.x][access.y] != 0:
		return Vector2i(-1, -1)
	return access


func _add_connection_between(a: Vector2i, b: Vector2i) -> void:
	var dir_ab = _get_direction(a, b)
	var dir_ba = _get_direction(b, a)
	if grid[a.x][a.y] == 0:
		corridor_cells[a.x][a.y] = true
		corridor_connections[a.x][a.y][dir_ab] = true
	if grid[b.x][b.y] == 0:
		corridor_cells[b.x][b.y] = true
		corridor_connections[b.x][b.y][dir_ba] = true


func _solve_tsp_nearest_neighbor(start_key: String, other_keys: Array, end_key: String, rooms: Dictionary) -> Array[String]:
	var path := [start_key]
	var remaining = other_keys.duplicate()
	
	while not remaining.is_empty():
		var current_pos = rooms[path.back()] as Vector2i
		var nearest_dist := INF
		var nearest_idx := 0
		
		for i in range(remaining.size()):
			var neighbor_pos = rooms[remaining[i]] as Vector2i
			var dist = abs(current_pos.x - neighbor_pos.x) + abs(current_pos.y - neighbor_pos.y)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_idx = i
		
		path.append(remaining[nearest_idx])
		remaining.remove_at(nearest_idx)
	
	path.append(end_key)
	return path


func _generate_path_bfs(from_pos: Vector2i, to_pos: Vector2i):
	if from_pos == to_pos:
		return [from_pos]
	
	var queue := [[from_pos]]  # Array of paths (each path is array of Vector2i)
	var visited_keys: Dictionary = {}
	visited_keys["%d,%d" % [from_pos.x, from_pos.y]] = true
	
	while not queue.is_empty():
		var current_path = queue.pop_front()
		var current = current_path.back() as Vector2i
		
		if current == to_pos:
			return current_path  # Return the complete path
		
		# Explore neighbors (up, down, left, right)
		var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
		for dir in dirs:
			var neighbor = current + dir
			if _is_in_bounds_gd(neighbor):
				var nkey = "%d,%d" % [neighbor.x, neighbor.y]
				if not visited_keys.has(nkey):
					# Can pass through empty cells or the target position
					if grid[neighbor.x][neighbor.y] == 0 or neighbor == to_pos:
						visited_keys[nkey] = true
						var new_path = current_path.duplicate()
						new_path.append(neighbor)
						queue.append(new_path)
	
	return []  # No path found


func _is_in_bounds_gd(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < GRID_WIDTH and pos.y < GRID_HEIGHT


func _mark_corridor_doors() -> void:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if corridor_cells[x][y]:
				cell_doors[x][y] = corridor_connections[x][y].duplicate()
	
	print("[FloorGenerator] Marked %d corridor cells" % _count_corridor_cells())


func _validate_corridor_travel() -> bool:
	var dirs = {
		"n": Vector2i(0, -1),
		"e": Vector2i(1, 0),
		"s": Vector2i(0, 1),
		"w": Vector2i(-1, 0)
	}
	var opposite = {"n": "s", "e": "w", "s": "n", "w": "e"}
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var doors = cell_doors[x][y]
			if doors == null:
				continue
			for dir_key in dirs:
				if not doors.get(dir_key, false):
					continue
				var neighbor = Vector2i(x, y) + dirs[dir_key]
				if not _is_in_bounds(neighbor.x, neighbor.y):
					print("[FloorGenerator] Unmatched door %s at (%d,%d) facing out of bounds" % [dir_key, x, y])
					return false
				var neighbor_doors = cell_doors[neighbor.x][neighbor.y]
				if neighbor_doors == null or not neighbor_doors.get(opposite[dir_key], false):
					print("[FloorGenerator] Unmatched door %s at (%d,%d); neighbor (%d,%d) missing %s" % [dir_key, x, y, neighbor.x, neighbor.y, opposite[dir_key]])
					return false

	var visited := {}
	var queue := [spawn_grid_pos]
	visited["%d,%d" % [spawn_grid_pos.x, spawn_grid_pos.y]] = true
	while not queue.is_empty():
		var current = queue.pop_front() as Vector2i
		var current_doors = cell_doors[current.x][current.y]
		if current_doors == null:
			continue
		for dir_key in dirs:
			if not current_doors.get(dir_key, false):
				continue
			var neighbor = current + dirs[dir_key]
			var nkey = "%d,%d" % [neighbor.x, neighbor.y]
			if not visited.has(nkey):
				visited[nkey] = true
				queue.append(neighbor)

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != 0:
				var rkey = "%d,%d" % [x, y]
				if not visited.has(rkey):
					print("[FloorGenerator] Unreachable room at (%d,%d)" % [x, y])
					return false
	return true


func _count_corridor_cells() -> int:
	var count := 0
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if corridor_cells[x][y]:
				count += 1
	return count
