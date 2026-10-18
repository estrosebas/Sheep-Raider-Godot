extends SceneTree

const Space = preload("res://scripts/levels/game_space.gd")
var failures = 0

func _init() -> void:
	call_deferred("verify")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func verify() -> void:
	check(Space.original_point(Vector3(100,200,300)) == Vector3(1,-2,-3), "Original viewer conversion includes both Y and Z")
	var checked = 0
	var sources = {
		"res://assets/levels/lvl_00/data/scenery_world_data.json":"res://assets/levels/lvl_00/scenery.tres",
		"res://assets/levels/lvl_00/data/sky_data.json":"res://assets/levels/lvl_00/sky.tres",
		"res://assets/levels/lvl_00/data/puzzle_static_data.json":"res://assets/levels/lvl_00/level_objects.tres",
		"res://assets/levels/lvl_00/data/rocket_data.json":"res://assets/levels/lvl_00/rocket.tres"}
	for path in sources:
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var mesh: ArrayMesh = load(sources[path])
		for surface in range(mesh.get_surface_count()):
			var page = mesh.surface_get_name(surface).get_slice("page_",1)
			var group = data[page]
			var arrays = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for vertex in range(group["verts"].size()):
				var source = group["verts"][vertex]
				var expected = Vector3(source[0],source[1],-source[2])
				check(arrays[Mesh.ARRAY_VERTEX][vertex].distance_to(expected) < 0.00002, "World vertex correction: " + path)
				checked += 1
			for triangle in range(0,indices.size(),3):
				check(indices[triangle] == triangle and indices[triangle+1] == triangle+2 and indices[triangle+2] == triangle+1, "Reflected winding is restored")
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame
	var player = level.get_node("Player")
	player.capture_mouse(false)
	check(is_equal_approx(player.position.z,43.45), "Spawn corrected into Godot space")
	check(is_equal_approx(player.camera_pivot.rotation.y,PI), "Initial camera follows converted source heading")
	var rocket = level.get_node("Rocket_77")
	check(rocket.global_position.is_equal_approx(Vector3(-93,8.22,2.85)), "Rocket uses the same space as scenery")
	var query = PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*5, player.global_position-Vector3.UP*10)
	query.exclude = [player.get_rid()]
	var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit["normal"].y > 0.5, "Corrected collision floor catches rays from above")
	await create_timer(1.0).timeout
	check(player.is_on_floor() and player.position.y > -1.0, "Player lands on corrected level collision")
	# Changing movement heading must rotate both art and item attachment together.
	player.skeleton.rotation.y = PI
	check(player.item_facing().z < -0.99, "Character and held items face movement after conversion")
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Game space: ", failures, " failures / ", checked, " corrected level vertices")
	quit(1 if failures else 0)
