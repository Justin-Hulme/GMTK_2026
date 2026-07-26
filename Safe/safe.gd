extends Node2D

@onready var player_node = get_node_or_null("Player")
@onready var detection_area: Area2D = $DetectionArea

@export var open_sprite : Texture2D
@export var close_sprite : Texture2D

var player_near = false
var open = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if player_near:
				if open:
					$"Sprite2D".texture = close_sprite
				else:
					$"Sprite2D".texture = open_sprite
				open = not open

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false
