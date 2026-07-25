extends CanvasLayer

@onready var player: CharacterBody2D = $".."

@onready var debt_amount_value: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/debt_amount_value
@onready var coin_total_value: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/HBoxContainer/coin_total_value
@onready var coin_to_debt_ratio: ProgressBar = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/MarginContainer/coin_to_debt_ratio

func _ready() -> void:
	player.coin_picked_up.connect(update_ratio)

func update_ratio(_amount: int) -> void:
	debt_amount_value.text = str(player.debt_value)
	coin_total_value.text = str(player.get_coin_total())
	
	if player.debt_value > 0:
		var ratio: float = float(player.get_coin_total()) / float(player.debt_value)
		coin_to_debt_ratio.value = clampf(ratio * 100.0, 0.0, 100.0)
