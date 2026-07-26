class_name FloorGenerator extends RefCounted

var rng: RandomNumberGenerator
var grid_state: Array[Array]        # [x][y] = TileDefinition or null (null = empty)
var frontier: Array[Vector2i]       # positions to try next
var spawn_grid_pos: Vector2i = Vector2i(-1, -1)
var exit_tile_scene_path: String = ""


func generate(config: LevelConfig, spawn_override = null) -> Dictionary:
	_init_rng(config.seed)
	_init_grid(config.grid_width, config.grid_height)
	
	var start_x := (config.grid_width / 2) if not spawn_override else int(spawn_override.x)
	var start_y := 0 if not spawn_override else int(spawn_override.y)
	spawn_grid_pos = Vector2i(start_x, start_y)
	
	_place_spawn(spawn_grid_pos)
	_grow_frontier(config.target_room_count, config.grid_width, config.grid_height)
	_place_exit_tile()
	
	_ensure_connectivity()
	
	var exit_cell := _find_exit_position()
	
	_print_grid_debug()
	
	if not _validate_all_doors_overlap():
		print("[FloorGenerator] Validation failed — doors don't all overlap")
	
	var root = _instantiate_visuals()
	
	return {
		"scene": root,
		"spawn_grid": spawn_grid_pos,
		"exit_grid": exit_cell if exit_cell != Vector2i(-1, -1) else spawn_grid_pos
	}


func connect_rooms(_a: Vector2i, _b: Vector2i) -> void:
	pass


const SCALE := 3.0
const CELL_SIZE := 128.0 * SCALE


func _init_rng(seed_val: int) -> void:
	rng = RandomNumberGenerator.new()
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val


func _init_grid(width: int, height: int) -> void:
	grid_state.clear()
	for x in range(width):
		var col := []
		for y in range(height):
			col.append(null)
		grid_state.append(col)


func _place_spawn(start_pos: Vector2i) -> void:
	var spawn_tile = TileRegistry.get_spawn_tile()
	if not spawn_tile:
		push_error("[FloorGenerator] No spawn tile found in registry!")
		return
	
	grid_state[start_pos.x][start_pos.y] = spawn_tile
	_add_frontier_neighbors(start_pos)


func _grow_frontier(target_count: int, grid_width: int, grid_height: int) -> void:
	var room_count := 1
	
	while not frontier.is_empty() and room_count < target_count:
		frontier.shuffle()
		
		var pos: Vector2i = frontier.pop_front()
		
		if grid_state[pos.x][pos.y] != null:
			continue
		
		if not _is_within_bounds(pos, grid_width, grid_height):
			continue
		
		var valid_tiles := _find_valid_tiles(pos)
		if valid_tiles.is_empty():
			continue
		
		var selected_tile = pick_random(valid_tiles)
		
		grid_state[pos.x][pos.y] = selected_tile
		room_count += 1
		
		_add_frontier_neighbors(pos)
	
	exit_tile_scene_path = TileRegistry.get_exit_tile().scene_path


func _place_exit_tile() -> void:
	if exit_tile_scene_path.is_empty():
		push_error("[FloorGenerator] No exit tile scene path set!")
		return
	
	var last_pos := Vector2i(-1, -1)
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			if grid_state[x][y]:
				last_pos = Vector2i(x, y)
	
	if last_pos.x >= 0 and last_pos.y >= 0:
		var exit_tile := TileRegistry.get_exit_tile()
		grid_state[last_pos.x][last_pos.y] = exit_tile


func _find_valid_tiles(pos: Vector2i) -> Array[TileDefinition]:
	var all_tiles := TileRegistry.get_all_tiles()
	var spawn_tile = TileRegistry.get_spawn_tile()
	var exit_tile = TileRegistry.get_exit_tile()
	var valid: Array[TileDefinition] = []
	
	if not spawn_tile or not exit_tile:
		push_error("[FloorGenerator] Spawn or exit tile missing from registry!")
		return valid
	
	for tile in all_tiles:
		if str(tile.scene_path) == str(spawn_tile.scene_path):
			continue
		if str(tile.scene_path) == str(exit_tile.scene_path):
			continue
		if not _is_compatible(tile, pos):
			continue
		valid.append(tile)
	
	return valid


func _is_compatible(candidate: TileDefinition, pos: Vector2i) -> bool:
	# Bidirectional constraint check against already-placed neighbors.
	# 1. If candidate has a door facing a neighbor, that neighbor must have a matching door.
	# 2. If candidate has NO door in a direction where the neighbor does, reject (inverse).
	
	if candidate.door_mask_n:
		var n = Vector2i(pos.x, pos.y - 1)
		if _is_in_bounds(n):
			var nn = grid_state[n.x][n.y]
			if nn and not nn.door_mask_s: return false
	
	if candidate.door_mask_e:
		var n = Vector2i(pos.x + 1, pos.y)
		if _is_in_bounds(n):
			var en = grid_state[n.x][n.y]
			if en and not en.door_mask_w: return false
	
	if candidate.door_mask_s:
		var n = Vector2i(pos.x, pos.y + 1)
		if _is_in_bounds(n):
			var sn = grid_state[n.x][n.y]
			if sn and not sn.door_mask_n: return false
	
	if candidate.door_mask_w:
		var n = Vector2i(pos.x - 1, pos.y)
		if _is_in_bounds(n):
			var wn = grid_state[n.x][n.y]
			if wn and not wn.door_mask_e: return false
	
	# Inverse check: if candidate lacks a door facing an existing neighbor that has one, reject.
	
	if not candidate.door_mask_n:
		var n = Vector2i(pos.x, pos.y - 1)
		if _is_in_bounds(n):
			var nn = grid_state[n.x][n.y]
			if nn and nn.door_mask_s: return false
	
	if not candidate.door_mask_e:
		var n = Vector2i(pos.x + 1, pos.y)
		if _is_in_bounds(n):
			var en = grid_state[n.x][n.y]
			if en and en.door_mask_w: return false
	
	if not candidate.door_mask_s:
		var n = Vector2i(pos.x, pos.y + 1)
		if _is_in_bounds(n):
			var sn = grid_state[n.x][n.y]
			if sn and sn.door_mask_n: return false
	
	if not candidate.door_mask_w:
		var n = Vector2i(pos.x - 1, pos.y)
		if _is_in_bounds(n):
			var wn = grid_state[n.x][n.y]
			if wn and wn.door_mask_e: return false
	
	return true


func _ensure_connectivity() -> void:
	# Build adjacency graph based on matching door pairs, then BFS from spawn.
	# Remove any tiles not reachable from spawn — they are disconnected components.
	var directions = [Vector2i(1, 0), Vector2i(0, 1)]  # only east and south to avoid duplicates
	
	var adj: Dictionary = {}
	
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			if grid_state[x][y]:
				adj[Vector2i(x, y)] = []
	
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			if not grid_state[x][y]:
				continue
			
			var pos = Vector2i(x, y)
			
			for dir in directions:
				var nx = x + dir.x
				var ny = y + dir.y
				
				if not _is_in_bounds(Vector2i(nx, ny)):
					continue
				
				var neighbor = grid_state[nx][ny]
				if not neighbor:
					continue
				
				# Check if both tiles have matching doors facing each other
				var connected = false
				
				if dir.x == 1:  # east neighbor
					if grid_state[x][y].door_mask_e and neighbor.door_mask_w:
						connected = true
				elif dir.y == 1:  # south neighbor
					if grid_state[x][y].door_mask_s and neighbor.door_mask_n:
						connected = true
				
				if connected:
					adj[pos].append(Vector2i(nx, ny))
					adj[Vector2i(nx, ny)].append(pos)
	
	# BFS from spawn
	var reachable := {}
	var queue := [spawn_grid_pos]
	reachable[spawn_grid_pos] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		for neighbor in adj.get(current, []):
			if not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)
	
	# Remove unreachable tiles
	var removed_count = 0
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			var pos = Vector2i(x, y)
			if grid_state[x][y] and not reachable.has(pos):
				grid_state[x][y] = null
				removed_count += 1
	
	print("[FloorGenerator] Connectivity: %d tiles placed, %d removed (disconnected), %d remain" % [adj.size(), removed_count, reachable.size()])


func _validate_all_doors_overlap() -> bool:
	# Only check internal mismatches — doors facing empty/boundary space are expected.
	
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			var tile = grid_state[x][y]
			if not tile or tile.scene_path.is_empty():
				continue
			
			# Check north door: neighbor must have south door if placed
			if tile.door_mask_n:
				var ny = y - 1
				if _is_in_bounds(Vector2i(x, ny)):
					var nn = grid_state[x][ny]
					if nn and not nn.door_mask_s:
						print("[FloorGenerator] VALIDATION FAIL: Tile at (%d,%d) has door_n but neighbor does not" % [x, y])
						return false
			
			# Check east door: neighbor must have west door if placed
			if tile.door_mask_e:
				var nx = x + 1
				if _is_in_bounds(Vector2i(nx, y)):
					var en = grid_state[nx][y]
					if en and not en.door_mask_w:
						print("[FloorGenerator] VALIDATION FAIL: Tile at (%d,%d) has door_e but neighbor does not" % [x, y])
						return false
			
			# Check south door: neighbor must have north door if placed
			if tile.door_mask_s:
				var sy = y + 1
				if _is_in_bounds(Vector2i(x, sy)):
					var sn = grid_state[x][sy]
					if sn and not sn.door_mask_n:
						print("[FloorGenerator] VALIDATION FAIL: Tile at (%d,%d) has door_s but neighbor does not" % [x, y])
						return false
			
			# Check west door: neighbor must have east door if placed
			if tile.door_mask_w:
				var wx = x - 1
				if _is_in_bounds(Vector2i(wx, y)):
					var wn = grid_state[wx][y]
					if wn and not wn.door_mask_e:
						print("[FloorGenerator] VALIDATION FAIL: Tile at (%d,%d) has door_w but neighbor does not" % [x, y])
						return false
	
	print("[FloorGenerator] Validation passed: all internal doors overlap")
	return true


func _add_frontier_neighbors(pos: Vector2i) -> void:
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n = pos + dir
		if _is_in_bounds(n) and grid_state[n.x][n.y] == null:
			if not frontier.has(n):
				frontier.append(n)


func _find_exit_position() -> Vector2i:
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			var tile = grid_state[x][y]
			if tile and "exit" in tile.name:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _instantiate_visuals() -> Node2D:
	var root := Node2D.new()
	
	for x in range(grid_state.size()):
		for y in range(grid_state[x].size()):
			var tile = grid_state[x][y]
			if not tile or tile.scene_path.is_empty():
				continue
			
			var room_scene = load(tile.scene_path) as PackedScene
			if not room_scene:
				push_error("[FloorGenerator] Failed to load scene: " + tile.scene_path)
				continue
			
			var room_instance = room_scene.instantiate()
			
			# Convert grid position to world position (each cell = 8 tiles * 16px = 128px), scaled up
			var room_data = room_instance.get_node_or_null("RoomData")
			var cell_w: float = room_data.cell_width if room_data else 1.0
			var cell_h: float = room_data.cell_height if room_data else 1.0
			room_instance.position = Vector2(x * cell_w * CELL_SIZE, y * cell_h * CELL_SIZE)
			
			# Scale up for visibility
			room_instance.scale = Vector2(SCALE, SCALE)
			
			root.add_child(room_instance)
			
			# Add TileMapLayer to "wall" group for coin_spawner collision detection
			var tile_map = room_instance.get_node_or_null("TileMapLayer")
			if tile_map:
				tile_map.add_to_group("wall")
	
	return root


func _is_within_bounds(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.y >= 0 and \
		   pos.x < width and pos.y < height


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and \
		   pos.x < grid_state.size() and pos.y < (grid_state[0].size() if grid_state.size() > 0 else 0)


func _print_grid_debug() -> void:
	var rows := grid_state[0].size() if grid_state.size() > 0 else 0
	
	for y in range(rows):
		var line := ""
		for x in range(grid_state.size()):
			var tile = grid_state[x][y]
			if not tile or tile.scene_path.is_empty():
				line += " . ;"
			else:
				var short_name := _short_name(tile.name)
				var dirs := []
				if tile.door_mask_n: dirs.append("N")
				if tile.door_mask_e: dirs.append("E")
				if tile.door_mask_s: dirs.append("S")
				if tile.door_mask_w: dirs.append("W")
				var padded := short_name + "     ".substr(short_name.length())
				line += padded + "[" + ",".join(dirs) + "];"
		print("[FloorGenerator] ", line)


func _short_name(name: StringName) -> String:
	var n = str(name).to_lower()
	if n.contains("spawn"): return "SPAWN"
	if n.contains("exit"): return "EXIT "
	if n.contains("hub"): return "HUB  "
	if n.contains("crossroads"): return "CROSS"
	if n.contains("corridor"): return "CORID"
	return n.substr(0, 5)


func pick_random(arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]
