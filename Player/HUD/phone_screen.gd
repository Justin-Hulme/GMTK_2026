extends Control

@onready var screen_content: Control = $ScreenContent
@onready var header: Label = $ScreenContent/Header

signal phone_toggled(is_open: bool)
signal action_pressed(action_name: String)

var is_open := false

func _ready() -> void:
	visible = false
	$ScreenContent/Buttons/Button1.pressed.connect(_on_button_pressed.bind("action1"))
	$ScreenContent/Buttons/Button2.pressed.connect(_on_button_pressed.bind("action2"))
	$ScreenContent/Buttons/Button3.pressed.connect(_on_button_pressed.bind("action3"))

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
