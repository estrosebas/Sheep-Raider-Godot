extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.directory = "user://studio_ground_%d"%Time.get_ticks_usec(); SaveFiles.studio_initialized = false
	SaveFiles.pending = {}; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_arrivals = []
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var scene = load(SaveFiles.STUDIO_SCENE).instantiate(); root.add_child(scene); current_scene = scene
	for i in range(40): await physics_frame
	for number in range(8):
		var door = scene.get_node("LevelDoor_%02d"%number)
		var query = PhysicsRayQueryParameters3D.create(door.global_position+Vector3.UP*.5,door.global_position-Vector3.UP*1,1)
		query.exclude = [scene.player.get_rid()]
		var hit = scene.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(door.global_position.y-hit.position.y-.005)<.002,"Door%02d rests on actual stage floor"%number)
	check(scene.get_node("LevelDoor_05").global_position.y>3,"Raised bonus-level stage remains elevated")
	var scroll = scene.get_node("StudioTextureAnimation")
	check(scroll.regions.size()==4 and scroll.pages.size()==4,"All four native studio scroll lists loaded")
	scroll.set_process(false)
	var before: Dictionary = {}
	for page in scroll.pages: before[page] = scroll.pages[page].image.get_data()
	scroll.advance_rows(7)
	for page in scroll.pages:
		check(before[page]!=scroll.pages[page].image.get_data(),"Native animated pixels change on page%d"%page)
	var bound = 0
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh: continue
		for i in range(mesh.mesh.get_surface_count()):
			var material = mesh.mesh.surface_get_material(i)
			if material is ShaderMaterial:
				for page in scroll.pages:
					if material.get_shader_parameter("albedo_texture")==scroll.pages[page].texture: bound += 1
	check(bound>=4,"Animated atlas pages are connected to rendered studio materials")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1200,900)
		var door = scene.get_node("LevelDoor_07")
		scene.player.global_position = door.global_position+Vector3(-1.8,0,1)
		scene.player.set_physics_process(false); scene.player.restart_fade.hide()
		var camera = Camera3D.new(); scene.add_child(camera)
		camera.global_position = door.global_position+Vector3(-4.5,1.7,-.5); camera.look_at(door.global_position+Vector3.UP)
		camera.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_snow_door.png")
	for audio in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): audio.stop(); audio.stream = null
	scene.queue_free(); await process_frame
	print("Studio door grounding / raised stages / native snow and atlas animation: ",failures," failures")
	quit(failures)
