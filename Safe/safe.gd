extends Node2D

@onready var player_node = null
@onready var detection_area: Area2D = $DetectionArea
@onready var timer: Timer = $Timer
@onready var progress_bar: ProgressBar = $ProgressBar

@export var open_sprite : Texture2D
@export var close_sprite : Texture2D

var player_near = false
var open = false
var paid = false
var timer_time = 0

const SAFE_LOW_VALUE := 2000
const SAFE_MID_VALUE := 4000
const SAFE_HIGH_VALUE := 6000

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	timer.timeout.connect(_on_timer_timeout)


func _process(delta):
	if !timer.is_stopped():
		progress_bar.value = (timer_time - timer.time_left) / timer_time * 100
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if player_near:
				if player_node.lockpick_speed < 0:
					$"Label".visible = true
					progress_bar.visible = false
					return
				else:
					$"Label".visible = false
					progress_bar.visible = true
					
					timer_time = 5 * player_node.lockpick_speed
					timer.wait_time = timer_time
					timer.start()
					$"AudioStreamPlayer".playing = true
				
func _on_timer_timeout():
	$"AudioStreamPlayer".playing = false
	if open:
		$"Sprite2D".texture = close_sprite
	else:
		$"Sprite2D".texture = open_sprite
	open = not open
	
	if not paid:
		paid = true
		
		var roll = randf()
		
		var score = 0
		if roll < 0.6:
			score = SAFE_LOW_VALUE
		elif roll < 0.9:
			score = SAFE_MID_VALUE
		else:
			score = SAFE_HIGH_VALUE
		
		player_node.add_score(score)


func get_remaining_value(can_open: bool = true) -> int:
	if paid or not can_open:
		return 0
	return SAFE_LOW_VALUE

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true
		player_node = body


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false
		$"Label".visible = false
		progress_bar.visible = false
		timer.stop()
		$"AudioStreamPlayer".playing = false
