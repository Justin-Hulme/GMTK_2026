class_name LevelConfig extends Resource

@export var grid_width: int = 14         # Soft boundary width (cells from spawn center)
@export var grid_height: int = 8         # Soft boundary height (cells from spawn center)
@export var target_room_count: int = 25  # WFC grows until this many rooms are placed

@export var seed: int = 0                # Random seed for deterministic generation
@export var total_floors: int = 3        # Total floors in the level
