extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://fragment_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	lab.player.set_physics_process(false); lab.player.set_process(false)
	var reference: ArrayMesh = lab.get_node("LeafMapFragment_0").mesh
	var original: ArrayMesh = load("res://assets/levels/lvl_04/scenery.tres")
	var native_leaves = PackedVector3Array()
	for s in range(original.get_surface_count()):
		if original.surface_get_name(s).begins_with("native_leaf_heap"):
			var arrays = original.surface_get_arrays(s)
			for i in arrays[Mesh.ARRAY_INDEX]: native_leaves.append(arrays[Mesh.ARRAY_VERTEX][i])
	var extracted = PackedVector3Array()
	for s in range(reference.get_surface_count()):
		if reference.surface_get_name(s).begins_with("native_leaf_heap"):
			for p in reference.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]: extracted.append(p+reference.get_meta("source_origin"))
	check(extracted.size()==390 and native_leaves.size()==extracted.size(),"Both native heaps must be present: 130 triangles")
	for i in range(mini(extracted.size(),native_leaves.size())):
		check(extracted[i].is_equal_approx(native_leaves[i]),"Extracted triangle differs from native world position")
	check(reference.get_surface_count()>1,"Fragment must include surrounding map materials")
	print("Fragment bounds: ",reference.get_aabb(),"; surfaces: ",reference.get_surface_count())
	var camera = Camera3D.new(); lab.add_child(camera); camera.fov = 65; camera.make_current()
	root.size = Vector2i(1280,720)
	for mode in range(4):
		var sample = lab.get_node("LeafMapFragment_"+str(mode))
		for s in range(reference.get_surface_count()):
			var a = reference.surface_get_arrays(s); var b = sample.mesh.surface_get_arrays(s)
			check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV],"Comparisons must keep geometry and UV identical")
		check(sample.has_node("NativeTerrainTop"),"Extracted fragment must have collision")
		if DisplayServer.get_name()!="headless":
			for angle in ["front","back"]:
				camera.global_position = sample.position+Vector3(10,2,13)*(1 if angle=="front" else -1)
				camera.global_position.y = 2
				camera.look_at(sample.position+Vector3(0,.6,0))
				lab.player.global_position = sample.position+Vector3(0,1,0)
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://validation/leaf_fragment_%d_%s.png"%[mode,angle])
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame
	print("Native fragment / both heaps / original vertices and UV / four materials: ",failures," failures")
	quit(failures)
