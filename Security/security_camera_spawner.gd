class_name SecurityCameraSpawner
extends RefCounted

const SECURITY_CAMERA_SCENE := preload("res://Security/security_camera.tscn")
const ROOM_MOUNT_CHANCES := {
	"easy": 0.35,
	"medium": 0.60,
	"hard": 0.85,
}
const CORRIDOR_MOUNT_CHANCES := {
	"easy": 0.15,
	"medium": 0.35,
	"hard": 0.50,
}
const ROOM_MOUNT_POINTS := {
	"N": {"position": Vector2(64, 6), "rotation": 180.0},
	"S": {"position": Vector2(64, 122), "rotation": 0.0},
	"E": {"position": Vector2(122, 64), "rotation": 270.0},
	"W": {"position": Vector2(6, 64), "rotation": 90.0},
}
const CORRIDOR_MOUNT_POINTS := {
	"N": {"position": Vector2(64, 38), "rotation": 180.0},
	"S": {"position": Vector2(64, 90), "rotation": 0.0},
	"E": {"position": Vector2(90, 64), "rotation": 270.0},
	"W": {"position": Vector2(38, 64), "rotation": 90.0},
}
const OPPOSITE_DIRECTIONS := {"N": "S", "S": "N", "E": "W", "W": "E"}


static func populate_generated_rooms(root_node: Node, config: LevelConfig) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var room_candidates: Array[Node2D] = []
	var corridor_candidates: Array[Node2D] = []
	for child in root_node.get_children():
		if not (child is Node2D):
			continue
		var room_node := child as Node2D
		if not (room_node.name.begins_with("room_") or room_node.name.begins_with("corridor_")):
			continue
		if room_node.name.begins_with("room_spawn") or room_node.name.begins_with("room_exit"):
			continue
		if room_node.get_node_or_null("SecurityCamera2D") != null:
			continue
		var is_corridor := room_node.name.begins_with("corridor_")
		if is_corridor:
			corridor_candidates.append(room_node)
		else:
			room_candidates.append(room_node)

	var room_spawned := _spawn_from_candidates(root_node, room_candidates, config, rng, false)
	var corridor_spawned := _spawn_from_candidates(root_node, corridor_candidates, config, rng, true)
	if room_spawned == 0 and not room_candidates.is_empty():
		room_candidates.shuffle()
		var forced_mount := _pick_mount(room_candidates[0], rng, false)
		if not forced_mount.is_empty():
			_spawn_camera(root_node, room_candidates[0].name, forced_mount)
			room_spawned += 1
	if corridor_spawned == 0 and config.difficulty != "easy" and not corridor_candidates.is_empty():
		corridor_candidates.shuffle()
		var forced_corridor_mount := _pick_mount(corridor_candidates[0], rng, true)
		if not forced_corridor_mount.is_empty():
			_spawn_camera(root_node, corridor_candidates[0].name, forced_corridor_mount)
			corridor_spawned += 1
	print("[SecurityCameraSpawner] Spawned %d room cameras and %d corridor cameras" % [room_spawned, corridor_spawned])


static func _spawn_from_candidates(root_node: Node, candidates: Array[Node2D], config: LevelConfig, rng: RandomNumberGenerator, is_corridor: bool) -> int:
	var spawned := 0
	for room_node in candidates:
		var chance := _get_spawn_chance(config, is_corridor)
		if rng.randf() > chance:
			continue
		var mount := _pick_mount(room_node, rng, is_corridor)
		if mount.is_empty():
			continue
		_spawn_camera(root_node, room_node.name, mount)
		spawned += 1
	return spawned


static func _get_spawn_chance(config: LevelConfig, is_corridor: bool) -> float:
	var table := CORRIDOR_MOUNT_CHANCES if is_corridor else ROOM_MOUNT_CHANCES
	return table.get(config.difficulty, table["medium"])


static func _pick_mount(room_node: Node2D, _rng: RandomNumberGenerator, is_corridor: bool) -> Dictionary:
	var available_walls := _get_candidate_walls(room_node, is_corridor)
	if available_walls.is_empty():
		return {}
	available_walls.shuffle()
	var mount_points := CORRIDOR_MOUNT_POINTS if is_corridor else ROOM_MOUNT_POINTS
	if not is_corridor:
		var selected_wall: String = available_walls[0]
		var selected_mount: Dictionary = mount_points[selected_wall]
		return {
			"position": room_node.to_global(selected_mount.position),
			"rotation": selected_mount.rotation,
		}
	for wall_dir in available_walls:
		var mount: Dictionary = mount_points[wall_dir]
		if not _has_valid_wall_mount(room_node, mount.position, wall_dir):
			continue
		return {
			"position": room_node.to_global(mount.position),
			"rotation": mount.rotation,
		}
	var fallback_wall: String = available_walls[0]
	var fallback_mount: Dictionary = mount_points[fallback_wall]
	return {
		"position": room_node.to_global(fallback_mount.position),
		"rotation": fallback_mount.rotation,
	}


static func _get_candidate_walls(room_node: Node2D, is_corridor: bool) -> Array[String]:
	var door_dirs := _get_door_directions(room_node)
	if is_corridor:
		return _get_corridor_candidate_walls(door_dirs)
	var blocked_walls := {}
	for door_dir in door_dirs:
		blocked_walls[door_dir] = true
	var preferred: Array[String] = []
	if door_dirs.size() == 1:
		var opposite = OPPOSITE_DIRECTIONS.get(door_dirs[0], "")
		if opposite != "":
			preferred.append(opposite)
	for wall_dir in ROOM_MOUNT_POINTS.keys():
		if blocked_walls.has(wall_dir):
			continue
		preferred.append(wall_dir)
	return _unique_dirs(preferred)


static func _get_corridor_candidate_walls(door_dirs: Array[String]) -> Array[String]:
	var door_set := {}
	for dir in door_dirs:
		door_set[dir] = true
	if door_set.size() >= 4:
		return []
	if door_set.has("N") and door_set.has("E") and door_set.has("S"):
		return ["W"]
	if door_set.has("N") and door_set.has("S") and door_set.has("W"):
		return ["E"]
	if door_set.has("E") and door_set.has("S") and door_set.has("W"):
		return ["N"]
	if door_set.has("N") and door_set.has("E") and door_set.has("W"):
		return ["S"]
	var candidates: Array[String] = []
	if door_set.has("N") and door_set.has("S"):
		candidates.append("E")
		candidates.append("W")
	elif door_set.has("E") and door_set.has("W"):
		candidates.append("N")
		candidates.append("S")
	else:
		for wall_dir in CORRIDOR_MOUNT_POINTS.keys():
			if not door_set.has(wall_dir):
				candidates.append(wall_dir)
	return _unique_dirs(candidates)


static func _get_door_directions(room_node: Node2D) -> Array[String]:
	var dirs: Array[String] = []
	for child in room_node.get_children():
		if child is Marker2D and child.name.begins_with("door_"):
			var direction := child.name.trim_prefix("door_").to_upper().substr(0, 1)
			if direction in ["N", "S", "E", "W"]:
				dirs.append(direction)
	return _unique_dirs(dirs)


static func _unique_dirs(values: Array) -> Array[String]:
	var seen := {}
	var unique: Array[String] = []
	for value in values:
		var dir := String(value)
		if seen.has(dir):
			continue
		seen[dir] = true
		unique.append(dir)
	return unique


static func _spawn_camera(parent_node: Node, room_name: String, mount: Dictionary) -> void:
	var camera := SECURITY_CAMERA_SCENE.instantiate() as SecurityCamera2D
	if camera == null:
		return
	camera.name = "SecurityCamera_%s" % room_name
	camera.position = mount.position
	camera.idle_rotation_degrees = mount.rotation
	parent_node.add_child(camera)
	camera.owner = null


static func _has_valid_wall_mount(room_node: Node2D, local_mount: Vector2, wall_dir: String) -> bool:
	var outward_offset := Vector2.ZERO
	var inward_offset := Vector2.ZERO
	match wall_dir:
		"N":
			outward_offset = Vector2(0, -8)
			inward_offset = Vector2(0, 16)
		"S":
			outward_offset = Vector2(0, 8)
			inward_offset = Vector2(0, -16)
		"E":
			outward_offset = Vector2(8, 0)
			inward_offset = Vector2(-16, 0)
		"W":
			outward_offset = Vector2(-8, 0)
			inward_offset = Vector2(16, 0)
		_:
			return false
	return _point_hits_tilemap(room_node, local_mount + outward_offset) and not _point_hits_tilemap(room_node, local_mount + inward_offset)


static func _point_hits_tilemap(room_node: Node2D, local_point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = room_node.to_global(local_point)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := room_node.get_world_2d().direct_space_state.intersect_point(query, 8)
	for hit in hits:
		if hit.get("collider") is TileMapLayer:
			return true
	return false
