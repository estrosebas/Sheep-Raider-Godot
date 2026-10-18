extends SceneTree

func _init() -> void:
	call_deferred("verify")

func render(viewport: SubViewport) -> Image:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func verify() -> void:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera = Camera3D.new()
	camera.rotation = Vector3(0.3,0.5,0)
	viewport.add_child(camera)
	camera.current = true
	var sky = preload("res://scripts/levels/original_sky.gd").new()
	viewport.add_child(sky)
	var sky_image = await render(viewport)
	var object = MeshInstance3D.new()
	object.mesh = QuadMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0,1)
	object.material_override = material
	camera.add_child(object)
	object.position.z = -2
	var with_sky = await render(viewport)
	sky.hide()
	var without_sky = await render(viewport)
	var foreground = with_sky.get_pixel(64,64)
	var baseline = without_sky.get_pixel(64,64)
	var background = sky_image.get_pixel(64,64)
	var valid = foreground.is_equal_approx(baseline) and foreground.r > 0.9 and foreground.b > 0.9 and foreground.g < 0.05 and not background.is_equal_approx(foreground)
	print("Sky GPU occlusion: ",valid,"; background=",background,"; foreground=",foreground,"; without sky=",baseline)
	viewport.queue_free()
	await process_frame
	quit(0 if valid else 1)
