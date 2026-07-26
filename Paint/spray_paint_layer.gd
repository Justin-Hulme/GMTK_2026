class_name SprayPaintLayer
extends Node2D

const DEFAULT_COLOR := Color8(0x73, 0x96, 0xE8, 0xB8)
const MIN_RADIUS := 2.0
const MAX_RADIUS := 4.0

var _marks: Array[Dictionary] = []


func add_mark(local_position: Vector2, color: Color = DEFAULT_COLOR) -> void:
	_marks.append({
		"position": local_position,
		"radius": randf_range(MIN_RADIUS, MAX_RADIUS),
		"color": color,
	})
	queue_redraw()


func _draw() -> void:
	for mark in _marks:
		_draw_mark(mark)


func _draw_mark(mark: Dictionary) -> void:
	var center: Vector2 = mark.position
	var radius: float = mark.radius
	draw_circle(center, radius, mark.color)
