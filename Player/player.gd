extends CharacterBody2D

@export var speed := 300.0
@export var acceleration := 1200.0
@export var deceleration := 1500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var phone_screen: Control = $HUD/Control/PhoneScreen
@onready var flashlight: PointLight2D = $Flashlight

var score := 0

# HUD Vars
signal coin_picked_up(amount)

var debt_value = 5000

var powerup_dict = {"magnet": 0}

var _coin_total := 0

var mouse_movement_enabled := true

var lockpick_speed = 0;

@onready var phone_icon = $HUD/Control/PhoneIcon

func _ready():
	phone_icon.phone_opened.connect(disable_movement)
	phone_icon.phone_closed.connect(enable_movement)
	
func set_coin_total(value: int) -> void:
	score = value
	_coin_total = value
	coin_picked_up.emit(_coin_total)

func get_coin_total() -> int:
	return _coin_total

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

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mouse_movement_enabled:
		target_velocity = direction.normalized() * speed

	if target_velocity.length() > 0:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)

	move_and_slide()

	flashlight.rotation = direction.angle() + deg_to_rad(90)

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
	
#func check_powerup(powerup_name: String):
	#return powerup_dict.get(powerup_name, 0)
	
func disable_movement():
	mouse_movement_enabled = false

func enable_movement():
	mouse_movement_enabled = true

func buy_upgrade(upgrade: UpgradeData):
	score -= upgrade.price
	_coin_total = score
	coin_picked_up.emit(_coin_total)
	
	match upgrade.name:
		"Shoes1": speed = 350
		"Shoes2": speed = 400
		"Shoes3": speed = 450
		"Magnet1": $"Area2D/Magnet".shape.radius = 50
		"Magnet2": $"Area2D/Magnet".shape.radius = 75
		"Magnet3": $"Area2D/Magnet".shape.radius = 100
		"Lockpick1": lockpick_speed = 1
		"Lockpick2": lockpick_speed = 0.5
		"Lockpick3": lockpick_speed = 0.25
		"Flashlight1": $"Flashlight".scale *= 1.5
		"Flashlight2": $"Flashlight".scale *= 1.5
		"Flashlight3": $"Flashlight".scale *= 1.5
