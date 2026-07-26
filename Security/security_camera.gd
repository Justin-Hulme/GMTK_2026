class_name SecurityCamera2D
extends Node2D

signal player_caught(player: Node2D)
signal player_released(player: Node2D)

@export var collision_mask := 1
@export var tracking_speed := 4.0
@export var idle_rotation_degrees := 0.0
@export var vision_distance := 260.0
@export var vision_angle_degrees := 55.0
@export var coins_per_tick := 50
@export var drain_interval := 1.0
@export var beam_color_idle := Color(0.35, 0.7, 1.0, 1.0)
@export var beam_color_alert := Color(1.0, 0.2, 0.2, 1.0)

var _tracked_player: Node2D = null
var _drain_timer := 0.0

@onready var light: PointLight2D = $PointLight2D
@onready var beam_polygon: Polygon2D = $BeamPolygon


func _ready() -> void:
	rotation = deg_to_rad(idle_rotation_degrees)
	_update_beam_color(false)


func _process(delta: float) -> void:
	if not is_instance_valid(_tracked_player):
		var player := _find_player()
		if is_instance_valid(player) and _is_player_in_cone(player) and _can_see_player(player):
			_catch_player(player)
		if not is_zero_approx(rotation - deg_to_rad(idle_rotation_degrees)):
			rotation = rotate_toward(rotation, deg_to_rad(idle_rotation_degrees), tracking_speed * delta)
		return

	if not _is_player_in_cone(_tracked_player) or not _can_see_player(_tracked_player):
		_release_player()
		return

	var direction := _tracked_player.global_position - global_position
	rotation = rotate_toward(rotation, direction.angle() + deg_to_rad(90.0), tracking_speed * delta)
	_drain_timer += delta
	while _drain_timer >= drain_interval:
		_drain_timer -= drain_interval
		if _tracked_player.has_method("remove_score"):
			_tracked_player.remove_score(coins_per_tick)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _is_player_in_cone(player: Node2D) -> bool:
	var to_player := player.global_position - global_position
	if to_player.length() > vision_distance:
		return false
	var forward := Vector2.UP.rotated(rotation)
	var angle_to_player := absf(rad_to_deg(forward.angle_to(to_player.normalized())))
	return angle_to_player <= vision_angle_degrees * 0.5


func _can_see_player(player: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = collision_mask
	query.exclude = [self]
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.collider == player


func _catch_player(player: Node2D) -> void:
	if _tracked_player == player:
		return
	_tracked_player = player
	_drain_timer = 0.0
	_update_beam_color(true)
	player_caught.emit(player)


func _release_player() -> void:
	if not is_instance_valid(_tracked_player):
		_tracked_player = null
		_update_beam_color(false)
		_drain_timer = 0.0
		return
	var previous_player := _tracked_player
	_tracked_player = null
	_update_beam_color(false)
	_drain_timer = 0.0
	player_released.emit(previous_player)


func _update_beam_color(alerted: bool) -> void:
	var color := beam_color_alert if alerted else beam_color_idle
	light.color = color
	beam_polygon.color = Color(color.r, color.g, color.b, 0.22)
