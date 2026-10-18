extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)

# Independent transcription of native Mat44::SetRotYXZ, with Y reflection.
func source_rotation(r: Array) -> Basis:
	var x = -float(r[0]); var y = float(r[1]); var z = float(r[2])
	var cx = cos(x); var sx = sin(x); var cy = cos(y); var sy = sin(y); var cz = cos(z); var sz = sin(z)
	var native = Basis(Vector3(cy*cz-sx*sy*sz,cy*sz+sx*sy*cz,-cx*sy),Vector3(-cx*sz,cx*cz,sx),Vector3(sy*cz+sx*cy*sz,sy*sz-sx*cy*cz,cx*cy))
	var reflect = Basis.from_scale(Vector3(1,-1,1))
	return reflect*native*reflect

func run():
	SaveFiles.startup_offered = true
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await create_timer(.2).timeout
	var actor = lab.player
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var data = actor.run_data.animations
	check(data.idle.original_name == "stand0","Empty-handed base is native STAND0")
	for name in ["idle","idle_stand1","idle_stand2","idle_stand3","idle_stand5"]:
		actor.play_anim(name)
		actor.animation_player.seek(0,true)
		actor.animation_player.advance(0)
		check(actor.animation_player.get_animation(name).loop_mode == Animation.LOOP_LINEAR,"Native idle bank clips repeat")
		for joint in range(actor.skeleton.get_bone_count()):
			var expected = source_rotation(data[name].frames[0].joints[joint].rot)
			var actual = Basis(actor.skeleton.get_bone_pose_rotation(joint))
			check(actual.x.distance_to(expected.x)<.0001 and actual.y.distance_to(expected.y)<.0001 and actual.z.distance_to(expected.z)<.0001,"Idle rotation matches original matrix: %s joint %d"%[name,joint])
	var idle = actor.original_idle
	idle.reset(actor)
	check(idle.loops_remaining >= 3 and idle.loops_remaining <= 5,"Initial STAND0 uses original 3..5 counter")
	idle.loops_remaining = 0
	idle.step(actor,data.idle.duration+.01)
	check(idle.clip in idle.VARIANTS,"Completed base idle selects one of four native variants")
	for clip in idle.VARIANTS:
		idle.clip = clip
		idle.elapsed = 0
		idle.loops_remaining = 0
		actor.play_anim(clip)
		idle.step(actor,data[clip].duration+.01)
		check(idle.clip == "idle" and idle.loops_remaining >= 2 and idle.loops_remaining <= 4,"Each idle variant returns to STAND0 with native loop count")
	actor.cinematic_controls_locked = true
	actor._process(20)
	check(idle.clip == "idle","Cinematics suppress idle fidgets")
	actor.cinematic_controls_locked = false
	actor.set_state(actor.WolfState.WALK)
	check(actor.animation_player.current_animation == "walk","Movement interrupts idle variant")
	actor.set_state(actor.WolfState.IDLE)
	check(idle.clip == "idle" and idle.elapsed == 0,"Returning to rest restarts native base")
	actor.global_position = Vector3.ZERO
	actor.animation_player.seek(.15,true)
	actor.animation_player.advance(0)
	actor.legacy_skin.update_pose()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960,900)
		var camera = Camera3D.new()
		lab.add_child(camera)
		camera.position = Vector3(2.5,1.7,-3.4)
		camera.look_at(Vector3(0,.85,0))
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/ralph_original_idle.png")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Ralph original idle poses / native variants: ",failures," failures")
	quit(1 if failures else 0)
