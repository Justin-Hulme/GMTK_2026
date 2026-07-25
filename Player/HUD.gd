extends CanvasLayer

@onready var player: CharacterBody2D = $".."

@onready var debt_amount_value: Label = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/Debt_H/debt_amount_value
@onready var coin_total_value: Label = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/Coin_H/coin_total_value
@onready var coin_to_debt_ratio: ProgressBar = $Control/coin_to_debt/PanelContainer/MarginContainer/HBoxContainer/MarginContainer/coin_to_debt_ratio

var _fill_style: StyleBoxFlat

func _ready() -> void:
	player.coin_picked_up.connect(update_ratio)
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(5)
	update_ratio(0)

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
