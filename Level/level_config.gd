class_name LevelConfig extends Resource

@export var grid_width: int = 10
@export var grid_height: int = 6
@export var target_room_count: int = 16
@export var random_seed: int = 0
@export var total_floors: int = 3
@export var debt: int = 5000
@export_enum("easy", "medium", "hard") var difficulty: String = "medium"


func get_coin_target_value() -> int:
	match difficulty:
		"easy":
			return maxi(int(round(float(debt) * 1.30)), 1)
		"hard":
			return maxi(int(round(float(debt) * 1.06)), 1)
		_:
			return maxi(int(round(float(debt) * 1.15)), 1)
