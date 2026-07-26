extends CanvasLayer

const FloorIndicatorScene = preload("res://Player/HUD/floor_indicator.tscn")
const FLOOR_INDICATOR_SPACING := 44.0


@onready var player: CharacterBody2D = $".."

@onready var debt_amount_value: Label = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/Debt_H/debt_amount_value
@onready var coin_total_value: Label = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/Coin_H/coin_total_value
@onready var coin_to_debt_ratio: ProgressBar = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/MarginContainer/coin_to_debt_ratio
@onready var floor_stack: VBoxContainer = $Control/floor_indicator/floor_stack
@onready var spray_paint_bar: ProgressBar = $Control/spray_can/PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var _fill_style: StyleBoxFlat
var _level_manager: Node

func _ready() -> void:
	player.coin_picked_up.connect(update_ratio)
	player.spray_paint_changed.connect(_update_spray_paint)
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(5)
	update_ratio(0)
	_update_spray_paint(player.spray_paint_remaining, player.spray_paint_max)
	_level_manager = get_node_or_null("/root/LevelManager")
	if _level_manager:
		_level_manager.floor_changed.connect(_on_floor_changed)
		_level_manager.level_changed.connect(_on_level_changed)
		refresh_floor_indicators(_level_manager.max_floors_per_level, _level_manager.current_floor_in_level)
	else:
		refresh_floor_indicators(1, 1)

func update_ratio(_amount: int) -> void:
	debt_amount_value.text = str(player.debt_value)
	coin_total_value.text = str(player.get_coin_total())
	
	if player.debt_value > 0:
		var ratio: float = float(player.get_coin_total()) / float(player.debt_value)
		coin_to_debt_ratio.value = clampf(ratio * 100.0, 0.0, 100.0)
		
		var t := coin_to_debt_ratio.value / 100.0
		var color := Color(1.0, 0.2, 0.2).lerp(Color(1.0, 0.84, 0.0), t)
		_fill_style.set_bg_color(color)
		coin_to_debt_ratio.set("theme_override_styles/fill", _fill_style)


func refresh_floor_indicators(total_floors: int, current_floor: int) -> void:
	for child in floor_stack.get_children():
		floor_stack.remove_child(child)
		child.queue_free()
	var clamped_total := maxi(total_floors, 1)
	for display_index in range(clamped_total):
		var floor_number = clamped_total - display_index
		var indicator = FloorIndicatorScene.instantiate()
		indicator.floor_number = floor_number
		indicator.active = floor_number == (clamped_total - current_floor + 1)
		indicator.position = Vector2(0, display_index * FLOOR_INDICATOR_SPACING)
		floor_stack.add_child(indicator)


func _on_floor_changed(_old_floor: int, new_floor: int, total_floors: int) -> void:
	refresh_floor_indicators(total_floors, new_floor)


func _on_level_changed(_old_level: int, _new_level: int) -> void:
	if _level_manager:
		refresh_floor_indicators(_level_manager.max_floors_per_level, _level_manager.current_floor_in_level)


func _update_spray_paint(current: int, maximum: int) -> void:
	spray_paint_bar.max_value = maximum
	spray_paint_bar.value = current
