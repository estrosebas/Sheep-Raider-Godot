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
	# Isolate the clear-view case from other laboratory fixtures and its floor.
	actor.global_position = Vector3(200,100,195)
	actor.camera.global_position = Vector3(200,102,208)
	actor.camera.look_at(Vector3(200,102,198))
	actor.set_state(actor.WolfState.PIT_FALL)
	check(actor.animation_player.current_animation == "fall_death" and actor.camera.top_level,"Fatal direct fall keeps DEAD1 and frozen camera")
	var held_camera = actor.camera.global_transform
	check(actor.camera.quaternion.is_equal_approx(actor.pit_camera_start),"Direct fall does not snap camera rotation on entry")
	actor.state_time = actor.direct_fall_camera_tilt_time*.25
	actor.step_pit_fall(0)
	var first_tilt = actor.camera.quaternion.angle_to(actor.pit_camera_start)
	actor.state_time = actor.direct_fall_camera_tilt_time*.5
	actor.step_pit_fall(0)
	check(first_tilt>0 and actor.camera.quaternion.angle_to(actor.pit_camera_start)>first_tilt,"Downward tilt advances smoothly instead of snapping")
	check(actor.camera.global_position.is_equal_approx(held_camera.origin),"Tilting preserves the fixed world-space camera position")
	actor.state_time = actor.direct_fall_impact_time-.01
	actor.step_pit_fall(0)
	check(not actor.void_impact.visible,"Impact must not appear before the impact sound")
	var settled_camera = actor.camera.global_transform
	check(actor.camera.quaternion.is_equal_approx(actor.pit_camera_target) and (-actor.camera.global_basis.z).y<(-held_camera.basis.z).y,"Camera settles gently downward before the impact")
	actor.global_position.y -= 30
	actor.state_time = actor.direct_fall_impact_time+.15
	actor.step_pit_fall(0)
	check(actor.direct_fall_impact_played and actor.void_impact.visible,"Fatal impact switches to original AEXPLOS2 BOOM")
	check(actor.void_impact.animation_player.current_animation == "boom","Native BOOM animation is sampled")
	check(actor.camera.global_transform.is_equal_approx(settled_camera),"Impact keeps the settled camera fixed without tracking Ralph")
	var impact_position = actor.void_impact.global_position
	actor.step_pit_fall(0)
	check(actor.void_impact.global_position.is_equal_approx(impact_position),"Impact is triggered once, not repositioned per frame")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/ralph_void_impact.png")
	# A wall in either gameplay or camera-only geometry suppresses the artwork,
	# while retaining the synchronized original impact sound.
	var wall = StaticBody3D.new(); var wall_shape = CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new(); wall_shape.shape.size = Vector3(12,12,.5)
	wall.add_child(wall_shape); lab.add_child(wall)
	wall.global_position = actor.camera.global_position-actor.camera.global_basis.z*5
	wall.global_basis = actor.camera.global_basis
	for layer in [1,2]:
		wall.collision_layer = layer
		await physics_frame; await physics_frame
		actor.void_impact_audio.stop(); actor.play_void_impact()
		check(not actor.void_impact.visible and actor.void_impact_audio.playing,"Obstructed view hides BOOM but keeps impact sound (layer%d)"%layer)
		actor.step_pit_fall(0)
		check(not actor.void_impact.visible,"Sampling the death animation cannot reshow an occluded impact")
	wall.global_position = actor.camera.global_position-actor.camera.global_basis.z*12
	await physics_frame; await physics_frame
	actor.play_void_impact()
	check(actor.void_impact.visible,"Distant scenery beyond six metres does not suppress BOOM")
	wall.queue_free(); await physics_frame; await physics_frame
	var floor_body = StaticBody3D.new(); var floor_shape = CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new(); floor_shape.shape.size = Vector3(20,1,20)
	floor_body.add_child(floor_shape); lab.add_child(floor_body)
	floor_body.global_position = actor.camera.global_position+Vector3.DOWN*1.1
	await physics_frame; await physics_frame
	actor.play_void_impact()
	check(actor.void_impact.visible,"Visible ground hit by the tilted camera is not treated as an intervening wall")
	floor_body.queue_free(); await physics_frame; await physics_frame
	actor.play_void_impact()
	check(actor.void_impact.visible and actor.void_impact_audio.playing,"An unobstructed view retains original BOOM and audio")
	actor.respawn_at_checkpoint()
	check(not actor.void_impact.visible,"Respawn clears the impact model")
	actor.set_state(actor.WolfState.RUN_AIR)
	actor.set_state(actor.WolfState.PIT_FALL)
	check(actor.animation_player.current_animation == "pit_fall","Air run exhaustion keeps separate STRIKE2")
	check(not actor.void_impact.visible,"Air run exhaustion does not reuse direct-fall impact")
	actor.respawn_at_checkpoint()
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Ralph normal FALL1 / carry FALL2 / fatal fall separation: ",failures," failures")
	quit(1 if failures else 0)
