extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func stop_scripts(scene):
	for node in scene.find_children("*","",true,false): node.set_process(false); node.set_physics_process(false)
func ground(actor,point):
	actor.global_position = point+Vector3.UP*.05
	await physics_frame; await physics_frame
	actor.velocity = Vector3.DOWN*2
	actor.move_and_slide()
	for i in range(3):
		actor.velocity = Vector3.DOWN*2; actor.move_and_slide()
func finish_action(player):
	for i in range(5):
		if player.item_actions.busy: player.item_actions._process(10)
func simulate_shot(catapult,rock = null):
	var broke = false
	for i in range(420):
		catapult._physics_process(1.0/60)
		if rock:
			broke = broke or rock.shattered
			rock._process(1.0/60)
		if catapult.state==catapult.State.IDLE and not catapult.camera_active: break
	return broke
func run():
	SaveFiles.startup_offered = true
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	stop_scripts(lab)
	var player = lab.player
	player.cinematic_controls_locked = false; player.tutorial_movement_locked = false; player.launch_controls_locked = false
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0); player.camera.make_current()
	var cat = lab.get_node("Catapult")
	var rock = lab.get_node("CatapultRock")
	var sheep = lab.get_node("CatapultSheep")
	var button = lab.get_node("CatapultButton")
	cat.update_bucket()
	check(cat.visual.skeleton.get_bone_count()==10 and rock.visual.rig.animations.has("stand"),"Lab uses native catapult and carryable rock models")
	check(cat.has_node("ChassisCollision") and cat.get_node("ChassisCollision").get_child(0).shape.get_faces().size()>0,"Visible chassis has exact mesh collision without filling the regulator opening")
	var chassis_ray = PhysicsRayQueryParameters3D.create(cat.global_position+Vector3(0,2,0),cat.global_position+Vector3(0,.1,0),1)
	var chassis_hit = lab.get_world_3d().direct_space_state.intersect_ray(chassis_ray)
	check(not chassis_hit.is_empty() and chassis_hit.collider==cat.get_node("ChassisCollision"),"Physics ray strikes the visible chassis above the laboratory floor")
	for door in lab.find_children("LevelDoor_*","",false,false):
		var ray = PhysicsRayQueryParameters3D.create(door.global_position+Vector3.UP,door.global_position+Vector3.DOWN*2,1)
		check(not actor_floor(lab,ray).is_empty(),"Every level door has laboratory ground below")
	check(cat.global_position.distance_to(lab.get_node("LevelDoor_03").global_position)>15,"Catapult no longer overlaps the level doors")
	cat.apply_pose(3680)
	var loaded_tip = cat.visual.legacy_skin.last_matrices[9].origin
	cat.apply_pose(0)
	check(cat.visual.legacy_skin.last_matrices[9].origin.y>loaded_tip.y+1,"Firing lifts the original arm instead of driving it downward")
	cat.apply_pose(cat.arm_angle)
	check(rock.broken_visual.rig.animations.has("break"),"Original AROCHE5B breaking animation recovered")
	# Real pickup/placement callbacks, with the native mode1 carry animation.
	await ground(player,rock.global_position+Vector3(0,0,1))
	check(rock.interact(player),"E starts native small-rock pickup")
	finish_action(player)
	check(player.carried_object==rock and rock.carried_by==player,"Native hand18 carry is established")
	rock._process(0)
	check(not player.inventory.can_open(),"Bulky rock is carried directly, not put in inventory")
	rock.move_carrier(.016)
	check(player.animation_player.current_animation.begins_with("sheep_carry_"),"SmallRock uses original WOLF_MODE_CARRY poses")
	var top = cat.bucket_box.end.y
	var centre = cat.bucket_box.get_center()
	await ground(player,Vector3(cat.bucket_box.position.x-.2,top,centre.z))
	player.skeleton.rotation.y = PI*.5
	check(rock.interact(player),"E starts safe placement onto catapult bucket")
	finish_action(player)
	check(not rock.carried_by and not player.carried_object,"Placement releases held rock")
	check(rock.global_position.y>cat.bucket_box.end.y+.4,"Native front placement releases in air rather than teleporting to floor")
	await physics_frame; await physics_frame
	for i in range(35): rock._physics_process(1.0/60)
	cat.scan_bucket()
	check(cat.bucket_contents.has(rock),"Placed rock physically occupies native bucket")
	# Move to original operating zone, translated only for the lab fixture.
	await ground(player,cat.global_position+Vector3(2,0,1.95))
	check(cat.interact(player),"Original activation zone enables power regulator")
	cat.axis_override = 1.0
	for i in range(180): cat._physics_process(1.0/60)
	check(cat.power==1024 and cat.arm_angle==4000,"Regulator reaches native maximum1024 / angle0xfa0")
	check(player.animation_player.current_animation=="catapult_turn" and cat.power_sound.playing,"Adjusting uses original TURN and loop118")
	cat.gauge._process(0)
	check(cat.gauge.visible,"Native ICTJAUG1 gauge is visible only while regulating")
	var high_pose = cat.visual.skeleton.get_bone_pose_rotation(6)
	cat.axis_override = -1.0
	for i in range(180): cat._physics_process(1.0/60)
	check(cat.power==0 and cat.arm_angle==3680,"Regulator clamps at native minimum")
	check(not high_pose.is_equal_approx(cat.visual.skeleton.get_bone_pose_rotation(6)),"Native regulator wheel actually rotates")
	cat.axis_override = 0.0; cat._physics_process(.016)
	check(not cat.power_sound.playing,"Regulator loop stops when adjustment stops")
	if DisplayServer.get_name()!="headless":
		var view = Camera3D.new(); lab.add_child(view)
		view.global_position = cat.global_position+Vector3(10,7,11)
		view.look_at(cat.global_position+Vector3.UP)
		view.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/catapult_regulator.png")
		cat.gauge.hide()
		view.global_position = Vector3(39,29,68); view.look_at(Vector3(5,0,30))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/catapult_lab_layout.png")
		view.queue_free(); player.camera.make_current()
	cat.stop_operating()
	check(not player.tutorial_movement_locked,"Leaving regulator returns movement control")
	# Fire from the linked button; no repeated shots while it stays down.
	await ground(player,button.global_position)
	button._physics_process(.016)
	check(cat.projectile==rock and cat.camera.is_current(),"Native button51 fires the loaded rock and tracking camera")
	var end_low = cat.flight_end
	var launch_count = cat.launch_count
	for i in range(3): button._physics_process(.016)
	check(cat.launch_count==launch_count,"Holding the fire button cannot repeat the shot")
	var hit_during_flight = simulate_shot(cat,rock)
	check(rock.catapult_motion_owner==null,"Rock flight finishes without retaining the controller")
	if not hit_during_flight:
		# MSG_LANDED(0) resumes gravity; MSG_LANDED(1) breaks the rock.
		rock.landed(true)
		check(rock.shattered and rock.broken_visual.visible,"Native impact switches to AROCHE5B BREAK")
	if rock.shattered:
		rock._process(float(rock.broken_visual.rig.animations["break"].duration)+.01)
	check(not rock.shattered and rock.global_position.is_equal_approx(rock.home),"Broken rock returns home at the native animation's end")
	check(not player.tutorial_movement_locked and player.camera.is_current(),"Shot camera returns after original two-second hold")
	# Independent sheep/Ralph loads share the same arc, without their own
	# gravity, floor-death probes or flock AI fighting the launch controller.
	for object in [sheep,player]:
		cat.reset_controller(); cat.set_meta("switch_held",false)
		rock.return_home()
		player.global_position = cat.global_position+Vector3(4,0,4)
		sheep.global_position = cat.global_position+Vector3(-3,0,3)
		cat.power = 1024; cat.arm_angle = 4000; cat.update_bucket()
		object.global_position = cat.bucket_box.get_center(); object.global_position.y = cat.bucket_box.end.y+.005
		check(cat.launch() and cat.projectile==object,"Catapult loads %s independently"%object.name)
		check(is_instance_valid(object.catapult_motion_owner),"Projectile suppresses competing locomotion")
		check(is_equal_approx(cat.flight_end.distance_to(end_low),10.0),"Native power changes landing distance by exactly maxDist*2")
		simulate_shot(cat)
		check(not is_instance_valid(object.catapult_motion_owner) and not cat.camera_active,"Landing releases projectile and camera")
		check(not player.tutorial_movement_locked,"Every load returns player controls")
	# A small rock can hold a pressure button while Ralph loads himself.
	rock.return_home(); rock.global_position = button.global_position
	player.global_position += Vector3.RIGHT*4
	await physics_frame; await physics_frame
	button._physics_process(.016)
	check(button.occupants.has(rock),"SmallRock weight can activate the fire button")
	cat.reset_controller()
	cat.freeze_player(); cat.state = cat.State.OPERATED
	player.set_state(player.WolfState.BLAST_DEATH)
	cat._physics_process(.016)
	check(not cat.controlling and not player.tutorial_movement_locked and player.current_state==player.WolfState.BLAST_DEATH,"Death interrupts regulation without trapping the player or overwriting death animation")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame
	print("Catapult native regulator / HUD / rock carry-place / button / three projectiles / camera: ",failures," failures")
	quit(1 if failures else 0)

func actor_floor(lab,ray):
	return lab.get_world_3d().direct_space_state.intersect_ray(ray)
