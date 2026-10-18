extends SceneTree
class ZoneOverlay extends Control:
	var camera: Camera3D
	var sam: OriginalSam
	var rules: Dictionary
	var previous_circle = true
	func point(x: float,z: float) -> Vector2:
		return camera.unproject_position(Vector3(x,4,z))
	func outline(box: Dictionary,color: Color,filled: bool=false):
		var a = box.min
		var b = box.max
		var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
		var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
		var rect = Rect2(point(lo.x,lo.z),point(hi.x,hi.z)-point(lo.x,lo.z)).abs()
		if filled: draw_rect(rect,Color(color,color.a*.10))
		draw_rect(rect,color,false,3)
	func _draw():
		for box in rules.green: outline(box,Color(.2,1,.35),true)
		for box in rules.orange: outline(box,Color(1,.55,.05),true)
		for box in rules.hit: outline(box,Color(1,.18,.28))
		for box in rules.authorized: outline(box,Color(.1,.85,1))
		# The comparison circle is the removed port adaptation, not original data.
		var vertices = PackedVector2Array()
		for i in range(97):
			var angle = i*TAU/96
			vertices.append(point(sam.home.x+cos(angle)*14,sam.home.z+sin(angle)*14))
		if previous_circle: draw_polyline(vertices,Color.WHITE,3,true)
		var center = point(sam.home.x,sam.home.z)
		draw_circle(center,7,Color(.7,.2,1))
		var font = ThemeDB.fallback_font
		draw_string(font,center+Vector2(12,-10),"SAM",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		var bridge = Rect2(point(4.56,-32.78),point(9.55,-17.13)-point(4.56,-32.78)).abs()
		draw_rect(bridge,Color(1,.85,.15),false,4)
		draw_string(font,bridge.position+Vector2(0,-10),"PUENTE",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(1,.9,.3))
		draw_rect(Rect2(16,14,970,192),Color(0,0,0,.86))
		var lines = ["ZONAS ORIGINALES DE SAM — nivel 01 (vista superior)","Verde: proximidad del HUD   |   Naranja dentro del verde: deteccion", "Rojo: Ralph puede seguir siendo perseguido   |   Cian: Sam puede caminar", "Blanco: circulo de 14 m del port; NO es original y se ha retirado", "Amarillo: puente. El limite cian termina antes de su entrada.", "Proyeccion XZ: la deteccion original tambien comprueba altura, ruido y vista."]
		var colors = [Color.WHITE,Color(1,.65,.2),Color(.2,.9,1),Color.WHITE,Color(1,.9,.3),Color(.8,.8,.8)]
		for i in range(lines.size()): draw_string(font,Vector2(30,43+i*28),lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,21,colors[i])
func _init(): call_deferred("capture")
func capture():
	root.size = Vector2i(1600,1080)
	SaveFiles.startup_offered = true
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.5).timeout
	var sam = level.get_node("Sam_43")
	for node in level.find_children("*","Node",true,false):
		node.set_process(false)
		node.set_physics_process(false)
	for node in level.get_children():
		if node.name == "OriginalSky": node.hide()
	for node in level.find_children("*","CanvasLayer",true,false): node.hide()
	var camera = Camera3D.new()
	level.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 83
	camera.global_position = Vector3(-19,120,-46)
	camera.look_at(Vector3(-19,0,-46),Vector3.FORWARD)
	camera.current = true
	var layer = CanvasLayer.new()
	layer.layer = 200
	level.add_child(layer)
	var overlay = ZoneOverlay.new()
	overlay.camera = camera
	overlay.sam = sam
	overlay.rules = sam.rules
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/sam_original_zones_vs_14m.png")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free()
	await process_frame
	quit()
