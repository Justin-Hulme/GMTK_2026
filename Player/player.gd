extends CharacterBody2D

@export var speed := 300.0
@export var acceleration := 1200.0
@export var deceleration := 1500.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var phone_screen: Control = $HUD/Control/PhoneIcon/PhoneScreen
@onready var flashlight: PointLight2D = $Flashlight
@onready var spray_bar: ProgressBar = $HUD/Control/spray_can/PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var score := 50000
signal spray_paint_changed(current, maximum)

# HUD Vars
signal coin_picked_up(amount)

var debt_value = 50000

var powerup_dict = {"magnet": 0}

var _coin_total := 0
var spray_paint_max := 100
var spray_paint_remaining := 100
const SPRAY_PAINT_COLOR := Color8(0x73, 0x96, 0xE8, 0xB8)
const SPRAY_PAINT_INTERVAL := 0.08

var mouse_movement_enabled := true

var lockpick_speed = -1;

var _has_switched := false
var _spray_paint_timer := 0.0

const DIRECTIONS := ["east", "north_east", "north_west", "south", "south_east", "south_west", "west", "north"]

@onready var phone_icon = $HUD/Control/PhoneIcon

func _ready():
	add_to_group("player")
	phone_icon.phone_opened.connect(disable_movement)
	phone_icon.phone_closed.connect(enable_movement)
	_build_sprite_frames("res://Assets/evilperson/no_money/animations/Walk/")
	set_coin_total(score)
	spray_paint_changed.emit(spray_paint_remaining, spray_paint_max)
	
func set_coin_total(value: int) -> void:
	score = value
	_coin_total = value
	coin_picked_up.emit(_coin_total)
	_check_character_evolution()

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

	if mouse_movement_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_spray_paint_timer -= delta
		if _spray_paint_timer <= 0.0:
			_try_spray_paint()
	else:
		_spray_paint_timer = 0.0

func add_score(amount: int) -> void:
	score += amount
	set_coin_total(score)


func remove_score(amount: int) -> void:
	if amount <= 0:
		return
	set_coin_total(maxi(score - amount, 0))


func _try_spray_paint() -> void:
	if spray_paint_remaining <= 0:
		return
	var level_loader := get_parent()
	if level_loader == null or not level_loader.has_method("try_spray_paint"):
		return
	if level_loader.try_spray_paint(global_position, SPRAY_PAINT_COLOR):
		spray_paint_remaining -= 1
		_spray_paint_timer = SPRAY_PAINT_INTERVAL
		spray_paint_changed.emit(spray_paint_remaining, spray_paint_max)
	
func get_score() -> int:
	return score
	
#func check_powerup(powerup_name: String):
	#return powerup_dict.get(powerup_name, 0)
	
func disable_movement():
	mouse_movement_enabled = false

func enable_movement():
	mouse_movement_enabled = true


func can_afford_upgrade(upgrade: UpgradeData) -> bool:
	return upgrade != null and score >= upgrade.price


func buy_upgrade(upgrade: UpgradeData):
	if not can_afford_upgrade(upgrade):
		return false
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
	return true


func _check_character_evolution() -> void:
	if _has_switched:
		return
	if debt_value <= 0:
		return
	var ratio := float(_coin_total) / float(debt_value)
	if ratio >= 0.33:
		_has_switched = true
		_build_sprite_frames("res://Assets/evilperson/money/animations/Walk/")
		animated_sprite.play("idle_south")


func _build_sprite_frames(base_path: String) -> void:
	var sf := SpriteFrames.new()
	for direction in DIRECTIONS:
		var walk_anim: String = "walk_%s" % direction
		var idle_anim: String = "idle_%s" % direction
		var folder: String = direction.replace("_", "-")
		sf.add_animation(walk_anim)
		sf.set_animation_speed(walk_anim, 12.0)
		sf.set_animation_loop(walk_anim, true)
		var first_tex = null
		for i in range(6):
			var tex_path: String = "%s%s/frame_%03d.png" % [base_path, folder, i]
			var tex = ResourceLoader.load(tex_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
			if tex:
				if first_tex == null:
					first_tex = tex
				sf.add_frame(walk_anim, tex)
		if first_tex:
			sf.add_animation(idle_anim)
			sf.set_animation_speed(idle_anim, 5.0)
			sf.set_animation_loop(idle_anim, true)
			sf.add_frame(idle_anim, first_tex)
	animated_sprite.sprite_frames = sf
