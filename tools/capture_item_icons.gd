extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	var views = []
	for definition in definitions.values():
		var viewport = SubViewport.new()
		viewport.size = Vector2i(128, 128)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var mesh = MeshInstance3D.new()
		mesh.mesh = load(definition["mesh"])
		viewport.add_child(mesh)
		var bounds = mesh.mesh.get_aabb()
		var center = bounds.position + bounds.size * 0.5
		var camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z) * 1.7
		viewport.add_child(camera)
		camera.position = center + Vector3(2, 1, 3).normalized() * 4.0
		camera.look_at(center)
		camera.current = true
		views.append({"viewport": viewport, "definition": definition})
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	for view in views:
		var path = "res://assets/items/%s/icon.png" % view["definition"]["slug"]
		var rendered = view["viewport"].get_texture().get_image()
		var used = rendered.get_used_rect()
		if used.has_area():
			var cropped = rendered.get_region(used)
			var fit = 104.0 / maxf(used.size.x, used.size.y)
			cropped.resize(maxi(1, roundi(used.size.x * fit)), maxi(1, roundi(used.size.y * fit)), Image.INTERPOLATE_NEAREST)
			var icon = Image.create(128, 128, false, rendered.get_format())
			icon.fill(Color.TRANSPARENT)
			icon.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), (Vector2i(128, 128) - cropped.get_size()) / 2)
			icon.save_png(path)
		else:
			rendered.save_png(path)
		view["viewport"].queue_free()
	await process_frame
	quit()
