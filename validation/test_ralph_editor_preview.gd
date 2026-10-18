extends SceneTree
func _init(): call_deferred("run")
func run():
	print("EDITOR HINT ",Engine.is_editor_hint())
	var player = load("res://scenes/characters/Ralph.tscn").instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	var skeleton = player.get_node("Skeleton3D")
	print("PREVIEW ",skeleton.preview_skin)
	print("MATERIAL ",skeleton.get_node("MeshInstance3D").mesh.surface_get_material(0).get_shader_parameter("use_legacy_skin"))
	var failures = 0
	if not Engine.is_editor_hint() or not skeleton.preview_skin:
		printerr("Editor preview did not initialize original skinning"); failures += 1
	var mesh = skeleton.get_node("MeshInstance3D").mesh
	if mesh.surface_get_material(0).get_shader_parameter("use_legacy_skin") != true:
		printerr("Editor is using the unposed source mesh"); failures += 1
	print("Editor preview failures: ",failures)
	await create_timer(2).timeout
	player.queue_free()
	await process_frame
	quit(1 if failures else 0)
