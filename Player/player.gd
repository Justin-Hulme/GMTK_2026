extends CharacterBody2D

@export var speed := 300.0
@export var acceleration := 1200.0
@export var deceleration := 1500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var phone_screen: Control = $HUD/Control/PhoneScreen

var score := 0

# HUD Vars
signal coin_picked_up(amount)

var debt_value = 5000

var powerup_dict = {"magnet": 1}

var _coin_total := 0

func set_coin_total(value: int) -> void:
	score = value
	_coin_total = value
	coin_picked_up.emit(_coin_total)

func get_coin_total() -> int:
	return _coin_total


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_phone"):
		phone_screen.toggle()

func _get_facing_name(angle_rad: float) -> String:
	var angle := rad_to_deg(angle_rad)
	if angle < 0.0:
		angle += 360.0
	if angle >= 337.5 or angle < 22.5:
		return "east"
	elif angle < 67.5:
		return "south_east"
	elif angle < 112.5:
		return "south"
	elif angle < 157.5:
		return "south_west"
	elif angle < 202.5:
		return "west"
	elif angle < 247.5:
		return "north_west"
	elif angle < 292.5:
		return "north"
	else:
		return "north_east"

func _physics_process(delta: float) -> void:
	var mouse_position := get_global_mouse_position()
	var direction := mouse_position - global_position

	var target_velocity := Vector2.ZERO

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_velocity = direction.normalized() * speed

	if target_velocity.length() > 0:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	move_and_slide()

	var facing := _get_facing_name(direction.angle())
	if velocity.length() > 10:
		animated_sprite.play("walk_" + facing)
	else:
		animated_sprite.play("idle_" + facing)

func add_score(amount: int) -> void:
	score += amount
	set_coin_total(score)
	
func get_score() -> int:
	return score
	
func check_powerup(powerup_name: String):
	return powerup_dict.get(powerup_name, 0)
