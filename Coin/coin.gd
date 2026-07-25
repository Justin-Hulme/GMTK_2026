extends Area2D

@export var value := 1

var magnet_target: Node2D = null
@export var magnet_speed := 500

signal coin_picked_up(new_amount)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)

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

func _on_area_exited(area):
	if area.is_in_group("magnet"):
		magnet_target = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if magnet_target:
		global_position  = global_position.move_toward(
			magnet_target.global_position,
			magnet_speed * delta
		)
