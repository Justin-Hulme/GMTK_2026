class_name SecurityCamera2D
extends Node2D

signal player_caught(player: Node2D)
signal player_released(player: Node2D)

@export var collision_mask := 1
@export var tracking_speed := 4.0
@export var idle_rotation_degrees := 0.0
@export var vision_distance := 220.0
@export var vision_angle_degrees := 45.0
@export var beam_ray_count := 13
@export var idle_sweep_degrees := 35.0
@export var idle_sweep_speed := 1.4
@export var coins_per_tick := 100
@export var drain_interval := 0.5
@export var beam_color_idle := Color(0.35, 0.7, 1.0, 1.0)
@export var beam_color_alert := Color(1.0, 0.2, 0.2, 1.0)
@export var alert_speed_scale := 2.0

var _tracked_player: Node2D = null
var _drain_timer := 0.0
var _beam_rotation := 0.0
var _idle_sweep_time := 0.0

@onready var beam_rig: Node2D = $BeamRig
@onready var light: PointLight2D = $BeamRig/PointLight2D
@onready var beam_polygon: Polygon2D = $BeamRig/BeamPolygon
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_beam_rotation = deg_to_rad(idle_rotation_degrees)
	beam_rig.rotation = _beam_rotation
	beam_polygon.visible = true
	_update_beam_color(false)
	_update_beam_polygon()
	_update_camera_animation(false)


func _process(delta: float) -> void:
	if not is_instance_valid(_tracked_player):
		var player := _find_player()
		if is_instance_valid(player) and _is_player_in_cone(player) and _can_see_player(player):
			_catch_player(player)
		_idle_sweep_time += delta * idle_sweep_speed
		var sweep_offset := sin(_idle_sweep_time) * deg_to_rad(idle_sweep_degrees)
		_beam_rotation = deg_to_rad(idle_rotation_degrees) + sweep_offset
		beam_rig.rotation = _beam_rotation
		_update_beam_polygon()
		_update_camera_animation(false)
		return

	if not _is_player_in_cone(_tracked_player) or not _can_see_player(_tracked_player):
		_release_player()
		return

	var direction := _tracked_player.global_position - global_position
	_beam_rotation = rotate_toward(_beam_rotation, direction.angle() + deg_to_rad(90.0), tracking_speed * delta)
	beam_rig.rotation = _beam_rotation
	_update_beam_polygon()
	_update_camera_animation(true)
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
	var forward := Vector2.UP.rotated(_beam_rotation)
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
	_idle_sweep_time = 0.0
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
	_idle_sweep_time = 0.0
	_update_beam_color(false)
	_drain_timer = 0.0
	player_released.emit(previous_player)


func _update_beam_color(alerted: bool) -> void:
	var color := beam_color_alert if alerted else beam_color_idle
	light.color = color
	beam_polygon.color = Color(color.r, color.g, color.b, 0.22)


func _update_beam_polygon() -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var ray_count := maxi(beam_ray_count, 3)
	var half_angle := deg_to_rad(vision_angle_degrees) * 0.5
	for i in range(ray_count):
		var t := float(i) / float(ray_count - 1)
		var angle_offset := lerpf(-half_angle, half_angle, t)
		var ray_dir := Vector2.UP.rotated(_beam_rotation + angle_offset)
		var ray_end := global_position + ray_dir * vision_distance
		var query := PhysicsRayQueryParameters2D.create(global_position, ray_end)
		query.collision_mask = collision_mask
		query.exclude = [self]
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		var hit_pos: Vector2 = ray_end
		if not result.is_empty():
			hit_pos = result.position
		points.append(beam_rig.to_local(hit_pos))
	beam_polygon.polygon = points


func _update_camera_animation(_alerted: bool) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var animation_name := _get_facing_animation_name()
	if animated_sprite.animation != animation_name:
		animated_sprite.animation = animation_name
	animated_sprite.stop()
	animated_sprite.frame = 0


func _get_facing_animation_name() -> StringName:
	var angle := wrapf(rad_to_deg(_beam_rotation), 0.0, 360.0)
	if angle >= 315.0 or angle < 45.0:
		return &"north"
	if angle < 135.0:
		return &"east"
	if angle < 225.0:
		return &"south"
	return &"west"
