extends SceneTree
var failures=0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func triangle_count(mesh: ArrayMesh) -> int:
	var count=0
	for surface in range(mesh.get_surface_count()):
		var arrays=mesh.surface_get_arrays(surface)
		count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://foliage_lab_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var base="res://assets/levels/lvl_04"
	var metadata=JSON.parse_string(FileAccess.get_file_as_string(base+"/data/foliage.json"))
	var native=JSON.parse_string(FileAccess.get_file_as_string(base+"/data/scenery.json"))
	var original_count=0
	for group in native.values(): original_count+=group.verts.size()/3
	var scenery:ArrayMesh=load(base+"/scenery.tres")
	check(triangle_count(scenery)==original_count,"Splitting leaf material preserves every original map triangle exactly once")
	var heap_surface=-1
	for surface in range(scenery.get_surface_count()):
		var material:ShaderMaterial=scenery.surface_get_material(surface)
		if scenery.surface_get_name(surface).begins_with("native_leaf_heap"):
			heap_surface=surface
			check(material.shader.resource_path.ends_with("bush_backface_cutout.gdshader"),"Level retains the prior material while new variants stay in the lab")
		else: check(not material.shader.resource_path.ends_with("bush_backface_cutout.gdshader"),"Other terrain, trees, grass and water retain their existing materials")
	check(heap_surface>=0,"Leaf patch is persisted in the editor-visible scenery resource")
	if heap_surface>=0:
		var arrays=scenery.surface_get_arrays(heap_surface)
		check(arrays[Mesh.ARRAY_VERTEX].size()==metadata.triangles.size()*3,"Only130 source leaf-heap triangles receive the patch")
	var lab=load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene=lab
	await create_timer(.4).timeout
	var player=lab.player; player.set_physics_process(false)
	var heap=lab.get_node("BullLeafHeap")
	var noise=lab.get_node("BullLeafHeapNoise"); noise.set_physics_process(false)
	check(triangle_count(heap.mesh)==int(metadata.sample_triangles) and int(metadata.sample_triangles)==67,"Lab displays a complete unchanged connected component of the original heap")
	check(heap.scale.is_equal_approx(Vector3.ONE) and heap.position==Vector3(1,0,-27),"Lab sample retains source dimensions behind the object stations")
	var bush=lab.get_node("Bush")
	check(not bush.visual.legacy_skin.materials.any(func(m): return m.shader==heap.mesh.surface_get_material(0).shader),"Rejected bush patch stays separate from the two-sided terrain reference")
	check(lab.get_node_or_null("LeafHeapExperiment_0")==null and lab.get_node_or_null("LeafMapFragment_0")==null,"Rejected experiments remain archived and absent from lab")
	var spot=Vector3.INF
	for a in range(noise.polygon.size()):
		var candidate=Vector2.ZERO
		for p in noise.polygon: candidate+=p
		candidate/=noise.polygon.size()
		candidate=candidate.lerp(noise.polygon[a],.25)
		if Geometry2D.is_point_in_polygon(candidate,noise.polygon):
			spot=Vector3(candidate.x,0,candidate.y);break
	check(spot!=Vector3.INF,"Translated lab polygon has a valid playable interior")
	if spot!=Vector3.INF:
		player.global_position=spot; player.set_state(player.WolfState.SNEAK); noise.positions.clear(); noise._physics_process(.016)
		check(noise.noise_count==0,"Stationary player causes no rustle in lab heap")
		player.global_position.x+=.03; noise._physics_process(.016)
		check(noise.noise_count>0 and noise.sound.playing and noise.emitter.emitting,"Walking in lab heap reuses native rustle129 and leaf particles")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
	lab.queue_free(); await process_frame
	print("Native leaf heap / removed experiments / top collision / source preservation / rustle: ",failures," failures")
	quit(failures)
