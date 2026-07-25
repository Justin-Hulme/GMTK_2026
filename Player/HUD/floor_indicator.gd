extends Node2D

@export var floor_number := 1 :
	set(val):
		floor_number = val
		$HBoxContainer/floor/floor_number.text = str(floor_number)

@export var active := false :
	set(val):
		active = val
		update_active_state()

func _ready():
	$HBoxContainer/floor/floor_number.text = str(floor_number)
	update_active_state()

func update_active_state():
	$HBoxContainer/floor/is_active.visible = active
	$HBoxContainer/MarginContainer/active_arrow.visible = active
