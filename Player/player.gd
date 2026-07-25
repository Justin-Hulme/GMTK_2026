extends CharacterBody2D

@export var speed := 300.0
@export var acceleration := 1200.0
@export var deceleration := 1500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	var mouse_position := get_global_mouse_position()
	var direction := mouse_position - global_position

	# Rotate character toward mouse
	rotation = direction.angle() + deg_to_rad(90)

	var target_velocity := Vector2.ZERO

	# Move toward cursor while holding left mouse button
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_velocity = direction.normalized() * speed

	# Accelerate/decelerate smoothly
	if target_velocity.length() > 0:
		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			deceleration * delta
		)

	move_and_slide()

	# Animation
	if velocity.length() > 10:
		animated_sprite.play("walking")
	else:
		animated_sprite.play("idle")
