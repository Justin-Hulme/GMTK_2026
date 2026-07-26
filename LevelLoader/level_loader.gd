extends Node2D

var floor_container: Node2D


func _ready() -> void:
	generate_floor()
	connect_exit_signals()


func generate_floor() -> void:
	var config := LevelConfig.new()
	config.target_room_count = 25
	
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
