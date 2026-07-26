extends TextureRect

@onready var phone_screen: Control = $"../PhoneScreen"

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		phone_screen.toggle()

func _on_hover() -> void:
	modulate = Color(1.2, 1.2, 1.2)

func _on_unhover() -> void:
	modulate = Color.WHITE
