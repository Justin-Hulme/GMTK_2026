extends Node2D

@export var open_angle := -90.0
@export var open_time := 0.5

@export var interaction_area : Area2D

var player_near := false
var is_open := false


func _ready():
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if player_near:
				toggle_door()


func toggle_door():
	is_open = !is_open

	var target_angle = deg_to_rad(open_angle) if is_open else 0

	var tween = create_tween()
	tween.tween_property(
		self,
		"rotation",
		target_angle,
		open_time
	)

func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
