extends SceneTree
func _init(): call_deferred("run")
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://heap_capture_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	lab.player.set_physics_process(false); lab.player.set_process(false)
	root.size = Vector2i(1280,720)
	var camera = Camera3D.new(); lab.add_child(camera); camera.make_current(); camera.fov = 65
	var material: ShaderMaterial = lab.get_node("LeafHeapExperiment_0").mesh.surface_get_material(0)
	var texture: Texture2D = material.get_shader_parameter("albedo_texture")
	texture.get_image().save_png("res://validation/leaf_heap_loaded_atlas.png")
	for angle in ["eye","reverse","above"]:
		for i in range(3):
			var sample = lab.get_node("LeafHeapExperiment_"+str(i))
			var offset = Vector3(7,1.0,9) if angle=="eye" else Vector3(-7,1.0,-9) if angle=="reverse" else Vector3(10,5,12)
			camera.global_position = sample.global_position+offset
			camera.look_at(sample.global_position+Vector3(0,.45,0))
			var point = sample.global_position+Vector3(1,0,0)
			var ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP)
			ray.exclude = [lab.player.get_rid()]
			var ground = lab.get_world_3d().direct_space_state.intersect_ray(ray)
			lab.player.global_position = ground.position+Vector3.UP*.01 if not ground.is_empty() else point
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/leaf_heap_%d_%s.png"%[i,angle])
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame; quit()
