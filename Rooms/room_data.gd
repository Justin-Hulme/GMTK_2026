class_name RoomData 
extends Node2D

@export var cell_width: int = 1
@export var cell_height: int = 1

@export var money_area: Area2D


func _ready() -> void:
	_update_money_area_message()


func _process(_delta: float) -> void:
	_update_money_area_message()


func is_vault_open() -> bool:
	var vault_door := get_node_or_null("Vault Door")
	if vault_door == null:
		return true
	if vault_door is CanvasItem and not (vault_door as CanvasItem).visible:
		return true
	var enabled_value = vault_door.get("enabled")
	if enabled_value is bool and not enabled_value:
		return true
	return false


func _is_player_in_money_area() -> bool:
	if money_area == null:
		return false
	for body in money_area.get_overlapping_bodies():
		if body is Node and body.is_in_group("player"):
			return true
	return false


func _update_money_area_message() -> void:
	var label_node := get_node_or_null("Label")
	if label_node == null or not (label_node is CanvasItem):
		return
	(label_node as CanvasItem).visible = (not is_vault_open()) and _is_player_in_money_area()

func _on_money_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_update_money_area_message()

func _on_money_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_update_money_area_message()
