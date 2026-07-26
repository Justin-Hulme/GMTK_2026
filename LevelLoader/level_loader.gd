extends Node2D

const FLOOR_GAP := 256
const FADE_DURATION := 0.4

var floor_containers: Array[Node2D] = []
var current_floor_index := 0
var fade_overlay: ColorRect
var is_transitioning := false
var level_config_path: String


func _ready() -> void:
	_init_fade_overlay()
	var config_path = "res://Levels/level_%d.tres" % LevelManager.current_level_number
	level_config_path = config_path
	
	var config = load(config_path) as Resource
	if not config:
		push_error("Failed to load level config: %s" % config_path)
		return
	
	generate_floors(config)
	connect_exit_signals()


func _init_fade_overlay() -> void:
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.visible = false
	add_child(fade_overlay)
	
	var viewport_size = get_viewport_rect().size
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)


func generate_floors(config: Resource) -> void:
	var generator := FloorGenerator.new()
	var current_spawn_pos: Variant = null
	
	for i in range(config.get("total_floors", 3)):
		var result = generator.generate(config, current_spawn_pos)
		
		var container := Node2D.new()
		container.name = "floor_%d" % (i + 1)
		container.visible = false
		
		var floor_height = config.grid_height * 128
		container.position = Vector2(0, -(i * (floor_height + FLOOR_GAP)))
		
		result.scene.name = "generated_rooms"
		container.add_child(result.scene)
		add_child(container)
		floor_containers.append(container)
		
		current_spawn_pos = result.exit_grid
	
	show_floor(0)


func show_floor(index: int) -> void:
	if is_transitioning or index < 0 or index >= floor_containers.size():
		return
	
	for i in range(floor_containers.size()):
		floor_containers[i].visible = (i == index)
	
	current_floor_index = index
	LevelManager.current_floor_in_level = index + 1
	
	var player_node = get_node_or_null("Player")
	if player_node:
		_reparent_player_to_floor(index)


func _on_exit_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	
	if body.is_in_group("player"):
		var next_index = current_floor_index + 1
		if next_index < floor_containers.size():
			await transition_to_floor(next_index)


func _on_exit_area_body_exited(body: Node2D) -> void:
	pass


func transition_to_floor(target_index: int) -> void:
	is_transitioning = true
	
	var player_node = get_node_or_null("Player")
	
	# Fade out
	fade_overlay.visible = true
	fade_overlay.color.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await tween.finished
	
	# Hide current floor, show target
	if player_node:
		player_node.visible = false
	
	floor_containers[current_floor_index].visible = false
	show_floor(target_index)
	
	if player_node:
		player_node.visible = true
	
	# Fade in
	var tween2 = create_tween()
	tween2.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await tween2.finished
	
	fade_overlay.visible = false
	is_transitioning = false


func _reparent_player_to_floor(floor_index: int) -> void:
	var target_container = floor_containers[floor_index]
	
	var generated = target_container.get_node_or_null("generated_rooms")
	if not generated:
		return
	
	var player_node = get_node_or_null("Player")
	if not player_node:
		return
	
	var spawn_pos = _find_spawn_room_center(generated)
	
	var old_parent = player_node.get_parent()
	if old_parent:
		old_parent.remove_child(player_node)
	
	target_container.add_child(player_node)
	player_node.position = spawn_pos


func _find_spawn_room_center(generated: Node2D) -> Vector2:
	for child in generated.get_children():
		var room_data = child.get_node_or_null("RoomData")
		if room_data and room_data.entrances.has(&"BOTTOM"):
			var tile_map = child.get_node_or_null("TileMapLayer")
			if tile_map:
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
		areas += _find_exit_areas(child)
	
	return areas


func connect_exit_signals() -> void:
	for container in floor_containers:
		var generated = container.get_node_or_null("generated_rooms")
		if not generated:
			continue
		
		var exit_areas = _find_exit_areas(generated)
		
		for area in exit_areas:
			area.body_entered.connect(_on_exit_body_entered)
