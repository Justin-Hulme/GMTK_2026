extends Node

const MAIN_MENU_SCENE_PATH := "res://Main.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("return_to_main_menu"):
		return

	var tree := get_tree()
	if tree == null:
		return

	var current_scene := tree.current_scene
	if current_scene == null:
		return

	if current_scene.scene_file_path == MAIN_MENU_SCENE_PATH:
		return

	get_viewport().set_input_as_handled()
	tree.change_scene_to_file(MAIN_MENU_SCENE_PATH)
