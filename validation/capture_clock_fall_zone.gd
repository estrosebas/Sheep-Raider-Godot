extends SceneTree

func _init(): call_deferred("capture")

func marker(overlay: Control,camera: Camera3D,point: Vector3,text: String,color: Color):
	var screen = camera.unproject_position(point)
	var dot = ColorRect.new()
	dot.color = color
	dot.position = screen-Vector2(7,7)
	dot.size = Vector2(14,14)
	overlay.add_child(dot)
	var label = Label.new()
	label.text = text
	label.position = screen+Vector2(14,-12)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",6)
	overlay.add_child(label)

func capture():
	root.size = Vector2i(1440,900)
	SaveFiles.startup_offered = true
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	level.player.set_physics_process(false)
	level.player.hide()
	await create_timer(.25).timeout
	var clock = level.get_node("TimeKeeper_65")
	clock.hint.hide()
	clock.set_process(false)
	var zone = level.get_node("SecretClockPathFall")
	zone.set_physics_process(false)
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.current = true
	var layer = CanvasLayer.new()
	layer.layer = 100
	level.add_child(layer)
	for view in ["overhead","approach","arrow_closeup"]:
		if view == "overhead" or view == "arrow_closeup":
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			var target = Vector3(29,0,-8) if view == "arrow_closeup" else Vector3(27,0,-23)
			camera.size = 23 if view == "arrow_closeup" else 38
			camera.global_position = target+Vector3.UP*45
			camera.look_at(target,Vector3.BACK)
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 66
			camera.global_position = Vector3(39,17,-6)
			camera.look_at(Vector3(27,0,-23))
		var overlay = Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(overlay)
		var corners = PackedVector2Array()
		for point in [Vector3(18,.2,-34),Vector3(36,.2,-34),Vector3(36,.2,-12),Vector3(18,.2,-12)]:
			corners.append(camera.unproject_position(point))
		var fill = Polygon2D.new()
		fill.polygon = corners
		fill.color = Color(1,.15,.1,.12)
		overlay.add_child(fill)
		var border = Line2D.new()
		border.points = corners
		border.closed = true
		border.width = 4
		border.default_color = Color(1,.25,.2)
		overlay.add_child(border)
		if view == "arrow_closeup":
			marker(overlay,camera,Vector3(28.5,0,-5.5),"A: punta aproximada de tu flecha",Color.YELLOW)
			marker(overlay,camera,Vector3(27,0,-11),"B",Color.CYAN)
			marker(overlay,camera,Vector3(31,0,-8),"C",Color.CYAN)
		else:
			marker(overlay,camera,clock.global_position,"RELOJ",Color.CYAN)
			marker(overlay,camera,Vector3(27,0,-19),"PUNTO PROBADO",Color.YELLOW)
		var caption = Label.new()
		caption.text = "PARCHE ACTUAL: zona roja del camino al reloj\nSolo activa la caida debajo de Y = -3 m; borde dibujado a la altura del camino."
		if view == "arrow_closeup": caption.text = "AMPLIACION DE LA ZONA DE TU FLECHA\nRojo: limite del parche anterior. A / B / C: referencias para ubicar el hueco."
		caption.position = Vector2(22,18)
		caption.add_theme_font_size_override("font_size",23)
		caption.add_theme_color_override("font_outline_color",Color.BLACK)
		caption.add_theme_constant_override("outline_size",7)
		overlay.add_child(caption)
		for i in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/clock_fall_zone_%s.png" % view)
		overlay.queue_free()
		await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await process_frame
	quit()
