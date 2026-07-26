extends Node2D

const FLOOR_GAP := 256
const FADE_DURATION := 0.4

var floor_container: Node2D
var fade_overlay: ColorRect
var is_transitioning := false


func _ready() -> void:
	_init_fade_overlay()
	generate_floor()
	connect_exit_signals()


func _init_fade_overlay() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.visible = false
	add_child(fade_overlay)
	
	var viewport_size = get_viewport_rect().size
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)


func generate_floor() -> void:
	var config := LevelConfig.new()
	config.grid_width = 14
	config.grid_height = 8
	config.max_depth_from_spawn = 4
	config.branch_ratio = 0.3
	
	var generator := FloorGenerator.new()
	var result = generator.generate(config, null)
	
	print("[LevelLoader] Generated floor: spawn=%s exit=%s" % [result.spawn_grid, result.exit_grid])
	
	floor_container = Node2D.new()
	floor_container.name = "floor_1"
	result.scene.name = "generated_rooms"
	floor_container.add_child(result.scene)
	add_child(floor_container)
	
	# Move player to render on top of rooms (last child = drawn last)
	var player_node = get_node_or_null("Player")
	if player_node:
		move_child(player_node, -1)
	
	# Position player at spawn room and center camera (3x scale)
	const SCALE := 3.0
	var spawn_x = result.spawn_grid.x * 128.0 * SCALE + 64.0 * SCALE
	var spawn_y = result.spawn_grid.y * 128.0 * SCALE + 64.0 * SCALE
	
	if player_node:
		player_node.position = Vector2(spawn_x, spawn_y)
	
	# Move camera to center on player area
	var camera = _find_camera()
	if camera:
		camera.global_position = Vector2(spawn_x, spawn_y - 100)


func _find_camera() -> Camera2D:
	var player_node = get_node_or_null("Player")
	if not player_node:
		return null
	
	for child in player_node.get_children():
		if child is Camera2D:
			return child as Camera2D
	
	return null


func _on_exit_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	
	if body.is_in_group("player"):
		print("[LevelLoader] Player entered exit! Next floor coming soon.")


func _reparent_player_to_floor(spawn_grid: Vector2i) -> void:
	var generated = floor_container.get_node_or_null("generated_rooms")
	if not generated:
		push_error("No generated rooms found!")
		return
	
	var player_node = get_node_or_null("Player")
	if not player_node:
		push_error("No Player node found!")
		return
	
	var spawn_pos = _find_spawn_room_center(generated, spawn_grid)
	
	var old_parent = player_node.get_parent()
	if old_parent:
		old_parent.remove_child(player_node)
	
	floor_container.add_child(player_node)
	player_node.position = spawn_pos


func _find_spawn_room_center(generated: Node2D, grid_pos: Vector2i) -> Vector2:
	for child in generated.get_children():
		var room_data = child.get_node_or_null("RoomData")
		if not room_data:
			continue
		
		var tile_map = child.get_node_or_null("TileMapLayer")
		if not tile_map:
			continue
		
		var bounds = tile_map.get_used_rect()
		return child.position + Vector2(
			bounds.position.x * 128 + (bounds.size.x * 128) / 2.0,
			bounds.position.y * 128 + (bounds.size.y * 128) / 2.0
		)
	
	return Vector2.ZERO


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
