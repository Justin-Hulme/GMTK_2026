extends Node

signal floor_changed(old_floor: int, new_floor: int, total_floors: int)
signal level_changed(old_level: int, new_level: int)
signal all_levels_completed

var current_level_number := 1
var current_floor_in_level := 1
var max_floors_per_level := 3
var coins_collected := 0
var debt_paid := 0

func _ready() -> void:
	current_level_number = 1
	current_floor_in_level = 1

func start_level(level_num: int) -> void:
	current_level_number = level_num
	current_floor_in_level = 1
	coins_collected = 0
	debt_paid = 0
	
func next_floor() -> void:
	var old_floor = current_floor_in_level
	current_floor_in_level += 1
	
	floor_changed.emit(old_floor, current_floor_in_level, max_floors_per_level)

func next_level() -> void:
	var old_level = current_level_number
	current_level_number += 1
	current_floor_in_level = 1
	
	level_changed.emit(old_level, current_level_number)
	
	if current_level_number > 999:
		all_levels_completed.emit()

func add_coins(amount: int) -> void:
	coins_collected += amount
