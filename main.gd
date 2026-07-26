extends Control

@export var game_scene: String = "res://LevelLoader/level_loader.tscn"
@onready var music_slider: VSlider = $Control/MusicSlider

var music_bus := AudioServer.get_bus_index("Music")

func _ready():
	$Button.pressed.connect(_on_button_pressed)
	$Button2.pressed.connect(_on_button2_pressed)
	music_slider.value = AudioServer.get_bus_volume_db(music_bus)
	music_slider.value_changed.connect(_on_music_volume_changed)


func _on_button_pressed():
	get_tree().change_scene_to_file(game_scene)


func _on_button2_pressed():
	get_tree().quit()
	
func _on_music_volume_changed(value):
	AudioServer.set_bus_volume_db(music_bus, value)
