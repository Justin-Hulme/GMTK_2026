extends HBoxContainer

signal purchased(upgrade)

@export var upgrades: Array[UpgradeData]
@export var max_icon: Texture2D

@onready var player = find_parent("Player")

@onready var icon_rect: TextureRect = $IconControl/Icon
@onready var label: Label = $Label
@onready var button: Button = $Button

var upgrade_pointer = 0

func _ready():
	icon_rect.texture = upgrades[upgrade_pointer].icon
	label.text = "$" + str(upgrades[upgrade_pointer].price)
	player.coin_picked_up.connect(_on_money_changed)
	button.pressed.connect(_on_button_pressed)
	_on_money_changed(player.get_coin_total())

func _on_button_pressed():
	if not player.can_afford_upgrade(upgrades[upgrade_pointer]):
		button.disabled = true
		return
	purchased.emit((upgrades[upgrade_pointer]))
	if upgrade_pointer < upgrades.size() - 1:
		upgrade_pointer += 1
		icon_rect.texture = upgrades[upgrade_pointer].icon
		label.text = "$" + str(upgrades[upgrade_pointer].price)
		_on_money_changed(player.get_coin_total())
	else:
		icon_rect.texture = max_icon
		label.text = ""
		button.disabled = true
		button.visible = false

func _on_money_changed(amount):
	if upgrades[upgrade_pointer].price <= amount:
		button.disabled = false
	else :
		button.disabled = true
