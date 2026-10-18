extends SceneTree
const Shell = preload("res://scripts/levels/original_visual_collision.gd")
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var mesh = level.get_node("Scenery").mesh
	var additive = PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		if Shell.surface_is_solid(mesh,surface): continue
		var arrays = mesh.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]; var indices = arrays[Mesh.ARRAY_INDEX]
		if indices==null or indices.is_empty(): additive.append_array(vertices)
		else:
			for index in indices: additive.append(vertices[index])
	check(not additive.is_empty() and Shell.solid_faces(mesh).size()<mesh.get_faces().size(),"Decorative additive light triangles are excluded from collision geometry")
	var start_region = AABB(Vector3(-22,-3,-58),Vector3(32,14,28))
	var sampled = 0; var hits = 0
	for i in range(0,additive.size(),3):
		var a = additive[i]; var b = additive[i+1]; var c = additive[i+2]
		var midpoint = (a+b+c)/3
		if not start_region.has_point(midpoint): continue
		var normal = (b-a).cross(c-a).normalized()
		if normal.is_zero_approx(): continue
		var query = PhysicsRayQueryParameters3D.create(midpoint+normal*.05,midpoint-normal*.05,3)
		query.exclude = [level.player.get_rid()]
		var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
		sampled+=1
		if not hit.is_empty(): hits+=1; print("Light crossing hit: ",midpoint," ",hit.collider)
	check(sampled>0 and hits==0,"Gameplay and camera rays cross every sampled starting light beam without hitting it")
	var origin = level.player.global_position
	var roof = PhysicsRayQueryParameters3D.create(origin+Vector3.UP*1.5,origin+Vector3.UP*12,2)
	check(not level.get_world_3d().direct_space_state.intersect_ray(roof).is_empty(),"Opaque starting roof still blocks the camera")
	var ground = PhysicsRayQueryParameters3D.create(origin+Vector3.UP,origin-Vector3.UP*2,1)
	ground.exclude = [level.player.get_rid()]
	check(not level.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(),"Starting ground remains solid")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level02 non-solid light / solid roof and ground: ",failures," failures; sampled ",sampled," light triangles")
	quit(failures)
