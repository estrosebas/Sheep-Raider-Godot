extends SceneTree
func _init(): call_deferred("run")
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	level.get_node("DaffyLessons").movies[0].played = true
	await create_timer(.3).timeout
	var player = level.player
	player.set_physics_process(false)
	player.play_anim("sheep_carry_idle")
	player.animation_player.seek(.15,true)
	player.animation_player.advance(0)
	player.legacy_skin.update_pose()
	var bounds = {}
	var mesh = player.skeleton.get_node("MeshInstance3D").mesh
	for s in range(mesh.get_surface_count()):
		var a = mesh.surface_get_arrays(s)
		var ids = a[Mesh.ARRAY_CUSTOM0]
		for i in range(a[Mesh.ARRAY_VERTEX].size()):
			var id = int(ids[i*4])
			var p = player.legacy_skin.last_matrices[id]*player.legacy_skin.inverse_rests[id]*a[Mesh.ARRAY_VERTEX][i]
			bounds[id] = maxf(bounds.get(id,-INF),p.y)
	print("Ralph maximum Y per joint: ",bounds)
	print("Carry joint18: ",player.legacy_skin.last_matrices[18].origin)
	var sheep = level.get_node("Sheep_52")
	sheep.visual.sample_animation("stand8",.15)
	var ranges = {}
	for s in sheep.visual.rig.surfaces.values():
		for i in range(s.verts.size()):
			var id = int(s.bones[i])
			var v = s.verts[i]
			var p = sheep.visual.legacy_skin.last_matrices[id]*sheep.visual.legacy_skin.inverse_rests[id]*Vector3(v[0],v[1],v[2])
			var r = ranges.get(id,Vector2(INF,-INF))
			ranges[id] = Vector2(minf(r.x,p.y),maxf(r.y,p.y))
	print("Sheep Y ranges: ",ranges)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	level.queue_free()
	await process_frame
	await process_frame
	quit()
