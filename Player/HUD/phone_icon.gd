extends TextureRect

@onready var phone_screen: Control = $"PhoneScreen"

signal phone_opened
signal phone_closed

var is_open := false

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		phone_screen.toggle()
		is_open = !is_open
		if is_open:
			phone_opened.emit()
		else:
			phone_closed.emit()
			
func _on_hover() -> void:
	modulate = Color(1.2, 1.2, 1.2)

func _on_unhover() -> void:
	modulate = Color.WHITE
