extends Area2D

@export var value := 1

var magnet_target: Node2D = null
@export var magnet_speed := 500

@onready var coin_shape = $CollisionShape2D.shape

signal coin_picked_up(new_amount)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.add_score(value)
		coin_picked_up.emit(body.get_score())
		queue_free()
		
func _on_area_entered(area):
	if area.is_in_group("magnet"):
		var player = area.get_parent()
		if player.check_powerup("magnet") > 0:
			magnet_target = area
	if area.is_in_group("flashlight"):
		var player = area.get_parent()
		check_flashlight(player)

func _on_area_exited(area):
	if area.is_in_group("magnet"):
		magnet_target = null
	if area.is_in_group("flashlight"):
		$Sprite2D.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if magnet_target:
		var next_position = global_position.move_toward(
			magnet_target.global_position,
			magnet_speed * delta
		)

		if not is_position_blocked(next_position):
			global_position = next_position
			
func is_position_blocked(position: Vector2) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = coin_shape
	query.transform = Transform2D(global_rotation, position)
	query.collision_mask = 1

	var results = get_world_2d().direct_space_state.intersect_shape(query)

	for result in results:
		if result.collider.is_in_group("wall"):
			return true

	return false
	
func check_flashlight(player):
	var space_state = get_world_2d().direct_space_state

	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	query.collision_mask = 1
	query.exclude = [player]

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		$Sprite2D.visible = true
	else:
		$Sprite2D.visible = false
