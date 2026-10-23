extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level); current_scene = level
	await create_timer(.4).timeout
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	for node in level.find_children("*","",true,false): node.set_process(false); node.set_physics_process(false)
	var actor = level.player
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false; actor.launch_controls_locked = false
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0); actor.camera.make_current()
	var cat = level.get_node("Catapult_46")
	var rock = level.get_node("SmallRock_74")
	var sheep = level.get_node("Flock").sheep[0]
	check(cat.has_method("launch") and rock.has_method("placement_from"),"Level05 uses live controllers instead of decorative imported actors")
	check(level.get_node("OriginalObjectCollisions").get_node_or_null("Catapult_46")==null and level.get_node("OriginalObjectCollisions").get_node_or_null("SmallRock_74")==null,"No duplicate immovable catapult/rock collision")
	var eye: Array = cat.definition.camera.eye
	check(Vector3(eye[0],eye[1],eye[2]).is_equal_approx(Vector3(-322,-1825,3915)),"Native camera572 eye was recovered")
	var button = level.get_node("SensibleButton_51")
	for sample in [[rock,0],[sheep,512],[actor,1024]]:
		cat.reset_controller(); cat.set_meta("switch_held",false)
		rock.return_home(); sheep.reset_to_home()
		actor.global_position = button.global_position
		actor.set_state(actor.WolfState.IDLE)
		cat.power = sample[1]; cat.arm_angle = 3680+floorf(cat.power*320/1024); cat.update_bucket()
		var object = sample[0]
		object.global_position = cat.bucket_box.get_center(); object.global_position.y = cat.bucket_box.end.y+.005
		check(cat.launch() and cat.projectile==object,"Real map launches %s with power%d"%[object.name,int(cat.power)])
		cat._physics_process(.2)
		check(cat.camera.is_current() and cat.camera.global_position.is_equal_approx(Vector3(-3.22,18.25,-39.15)),"Shot uses the original fixed tracking-eye position")
		var direction = (object.global_position+Vector3.UP*.35-cat.camera.global_position).normalized()
		check((-cat.camera.global_basis.z).dot(direction)>.999,"Camera follows current projectile rather than the empty catapult")
		if DisplayServer.get_name()!="headless":
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/level05_catapult_%s.png"%object.name)
		for i in range(420):
			cat._physics_process(1.0/60)
			if object==rock: rock._process(1.0/60)
			if cat.state==cat.State.IDLE and not cat.camera_active: break
		check(cat.projectile==null and not cat.camera_active and not actor.tutorial_movement_locked,"Landing restores camera and input for %s"%object.name)
		check(object.catapult_motion_owner==null,"No launch owner remains on %s"%object.name)
		print(object.name," landing: ",object.global_position," arc target: ",cat.flight_end)
	cat.reset_controller()
	actor.global_position = level.get_node("Sam_56").global_position+Vector3.RIGHT*.5
	actor.carried_object = rock; rock.carried_by = actor
	level.get_node("Sam_56")._catch_player(0)
	check(actor.carried_object==null and rock.carried_by==null and rock.global_position.is_equal_approx(rock.home),"Sam capture returns held SmallRock without losing it")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Level05 native catapult / actual geometry / three loads / tracking / landing: ",failures," failures")
	quit(1 if failures else 0)
