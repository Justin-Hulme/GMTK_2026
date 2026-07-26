class_name RoomData 
extends Node2D

@export var cell_width: int = 1
@export var cell_height: int = 1

@export var money_area: Area2D

func _ready() -> void:
	pass

func _on_money_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		$"Label".visible = true

func _on_money_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		$"Label".visible = false
