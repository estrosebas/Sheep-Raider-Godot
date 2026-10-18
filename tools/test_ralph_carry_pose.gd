extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value, message):
	if not value: failures += 1; printerr(message)
# Direct transcription of Mat44::SetRotYXZ, transpose row-vector storage,
# then reflect native Y. Angles decoded by original Math_Angle* are clockwise.
func source_rotation(r: Array) -> Basis:
	var x = -float(r[0]); var y = float(r[1]); var z = float(r[2])
	var cx = cos(x); var sx = sin(x); var cy = cos(y); var sy = sin(y); var cz = cos(z); var sz = sin(z)
	var native = Basis(Vector3(cy*cz-sx*sy*sz,cy*sz+sx*sy*cz,-cx*sy),Vector3(-cx*sz,cx*cz,sx),Vector3(sy*cz+sx*cy*sz,sy*sz-sx*cy*cz,cx*cy))
	var reflect = Basis.from_scale(Vector3(1,-1,1))
	return reflect*native*reflect
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	await create_timer(.2).timeout
	var player = level.player
	player.set_physics_process(false)
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_run_data.json"))
	for name in data.animations:
		if not name.begins_with("sheep_"): continue
		player.animation_player.play(name)
		player.animation_player.seek(0,true)
		player.animation_player.advance(0)
		for joint in range(1,player.skeleton.get_bone_count()):
			var expected = source_rotation(data.animations[name].frames[0].joints[joint].rot)
			var actual = Basis(player.skeleton.get_bone_pose_rotation(joint))
			check(actual.x.distance_to(expected.x)<.0001 and actual.y.distance_to(expected.y)<.0001 and actual.z.distance_to(expected.z)<.0001,"Carry key differs from original matrix: %s joint %d"%[name,joint])
	player.animation_player.play("sheep_carry_idle")
	player.animation_player.seek(.15,true)
	player.animation_player.advance(0)
	player.legacy_skin.update_pose()
	var pose = player.legacy_skin.last_matrices
	print("Shoulders/hands Y: ",pose[15].origin.y," / ",pose[17].origin.y," ; ",pose[19].origin.y," / ",pose[21].origin.y)
	check(pose[17].origin.y>pose[15].origin.y and pose[21].origin.y>pose[19].origin.y,"Both hands must rise above their shoulders")
	check(level.get_node("Sheep_52").carry_visual_lift==0,"No artificial sheep lift")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Original carry matrix / raised hands: ",failures," failures")
	quit(1 if failures else 0)
