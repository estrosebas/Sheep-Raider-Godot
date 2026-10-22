extends SceneTree

class ClockLocator extends Control:
	var camera: Camera3D
	var points: Array = []
	func _draw():
		draw_rect(Rect2(12,12,850,72),Color(0,0,0,.8))
		draw_string(ThemeDB.fallback_font,Vector2(28,42),"NIVEL 05: UBICACION DEL RELOJ",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(28,69),"El marcador amarillo esta bajo la repisa; no encima del terreno.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		for record in points:
			var p = camera.unproject_position(record.point)
			draw_arc(p,24,0,TAU,64,Color.BLACK,8,true)
			draw_arc(p,24,0,TAU,64,record.color,4,true)
			draw_line(p-Vector2(8,0),p+Vector2(8,0),record.color,2)
			draw_line(p-Vector2(0,8),p+Vector2(0,8),record.color,2)
			var end: Vector2 = p+record.offset
			draw_line(p,end,Color.BLACK,5,true)
			draw_line(p,end,record.color,2,true)
			var font = ThemeDB.fallback_font
			var size = font.get_string_size(record.label,HORIZONTAL_ALIGNMENT_LEFT,-1,22)
			draw_rect(Rect2(end-Vector2(6,25),size+Vector2(12,12)),Color(0,0,0,.85))
			draw_string(font,end,record.label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,record.color)

func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1280,720)
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	OriginalProgress.restore({})
	SaveFiles.directory = "user://clock05_capture_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level05.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(10): await physics_frame
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	level.player.get_node("ActionPrompt").hide()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("BGMPlayer").stop()
	var clock = level.get_node("TimeKeeper_61")
	var bull = level.get_node("bull_60")
	print("Clock05 Godot position: ",clock.global_position)
	var camera = Camera3D.new(); level.add_child(camera)
	camera.position = Vector3(43,55,48); camera.look_at(Vector3(-10,0,-20)); camera.current = true
	var layer = CanvasLayer.new(); root.add_child(layer)
	layer.layer = 450
	var locator = ClockLocator.new(); layer.add_child(locator); locator.camera = camera
	locator.points = [
		{"point":clock.global_position,"color":Color(1,.9,.05),"label":"RELOJ (Y = %.2f m)"%clock.global_position.y,"offset":Vector2(52,100)},
		{"point":bull.global_position,"color":Color(1,.45,.15),"label":"TORO, ARRIBA","offset":Vector2(60,-70)},
		{"point":level.player.global_position,"color":Color(.15,1,1),"label":"INICIO","offset":Vector2(-120,90)}]
	await save_image("res://validation/level05_clock_location.png")
	var aim = clock.global_position+Vector3.UP*.92
	camera.position = clock.global_position+Vector3(-2.6,1,.2)
	camera.look_at(aim)
	locator.points = [{"point":clock.global_position+Vector3.UP*.9,"color":Color(1,.9,.05),"label":"RELOJ ORIGINAL 61","offset":Vector2(160,-80)}]
	await save_image("res://validation/level05_clock_close.png")
	layer.queue_free(); level.queue_free(); await process_frame
	quit()

func save_image(path: String):
	for control in get_nodes_in_group("optional_statistics"):
		if is_instance_valid(control.dialog): control.dialog.hide()
	for i in range(6): await process_frame; await RenderingServer.frame_post_draw
	for layer in root.get_children():
		if layer is CanvasLayer:
			for child in layer.get_children():
				if child is ClockLocator: child.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(path)
	print("Clock capture ",path,": ",result)
