extends Node2D

const FloorGenerator = preload("res://Level/floor_generator.gd")
const COIN_GOLD = preload("res://Coin/coin_gold.tscn")
const COIN_SILVER = preload("res://Coin/coin_silver.tscn")
const COIN_COPPER = preload("res://Coin/coin_copper.tscn")
const PropPlacerScript = preload("res://Prop/prop_placer.gd")

const CELL_SIZE := 384.0
const COIN_MARGIN := 48.0
const COIN_GOLD_VALUE := 100.0
const COIN_SILVER_VALUE := 50.0
const COIN_COPPER_VALUE := 10.0
const COIN_GOLD_WEIGHT := 10.0
const COIN_SILVER_WEIGHT := 30.0
const COIN_COPPER_WEIGHT := 60.0

var floor_container: Node2D
var _coin_rng := RandomNumberGenerator.new()
@export var level_config: LevelConfig
var _is_transitioning_floor := false
var _current_exit_room: Node2D
var _current_exit_area: Area2D
var played_unlock

func _ready() -> void:
	_coin_rng.randomize()
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.current_floor_in_level = 1
	generate_floor(false)


func generate_floor(reset_floor_state: bool = false) -> void:
	played_unlock = false
	var config := _get_level_config()
	var level_manager = get_node_or_null("/root/LevelManager")
	if reset_floor_state and level_manager:
		level_manager.current_floor_in_level = 1
	
	var generator := FloorGenerator.new()
	var result = generator.generate(config)
	
	print("[LevelLoader] Generated floor")

	if is_instance_valid(floor_container):
		floor_container.queue_free()

	floor_container = Node2D.new()
	var floor_number := 1
	if level_manager:
		floor_number = level_manager.current_floor_in_level
	floor_container.name = "floor_%d" % floor_number
	result.scene.name = "generated_rooms"
	floor_container.add_child(result.scene)
	add_child(floor_container)
	PropGridBuilder.build_for_generated_rooms(result.scene)
	PropPlacerScript.populate_generated_rooms(result.scene)
	_build_light_occluders(result.scene)
	_spawn_map_coins.call_deferred(result.scene, _get_target_coin_count(config))
	
	# Move player to render on top of rooms (last child = drawn last)
	var player_node = get_node_or_null("Player")
	if player_node:
		move_child(player_node, -1)
		player_node.debt_value = config.debt

	if level_manager:
		level_manager.max_floors_per_level = config.total_floors
		var hud = player_node.get_node_or_null("HUD") if player_node else null
		if hud and hud.has_method("refresh_floor_indicators"):
			hud.refresh_floor_indicators(level_manager.max_floors_per_level, level_manager.current_floor_in_level)
	if player_node and player_node.has_signal("coin_picked_up"):
		if not player_node.coin_picked_up.is_connected(_on_player_coin_total_changed):
			player_node.coin_picked_up.connect(_on_player_coin_total_changed)

	# Position player at spawn grid position using actual room cell size (384x384)
	var spawn_grid_pos := Vector2i(0, 0)
	if "spawn_grid" in result:
		spawn_grid_pos = result.spawn_grid
	
	var player_world_x := spawn_grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0
	var player_world_y := spawn_grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	
	if player_node:
		player_node.position = Vector2(player_world_x, player_world_y)

	connect_exit_signals()
	_update_exit_unlock_state()
	_is_transitioning_floor = false

	# Camera2D already follows the player as a child node.
	# Avoid overriding its global position here, which offsets the player off-center.


func _find_camera() -> Camera2D:
	var player_node = get_node_or_null("Player")
	if not player_node:
		return null
	
	for child in player_node.get_children():
		if child is Camera2D:
			return child as Camera2D
	
	return null


func _get_level_config() -> LevelConfig:
	if level_config != null:
		return level_config
	return LevelConfig.new()


func _spawn_map_coins(generated_rooms: Node, target_coin_count: int) -> void:
	if not is_instance_valid(generated_rooms):
		return
	var candidates := _get_coin_spawn_candidates(generated_rooms)
	if candidates.is_empty():
		return

	var coin_shape := CircleShape2D.new()
	coin_shape.radius = 8.0
	var spawned := 0
	for _i in range(target_coin_count):
		var candidate = candidates[_coin_rng.randi_range(0, candidates.size() - 1)]
		var spawned_here := false
		for _attempt in range(20):
			var pos: Vector2 = candidate
			if _is_coin_spawn_blocked(pos, coin_shape):
				continue
			var coin = _pick_random_coin().instantiate()
			coin.global_position = pos
			coin.z_index = 10
			generated_rooms.add_child(coin)
			spawned += 1
			spawned_here = true
			break
		if not spawned_here:
			continue
	print("[LevelLoader] Spawned %d coins (target=%d)" % [spawned, target_coin_count])


func _build_light_occluders(root_node: Node) -> void:
	for child in root_node.get_children():
		_build_light_occluders_for_node(child)


func _build_light_occluders_for_node(node: Node) -> void:
	if node is TileMapLayer:
		_add_occluders_from_tilemap(node as TileMapLayer)
	for child in node.get_children():
		_build_light_occluders_for_node(child)


func _add_occluders_from_tilemap(tilemap: TileMapLayer) -> void:
	var tile_set := tilemap.tile_set
	if tile_set == null:
		return
	var occluder_root := Node2D.new()
	occluder_root.name = "GeneratedOccluders"
	tilemap.add_child(occluder_root)
	for cell in tilemap.get_used_cells():
		var source_id := tilemap.get_cell_source_id(cell)
		if source_id == -1:
			continue
		var atlas_coords := tilemap.get_cell_atlas_coords(cell)
		var alternative := tilemap.get_cell_alternative_tile(cell)
		var source := tile_set.get_source(source_id)
		if source == null or not source.has_method("get_tile_data"):
			continue
		var tile_data = source.get_tile_data(atlas_coords, alternative)
		if tile_data == null:
			continue
		var shape_count: int = tile_data.get_collision_polygons_count(0)
		for polygon_idx in range(shape_count):
			var points: PackedVector2Array = tile_data.get_collision_polygon_points(0, polygon_idx)
			if points.is_empty():
				continue
			var polygon := OccluderPolygon2D.new()
			polygon.polygon = points
			var occluder := LightOccluder2D.new()
			occluder.occluder = polygon
			occluder.position = tilemap.map_to_local(cell)
			occluder_root.add_child(occluder)


func _get_target_coin_count(config: LevelConfig) -> int:
	var target_coin_value = config.get_coin_target_value()
	var total_weight = COIN_GOLD_WEIGHT + COIN_SILVER_WEIGHT + COIN_COPPER_WEIGHT
	var average_coin_value = (
		COIN_GOLD_VALUE * COIN_GOLD_WEIGHT +
		COIN_SILVER_VALUE * COIN_SILVER_WEIGHT +
		COIN_COPPER_VALUE * COIN_COPPER_WEIGHT
	) / total_weight
	return maxi(int(round(float(target_coin_value) / average_coin_value)), 1)


func _get_coin_spawn_candidates(generated_rooms: Node) -> Array:
	var candidates := []
	for child in generated_rooms.get_children():
		if not (child is Node2D):
			continue
		var node2d := child as Node2D
		if not (node2d.name.begins_with("room_") or node2d.name.begins_with("corridor_")):
			continue
		for tilemap in _find_tilemaps(node2d):
			candidates.append_array(_get_safe_coin_points_from_tilemap(tilemap))
	return candidates


func _find_tilemaps(root_node: Node) -> Array[TileMapLayer]:
	var tilemaps: Array[TileMapLayer] = []
	for child in root_node.get_children():
		if child is TileMapLayer:
			tilemaps.append(child as TileMapLayer)
	return tilemaps


func _get_safe_coin_points_from_tilemap(tilemap: TileMapLayer) -> Array:
	var points := []
	var used_cells: Array[Vector2i] = tilemap.get_used_cells()
	if used_cells.is_empty():
		return points

	var min_x := used_cells[0].x
	var max_x := used_cells[0].x
	var min_y := used_cells[0].y
	var max_y := used_cells[0].y
	for cell in used_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	for cell in used_cells:
		if cell.x <= min_x or cell.x >= max_x or cell.y <= min_y or cell.y >= max_y:
			continue
		var source_id := tilemap.get_cell_source_id(cell)
		if source_id == -1:
			continue
		var atlas_coords := tilemap.get_cell_atlas_coords(cell)
		var alternative := tilemap.get_cell_alternative_tile(cell)
		var source := tilemap.tile_set.get_source(source_id)
		if source == null or not source.has_method("get_tile_data"):
			continue
		var tile_data = source.get_tile_data(atlas_coords, alternative)
		if tile_data == null:
			continue
		var shape_count: int = tile_data.get_collision_polygons_count(0)
		if shape_count > 0:
			continue
		points.append(tilemap.to_global(tilemap.map_to_local(cell)))
	return points


func _is_coin_spawn_blocked(target_pos: Vector2, coin_shape: Shape2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = coin_shape
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = 1
	var results = get_world_2d().direct_space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider is TileMapLayer:
			return true
		if collider is CharacterBody2D:
			return true
		if collider is Area2D:
			return true
		if collider != null and (collider.is_in_group("wall") or collider.is_in_group("magnet")):
			return true
	return false


func _pick_random_coin() -> PackedScene:
	var roll := _coin_rng.randi_range(1, 100)
	if roll <= 10:
		return COIN_GOLD
	if roll <= 40:
		return COIN_SILVER
	return COIN_COPPER


func _on_exit_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _is_transitioning_floor:
		return
	var required_coins := _get_required_coins_for_exit(body)
	if body.get_coin_total() < required_coins:
		print("[LevelLoader] Exit locked: need %d coins, have %d" % [required_coins, body.get_coin_total()])
		return
	_is_transitioning_floor = true
	print("[LevelLoader] Player entered exit!")
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager == null:
		generate_floor(false)
		return
	if level_manager.current_floor_in_level < level_manager.max_floors_per_level:
		level_manager.next_floor()
		generate_floor(false)
		return
	level_manager.next_level()
	level_manager.max_floors_per_level = _get_level_config().total_floors
	generate_floor(true)


func _get_required_coins_for_exit(player_node: Node2D) -> int:
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager == null:
		return player_node.debt_value
	var floor_ratio := float(level_manager.current_floor_in_level) / float(maxi(level_manager.max_floors_per_level, 1))
	return int(ceil(float(player_node.debt_value) * floor_ratio))


func _find_exit_areas(node: Node) -> Array[Area2D]:
	var areas := []
	if node is Area2D and node.name == "Area2D":
		var has_collision := false
		for child in node.get_children():
			if child is CollisionShape2D:
				has_collision = true
				break
		if has_collision:
			areas.append(node as Area2D)
	
	for child in node.get_children():
		var sub = _find_exit_areas(child)
		for a in sub:
			areas.append(a)
	
	return areas


func connect_exit_signals() -> void:
	_current_exit_area = null
	_current_exit_room = null
	if not floor_container:
		push_error("No floor container!")
		return
	
	var generated = floor_container.get_node_or_null("generated_rooms")
	if not generated:
		return
	
	var exit_areas = _find_exit_areas(generated)
	
	for area in exit_areas:
		_current_exit_area = area
		_current_exit_room = area.get_parent() as Node2D
		if not area.body_entered.is_connected(_on_exit_body_entered):
			area.body_entered.connect(_on_exit_body_entered)


func _on_player_coin_total_changed(_amount: int) -> void:
	_update_exit_unlock_state()


func _update_exit_unlock_state() -> void:
	if not is_instance_valid(_current_exit_room):
		return
	var player_node = get_node_or_null("Player")
	if player_node == null:
		return
	var unlocked: bool = player_node.get_coin_total() >= _get_required_coins_for_exit(player_node)
	var vault_node = _find_vault_door_node(_current_exit_room)
	if vault_node:
		_set_vault_door_enabled(vault_node, not unlocked)
	if unlocked and not played_unlock:
		played_unlock = true
		$"AudioStreamPlayer".playing = true
	if is_instance_valid(_current_exit_area):
		_current_exit_area.set_deferred("monitoring", unlocked)
		_current_exit_area.set_deferred("monitorable", unlocked)


func _find_vault_door_node(root_node: Node) -> Node:
	for child in root_node.get_children():
		if child.name == "Vault Door" or child.name == "VaultDoor" or child.name == "TileMapLayer2":
			return child
		var found = _find_vault_door_node(child)
		if found:
			return found
	return null


func _set_vault_door_enabled(node: Node, enabled: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = enabled
	if node is TileMapLayer:
		node.set("enabled", enabled)
	for child in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = not enabled
		elif child is TileMapLayer:
			child.set("enabled", enabled)
		if child is CanvasItem:
			(child as CanvasItem).visible = enabled
		_set_vault_door_enabled(child, enabled)
