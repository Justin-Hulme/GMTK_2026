class_name FloorGenerator extends RefCounted

# Cell types for grid cells
enum Cell { EMPTY = 0, START = 1, CRITICAL = 2, BRANCH = 3, END = 4 }

# Door bitmasking constants (powers of 2 for bitwise operations)
enum Doors { NONE = 0, RIGHT = 1, UP = 2, LEFT = 4, DOWN = 8 }

const DIR_TO_DOOR := {
	Vector2i(1, 0): Doors.RIGHT,
	Vector2i(0, -1): Doors.UP,
	Vector2i(-1, 0): Doors.LEFT,
	Vector2i(0, 1): Doors.DOWN
}

const OPPOSITE_DOOR := {
	Doors.RIGHT: Doors.LEFT,
	Doors.LEFT: Doors.RIGHT,
	Doors.UP: Doors.DOWN,
	Doors.DOWN: Doors.UP
}

# Direction names for door markers (matching Marker2D naming convention)
const DOOR_NAMES := [
	&"door_E",  # RIGHT
	&"door_N",  # UP  
	&"door_W",  # LEFT
	&"door_S"   # DOWN
]

var rng: RandomNumberGenerator
var grid: Array           # Cell type per cell [x][y]
var doors: Array          # Bitmask per cell [x][y]
var room_map: Dictionary  # Vector2i → prefab template_id (for instantiation)


func generate(config: LevelConfig, spawn_override: Variant = null) -> Dictionary:
	"""
	Main entry point. Generates a floor layout and returns the scene + metadata.
	
	Returns dictionary with keys:
		- "scene": Node2D containing instantiated rooms
		- "spawn_grid": Vector2i grid position of spawn room
		- "exit_grid": Vector2i grid position of exit room
	"""
	_init_rng(config.seed)
	_init_grid(config.grid_width, config.grid_height)
	
	var spawn_pos = spawn_override if spawn_override is Vector2i else _find_default_spawn(config)
	_generate_critical_path_bfs(spawn_pos, config.max_depth_from_spawn)
	_generate_branches(config.branch_ratio)
	mark_exit_room()
	
	# Validate connectivity before instantiating visuals
	if not _validate_connectivity():
		push_warning("Generated floor has disconnected rooms!")
	
	var exit_cell = _find_exit_cell()
	var spawn_grid_pos = _find_start_cell()
	
	return {
		"scene": _instantiate_visuals(config),
		"spawn_grid": spawn_grid_pos,
		"exit_grid": exit_cell if exit_cell != Vector2i(-1, -1) else spawn_grid_pos
	}


func connect_rooms(a: Vector2i, b: Vector2i) -> void:
	"""Connect two adjacent grid cells with doors (bitmask synchronization)."""
	var dir := b - a
	assert(DIR_TO_DOOR.has(dir), "Invalid adjacent direction %s" % str(dir))
	doors[a.x][a.y] |= DIR_TO_DOOR[dir]
	doors[b.x][b.y] |= OPPOSITE_DOOR[DIR_TO_DOOR[dir]]


func _init_rng(seed_val: int) -> void:
	rng = RandomNumberGenerator.new()
	if seed_val == 0:
		rng.randomize()
	else:
		rng.seed = seed_val


func _init_grid(width: int, height: int) -> void:
	grid.clear()
	doors.clear()
	
	for x in range(width):
		var col_cells := []
		var col_doors := []
		for y in range(height):
			col_cells.append(Cell.EMPTY)
			col_doors.append(Doors.NONE)
		grid.append(col_cells)
		doors.append(col_doors)


func _find_default_spawn(config: LevelConfig) -> Vector2i:
	return Vector2i(config.grid_width / 2, 0)


func _generate_critical_path_bfs(start: Vector2i, max_depth: int) -> void:
	grid[start.x][start.y] = Cell.START
	
	var queue := [[start, 0]]
	
	while not queue.is_empty():
		var current_data = queue.pop_front()
		var current_pos = current_data[0]
		var depth = current_data[1]
		
		if depth >= max_depth:
			continue
		
		var neighbors := _get_valid_empty_neighbors(current_pos)
		if neighbors.is_empty():
			continue
		
		var next_pos = pick_random(neighbors)
		connect_rooms(current_pos, next_pos)
		grid[next_pos.x][next_pos.y] = Cell.CRITICAL
		
		queue.push_back([next_pos, depth + 1])


func _get_valid_empty_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors := []
	for dir in DIR_TO_DOOR.keys():
		var next = pos + dir
		if _is_in_bounds(next) and grid[next.x][next.y] == Cell.EMPTY:
			neighbors.push_back(next)
	return neighbors


func _generate_branches(branch_ratio: float) -> void:
	var critical_cells := []
	
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == Cell.CRITICAL:
				critical_cells.push_back(Vector2i(x, y))
	
	critical_cells.shuffle()
	var target_branches = int(critical_cells.size() * branch_ratio)
	var placed := 0
	
	for cell in critical_cells:
		if placed >= target_branches:
			break
		
		var neighbors := _get_valid_empty_neighbors(cell)
		if not neighbors.is_empty():
			var branch_pos = pick_random(neighbors)
			connect_rooms(cell, branch_pos)
			grid[branch_pos.x][branch_pos.y] = Cell.BRANCH
			placed += 1


func mark_exit_room() -> void:
	"""Find CRITICAL cell with max BFS distance from spawn (≥1 room away), pick randomly from deepest tier."""
	var start = _find_start_cell()
	if not start or start.x < 0:
		return
	
	# Run BFS to compute distances from spawn
	var dist := {}
	dist[start] = 0
	var queue := [start]
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		for dir in DIR_TO_DOOR.keys():
			var n = pos + dir
			if _is_in_bounds(n) and grid[n.x][n.y] != Cell.EMPTY and not (n in dist):
				dist[n] = dist[pos] + 1
				queue.push_back(n)
	
	# Find max depth among CRITICAL cells that are ≥1 room from spawn
	var max_depth := -1
	for pos in dist:
		if grid[pos.x][pos.y] == Cell.CRITICAL and dist[pos] >= 1:
			max_depth = max(max_depth, dist[pos])
	
	# Pick randomly from all CRITICAL cells at max depth (Option B)
	var candidates := []
	for pos in dist:
		if grid[pos.x][pos.y] == Cell.CRITICAL and dist[pos] == max_depth:
			candidates.push_back(pos)
	
	if not candidates.is_empty():
		var exit_cell = pick_random(candidates)
		grid[exit_cell.x][exit_cell.y] = Cell.END


func _validate_connectivity() -> bool:
	"""Flood fill from START — all non-EMPTY cells must be reachable."""
	var start = _find_start_cell()
	if not start or start.x < 0:
		return false
	
	var visited := {}
	var queue := [start]
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		if pos in visited:
			continue
		visited[pos] = true
		
		for dir in DIR_TO_DOOR.keys():
			if doors[pos.x][pos.y] & DIR_TO_DOOR[dir]:
				var neighbor := pos + dir
				if _is_in_bounds(neighbor) and grid[neighbor.x][neighbor.y] != Cell.EMPTY:
					queue.push_back(neighbor)
	
	# Every non-EMPTY cell must be visited
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] != Cell.EMPTY and not (Vector2i(x, y) in visited):
				return false
	
	return true


func _select_prefab(cell_type: Cell, pos: Vector2i) -> StringName:
	"""Maps cell type to prefab template with exclusion rules."""
	match cell_type:
		Cell.START:
			return &"room_spawn_1"
		
		Cell.END:
			return &"room_exit_1"
		
		Cell.CRITICAL:
			var crit_neighbors := _count_critical_neighbors(pos)
			if crit_neighbors >= 4:
				return &"room_hub"
			
			if crit_neighbors == 3:
				return pick_random([&"room_crossroads_1", &"room_corridor_1"])
			
			return pick_random([&"room_corridor_1", &"room_corridor_2"])
		
		Cell.BRANCH:
			var edge_dist := _distance_to_edge(pos)
			if edge_dist <= 1:
				return pick_random([&"deadends/room_printers", &"deadends/room_bathroom"])
			
			return pick_random([&"deadends/room_office", &"deadends/room_office_2"])
	
	# Fallback
	return &"room_corridor_1"


func _count_critical_neighbors(pos: Vector2i) -> int:
	var count := 0
	for dir in DIR_TO_DOOR.keys():
		var n = pos + dir
		if _is_in_bounds(n) and grid[n.x][n.y] == Cell.CRITICAL:
			count += 1
	return count


func _distance_to_edge(pos: Vector2i) -> int:
	return min(
		min(pos.x, pos.y),
		min(grid.size() - 1 - pos.x, (grid[0].size() if grid.size() > 0 else 0) - 1 - pos.y)
	)


func _instantiate_visuals(config: LevelConfig) -> Node2D:
	var root := Node2D.new()
	
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == Cell.EMPTY:
				continue
			
			var prefab_name = _select_prefab(grid[x][y], Vector2i(x, y))
			room_map[Vector2i(x, y)] = prefab_name
			
			var room_scene := load("res://" + prefab_name + ".tscn") as PackedScene
			if not room_scene:
				push_error("Missing prefab: res://%s.tscn" % prefab_name)
				continue
			
			var room_instance = room_scene.instantiate()
			
			# Convert grid position to world position (each cell = 8 tiles * 16px = 128px)
			var room_data = room_instance.get_node_or_null("RoomData")
			var cell_w = 1 if not room_data else room_data.cell_width
			var cell_h = 1 if not room_data else room_data.cell_height
			room_instance.position = Vector2(x * cell_w * 128, y * cell_h * 128)
			
			root.add_child(room_instance)
			
			# Add TileMapLayer to "wall" group for coin_spawner collision detection
			var tile_map = room_instance.get_node_or_null("TileMapLayer")
			if tile_map:
				tile_map.add_to_group("wall")
	
	return root


func _find_start_cell() -> Vector2i:
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == Cell.START:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _find_exit_cell() -> Vector2i:
	for x in range(grid.size()):
		for y in range(grid[x].size()):
			if grid[x][y] == Cell.END:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and \
		   pos.x < grid.size() and pos.y < (grid[0].size() if grid.size() > 0 else 0)


func pick_random(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]
