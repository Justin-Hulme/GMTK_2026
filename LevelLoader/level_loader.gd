extends Node2D

const FloorGenerator = preload("res://Level/floor_generator.gd")
const COIN_GOLD = preload("res://Coin/coin_gold.tscn")
const COIN_SILVER = preload("res://Coin/coin_silver.tscn")
const COIN_COPPER = preload("res://Coin/coin_copper.tscn")

const CELL_SIZE := 384.0
const COIN_MARGIN := 24.0
const COIN_TARGET_COUNT := 24

var floor_container: Node2D
var _coin_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_coin_rng.randomize()
	generate_floor()
	connect_exit_signals()


func generate_floor() -> void:
	var config := LevelConfig.new()
	config.target_room_count = 16
	
	var generator := FloorGenerator.new()
	var result = generator.generate(config)
	
	print("[LevelLoader] Generated floor")
	
	floor_container = Node2D.new()
	floor_container.name = "floor_1"
	result.scene.name = "generated_rooms"
	floor_container.add_child(result.scene)
	add_child(floor_container)
	_spawn_map_coins.call_deferred(result.scene)
	
	# Move player to render on top of rooms (last child = drawn last)
	var player_node = get_node_or_null("Player")
	if player_node:
		move_child(player_node, -1)
	
	# Position player at spawn grid position using actual room cell size (384x384)
	var spawn_grid_pos := Vector2i(0, 0)
	if "spawn_grid" in result:
		spawn_grid_pos = result.spawn_grid
	
	var player_world_x := spawn_grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0
	var player_world_y := spawn_grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	
	if player_node:
		player_node.position = Vector2(player_world_x, player_world_y)
	
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


func _spawn_map_coins(generated_rooms: Node) -> void:
	if not is_instance_valid(generated_rooms):
		return
	var candidates := _get_coin_spawn_candidates(generated_rooms)
	if candidates.is_empty():
		return

	var coin_shape := CircleShape2D.new()
	coin_shape.radius = 8.0
	var spawned := 0
	for _i in range(COIN_TARGET_COUNT):
		var candidate = candidates[_coin_rng.randi_range(0, candidates.size() - 1)]
		var spawned_here := false
		for _attempt in range(20):
			var pos = Vector2(
				candidate.origin.x + _coin_rng.randf_range(COIN_MARGIN, CELL_SIZE - COIN_MARGIN),
				candidate.origin.y + _coin_rng.randf_range(COIN_MARGIN, CELL_SIZE - COIN_MARGIN)
			)
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
	print("[LevelLoader] Spawned %d coins" % spawned)


func _get_coin_spawn_candidates(generated_rooms: Node) -> Array:
	var candidates := []
	for child in generated_rooms.get_children():
		if not (child is Node2D):
			continue
		var node2d := child as Node2D
		if not (node2d.name.begins_with("room_") or node2d.name.begins_with("corridor_")):
			continue
		candidates.append({"origin": node2d.global_position})
	return candidates


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
	if body.is_in_group("player"):
		print("[LevelLoader] Player entered exit!")


func _find_exit_areas(node: Node) -> Array[Area2D]:
	var areas := []
	if node is Area2D and node.name == "Area2D":
		var collision = node.get_node_or_null("CollisionShape2D")
		if collision and collision.is_inside_tree():
			areas.append(node as Area2D)
	
	for child in node.get_children():
		var sub = _find_exit_areas(child)
		for a in sub:
			areas.append(a)
	
	return areas


func connect_exit_signals() -> void:
	if not floor_container:
		push_error("No floor container!")
		return
	
	var generated = floor_container.get_node_or_null("generated_rooms")
	if not generated:
		return
	
	var exit_areas = _find_exit_areas(generated)
	
	for area in exit_areas:
		area.body_entered.connect(_on_exit_body_entered)
