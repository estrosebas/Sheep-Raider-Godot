extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)

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
	actor.set_state(actor.WolfState.FALL)
	var source = actor.run_data.animations.fall
	check(source.original_name == "fall1" and actor.animation_player.current_animation == "fall","Empty-handed descent uses native FALL1")
	check(actor.run_data.animations.sheep_carry_fall.original_name == "fall2","Carried sheep retains its distinct FALL2")
	check(actor.animation_player.get_animation("fall").loop_mode == Animation.LOOP_LINEAR,"Ordinary fall repeats while airborne")
	for i in range(source.frames.size()):
		var time = 0.0 if i == 0 else float(source.frames[i-1].time)
		actor.animation_player.seek(time,true)
		actor.animation_player.advance(0)
		for joint in range(actor.skeleton.get_bone_count()):
			var expected = source_rotation(source.frames[i].joints[joint].rot)
			var actual = Basis(actor.skeleton.get_bone_pose_rotation(joint))
			check(actual.x.distance_to(expected.x)<.0001 and actual.y.distance_to(expected.y)<.0001 and actual.z.distance_to(expected.z)<.0001,"FALL1 rotation matches native key: %d joint %d"%[i,joint])
	actor.set_state(actor.WolfState.PIT_FALL)
	check(actor.animation_player.current_animation == "fall_death" and actor.camera.top_level,"Fatal direct fall keeps DEAD1 and frozen camera")
	actor.respawn_at_checkpoint()
	actor.set_state(actor.WolfState.RUN_AIR)
	actor.set_state(actor.WolfState.PIT_FALL)
	check(actor.animation_player.current_animation == "pit_fall","Air run exhaustion keeps separate STRIKE2")
	actor.respawn_at_checkpoint()
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Ralph normal FALL1 / carry FALL2 / fatal fall separation: ",failures," failures")
	quit(1 if failures else 0)
