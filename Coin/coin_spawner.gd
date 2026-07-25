extends Area2D

@export var coin_scenes: Array[PackedScene]
@export var coin_weights: Array[int]
@export var amount := 50
@export var coin_check_shape: Shape2D

@onready var spawn_shape := $CollisionShape2D.shape as RectangleShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(amount):
		spawn_coin()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		
func spawn_coin():
	for attempt in range(100):
		var spawn_position = global_position + Vector2(
			randf_range(-spawn_shape.size.x / 2, spawn_shape.size.x / 2),
			randf_range(-spawn_shape.size.y / 2, spawn_shape.size.y / 2)
		)

		if not is_position_blocked(spawn_position):
			var selected_coin = get_random_coin()
			var coin = selected_coin.instantiate()
			
			coin.global_position = spawn_position
			
			get_parent().add_child.call_deferred(coin)
			coin.z_index = 10
			
			return

func is_position_blocked(position: Vector2) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = coin_check_shape
	query.transform = Transform2D(0, position)
	query.collision_mask = 1

	var results = get_world_2d().direct_space_state.intersect_shape(query)

	for result in results:
		if result.collider.is_in_group("wall"):
			return true

	return false

func get_random_coin() -> PackedScene:
	var total_weight = 0

	for weight in coin_weights:
		total_weight += weight

	var roll = randi_range(1, total_weight)

	var current = 0
	for i in range(coin_weights.size()):
		current += coin_weights[i]

		if roll <= current:
			return coin_scenes[i]

	return coin_scenes[0]
