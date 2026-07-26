extends Control

@onready var screen_content: Control = $ScreenContent
@onready var header: Label = $ScreenContent/Header
@onready var player = find_parent("Player")

signal phone_toggled(is_open: bool)
signal action_pressed(action_name: String)

var is_open := false

func _ready() -> void:
	visible = false
	for upgrade in find_child("Upgrades").get_children():
		if not upgrade.has_signal("purchased"):
			print("continuing", upgrade)
			continue

		upgrade.purchased.connect(_on_upgrade_purchased)
		print("connected")

func toggle() -> void:
	is_open = !is_open
	visible = is_open
	phone_toggled.emit(is_open)

func open() -> void:
	is_open = true
	visible = true
	phone_toggled.emit(true)

func close() -> void:
	is_open = false
	visible = false
	phone_toggled.emit(false)

func _on_button_pressed(action_name: String) -> void:
	action_pressed.emit(action_name)

func _on_upgrade_purchased(upgrade: UpgradeData):
	player.buy_upgrade(upgrade)
