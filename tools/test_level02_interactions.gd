extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func finish_actions(player):
	player.item_actions.set_process(false)
	for i in range(8):
		if player.item_actions.busy: player.item_actions._process(10)
func equip(player,item):
	player.inventory.animate_selection = false
	if not player.inventory.state.items.has(item.item_id):
		player.inventory.add_item({"id":item.item_id,"class_id":item.class_id,"label":item.item_label,"icon":item.icon_path,"kept":false},item)
	else:
		player.inventory.state.select_class(item.class_id)
		player.inventory.equipped_id = item.item_id
		player.inventory.equipped.emit(player.inventory.state.get_selected_object())
func stop_audio(level):
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.startup_offered = true
	GameLocalization.select("es",false)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab); current_scene = lab
	check(not lab.has_node("BushVolume") and not lab.has_node("BushRender_1"),"Discarded bush experiments stay disabled in the normal laboratory")
	check(lab.get_node("Bush").render_variant == 2,"Accepted option2 is the default bush renderer")
	preload("res://scripts/testing/experiments/bush_render_experiments.gd").setup(lab)
	await create_timer(.3).timeout
	var player = lab.player
	player.set_physics_process(false); player.set_process(false)
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var perfume = lab.get_node("Item_39")
	var fan = lab.get_node("Item_7")
	player.global_position = Vector3(0,0,0)
	player.skeleton.rotation.y = 0
	equip(player,perfume)
	check(player.inventory.use_selected(),"Perfume uses original placing animation")
	finish_actions(player)
	check(perfume.active and perfume.deployed and perfume.holder == null,"Placed perfume emits and remains in world")
	player.global_position = Vector3(0,0,-2)
	equip(player,fan)
	player.play_anim("held_item_idle")
	player.animation_player.seek(.2,true); player.animation_player.advance(0); player.apply_legacy_reaction_pose()
	fan._update_held_position()
	var hand = player.skeleton.global_transform*player.legacy_skin.last_matrices[18]
	check(fan.global_position.distance_to(hand.origin)<.001,"Fan attaches to original hand joint18")
	check(fan.actor_visual.animation_player.current_animation == "link","Fan uses recovered LINK held pose")
	check(player.inventory.use_selected(),"Fan activates")
	player._physics_process(.016)
	check(player.animation_player.current_animation == "fan_blow_idle","Ralph uses original STANDV1 fan pose")
	for i in range(100):
		fan.item_step(.05); perfume.item_step(.05); perfume.scent._process(.05)
	check(fan.actor_visual.animation_player.current_animation == "standv1","Fan plays original wind/spinning geometry")
	check(perfume.blow_time > 4 and perfume.can_smell_from(perfume.global_position+Vector3(0,0,18)) and not perfume.can_smell_from(perfume.global_position+Vector3(3,0,18)),"Fan extends original twenty-metre scent corridor with two-metre lateral limit")
	check(perfume.scent_position() == perfume.global_position,"Perfume attracts sheep toward the bottle, not away from it")
	check(perfume.scent.emitted_total > 0 and perfume.scent.frames.size() == 4,"Perfume renders original scent sprite sheet")
	var attracted = lab.get_node("Sheep")
	attracted.global_position = perfume.global_position+Vector3(1,0,12)
	var sheep_start = attracted.global_position.distance_to(perfume.global_position)
	# Perfume now uses native SCENT_TURN + SCENT_SNIFF before WALK2.
	# Allow their complete clips rather than expecting movement after .5s.
	await create_timer(7).timeout
	check(attracted.global_position.distance_to(perfume.global_position) < sheep_start-.2,"Sheep follows wind-carried scent toward the perfume bottle")
	if DisplayServer.get_name() != "headless":
		player.animation_player.seek(.1,true); player.animation_player.advance(0); player.apply_legacy_reaction_pose()
		fan._update_held_position()
		var camera = Camera3D.new()
		lab.add_child(camera)
		camera.global_position = player.global_position+Vector3(3,2.3,4)
		camera.look_at(player.global_position+Vector3(0,1,1))
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/original_fan_and_perfume.png")
	var before = perfume.blow_time
	player.skeleton.rotation.y = PI
	for i in range(10): fan.item_step(.05); perfume.item_step(.05)
	check(perfume.blow_time < before,"Scent range decays when fan faces away")
	fan.deactivate(); player._process(.01)
	check(fan.actor_visual.animation_player.current_animation == "link","Stopping fan restores original held pose")
	var rock = lab.get_node("PushableRock")
	player.global_position = rock.global_position+Vector3(-1.4,-rock.global_position.y,0)
	player.velocity = Vector3.ZERO
	Input.action_press("action")
	check(rock.interact(player),"Rock starts native PUSH1A")
	finish_actions(player)
	check(player.push_target == rock and player.animation_player.current_animation == "push_loop","Push action enters native PUSH1B")
	var start = rock.global_position
	for i in range(60):
		await physics_frame
		rock.step_pusher(player,1.0/60.0)
	check(rock.global_position.x > start.x+.2 and absf(rock.global_position.z-start.z)<.01,"Rock and player physically move along selected push axis")
	check(not rock.roll.is_equal_approx(Basis.IDENTITY),"Rock rolls by displacement and radius")
	Input.action_release("action"); rock.step_pusher(player,.05)
	check(player.push_target == null and player.animation_player.current_animation == "push_end","Releasing E plays native PUSH1C")
	finish_actions(player)
	var bush = lab.get_node("Bush")
	player.global_position = bush.global_position+Vector3(0,0,-.9)
	player.velocity = Vector3.ZERO
	check(bush.interact(player),"Bush enters using original JUMP6")
	finish_actions(player)
	bush._process(2)
	check(player.active_bush == bush and not player.skeleton.get_node("MeshInstance3D").visible and bush.disguise.idle_clip == "stand1","Bush swaps to native ABCOYO01 hidden model")
	if DisplayServer.get_name() != "headless":
		var camera = lab.get_viewport().get_camera_3d()
		camera.global_position = player.global_position+Vector3(2,1.6,-3)
		camera.look_at(player.global_position+Vector3.UP*.7)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/original_bush_cover.png")
	check(bush.hidden_from_sam(),"Stationary bush hides Ralph")
	player.velocity.x = 1
	check(not bush.hidden_from_sam(),"Moving bush is visible")
	player.velocity = Vector3.ZERO; bush.age = 4
	check(bush.eat(20.1) and player.active_bush == null and bush.respawn_time > 0,"Nearby sheep consumes worn bush after native twenty seconds")
	bush._process(7.1)
	check(bush.respawn_time == 0 and bush.visual.visible,"Bush recovers at home")
	var round_bush = lab.get_node("BushVolume")
	player.global_position = round_bush.global_position+Vector3(0,0,-.9)
	check(round_bush.interact(player),"Volume variant shares bush entry interaction")
	finish_actions(player)
	check(round_bush.is_rising(),"Bush HEAD1 entry remains stationary before walking")
	player.velocity = Vector3(1,0,0)
	player._physics_process(.016)
	check(absf(player.velocity.x)<.001,"First movement cannot slide during native bush rise")
	round_bush._process(2)
	check(round_bush.hidden_from_sam() and round_bush.disguise.asset_directory == "res://assets/items/bush_custom_disguise","Editable copy shares concealment and uses independent source assets")
	var copy_mesh = round_bush.disguise.skeleton.get_node("Visual").mesh
	var native_mesh = load("res://assets/items/bush_disguise/worn.tres")
	check(copy_mesh.get_surface_count() == native_mesh.get_surface_count()+2,"Copy retains original surfaces and adds only two foliage closure surfaces")
	for clip in ["walk2","walk1","jump1","fall1","stand1"]:
		round_bush.disguise.sample_animation(clip,.2)
		check(round_bush.disguise.legacy_skin.last_matrices.size() == round_bush.disguise.rig.joints.size(),"Closed foliage preserves animated joint palette: "+clip)
	round_bush.disguise.idle("stand1")
	check(player.run_data.sounds.has("30") and player.run_data.sounds.has("33"),"Original bush animation sound events resolve to extracted samples")
	if DisplayServer.get_name() != "headless":
		var camera = lab.get_viewport().get_camera_3d()
		camera.global_position = Vector3(7,2.8,21)
		camera.look_at(Vector3(7,.7,16))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/bush_variants.png")
	round_bush.leave()
	finish_actions(player)
	check(player.active_bush == null and round_bush.visual.visible,"Volume variant exits with original animation")
	check(round_bush.visual.idle_clip == "stand1","Bush scenery OUT6 finishes instead of looping after exit")
	var exit_sample = false
	for sound in player.animation_sfx_players:
		if sound.stream and sound.stream.resource_path == "res://assets/levels/lvl_02/audio/33.wav": exit_sample = true
	check(exit_sample,"Native OUT6 final sound event33 plays on exit")
	var facing = lab.get_node("BushRender_1")
	player.global_position = facing.global_position+Vector3(0,0,-.9)
	check(facing.interact(player),"Third original copy accepts bush interaction")
	finish_actions(player); facing._process(2)
	var foliage_count = 0
	for mat in facing.disguise.legacy_skin.materials:
		var texture = mat.get_shader_parameter("albedo_texture")
		if texture != null and (texture.resource_path.ends_with("page_11.png") or texture.resource_path.ends_with("page_9.png")):
			check(mat.shader.resource_path == "res://shaders/bush_depth_cutout.gdshader","Nearest visible foliage writes depth without rotating")
			foliage_count += 1
		else: check(mat.shader.resource_path != "res://shaders/bush_depth_cutout.gdshader","Ralph body keeps original rendering and direction")
	check(foliage_count == 2 and facing.hidden_from_sam(),"Third copy preserves two original foliage surfaces and concealment")
	if DisplayServer.get_name() != "headless":
		var camera = lab.get_viewport().get_camera_3d()
		for i in range(3):
			var angle = i*PI*.5
			camera.global_position = player.global_position+Vector3(sin(angle)*3,1.6,cos(angle)*3)
			camera.look_at(player.global_position+Vector3.UP*.7)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/bush_depth_%d.png"%i)
	facing.leave(); finish_actions(player)
	check(player.active_bush == null,"Third copy exits normally")
	for index in [2,3]:
		var candidate = lab.get_node("BushRender_%d"%index)
		player.global_position = candidate.global_position+Vector3(0,0,-.9)
		check(candidate.interact(player),"Layer experiment accepts entry: "+str(index))
		finish_actions(player); candidate._process(2)
		check(candidate.hidden_from_sam() and not candidate.camera_facing,"Layer experiment retains concealment and fixed direction")
		candidate.leave(); finish_actions(player)
	if DisplayServer.get_name() != "headless":
		var camera = lab.get_viewport().get_camera_3d()
		camera.global_position = Vector3(9,5,33)
		camera.look_at(Vector3(9,.5,24))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/bush_layer_comparison.png")
	stop_audio(lab); lab.queue_free(); await process_frame
	var level = load("res://scenes/levels/Level02.tscn").instantiate()
	root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var native_player = level.player
	native_player.set_physics_process(false)
	check(level.get_node("CameraVisualCollision").collision_layer == 2 and native_player.camera_pivot.collision_mask == 3,"Roof and rendered shell block camera on its own collision layer")
	var shape = level.get_node("Collision/CollisionShape3D").shape
	check(shape.get_meta("native_triangles") == 4435 and shape.backface_collision,"Starting walls use reconciled visible shell collision")
	var query = PhysicsRayQueryParameters3D.create(native_player.global_position+Vector3.UP*1.5,native_player.global_position+Vector3.UP*12,2)
	check(not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Camera ceiling ray hits the visible starting roof")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level02_corrected_spawn.png")
	var mailbox = level.get_node("Mailbox_66")
	mailbox._deliver(native_player)
	var r = mailbox.definition.camera.rotation
	var expected = Basis.from_euler(Vector3(-r[0],r[1],-r[2])*TAU/4096)
	check(mailbox.delivery_camera.global_basis.is_equal_approx(expected),"Mailbox camera orientation is global, unaffected by artwork yaw")
	check(mailbox.rotation.is_zero_approx() and absf(mailbox.visual.rotation.y)>1,"Mailbox world collision stays unrotated while source artwork faces native direction")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level02_corrected_mailbox.png")
	mailbox._release_camera()
	var native_bush = level.get_node("Bush_76")
	check(native_bush.render_variant == 2,"Native level bush uses accepted option2 automatically")
	for mat in native_bush.visual.legacy_skin.materials:
		check(mat.shader.resource_path == "res://shaders/bush_backface_cutout.gdshader","Native scenery foliage uses front-face depth cutout")
	var guard = level.get_node("Sam_51")
	guard.set_physics_process(false)
	guard.alert_level = 1; guard.relative_angle = 0
	native_player.global_position = guard.global_position+Vector3(3,0,0)
	native_player.velocity = Vector3.ZERO
	native_bush.wear(native_player)
	check(not guard.can_detect_player(),"Native Sam does not detect stationary covered Ralph")
	native_player.velocity.x = 1
	native_player.set_state(native_player.WolfState.WALK)
	check(guard.can_detect_player(),"Moving bush exposes Ralph to native Sam")
	native_bush.leave(false,false)
	var native_rock = level.get_node("Rock_44")
	check(native_rock.definition.props["0x4"] == 1 and native_rock.definition.props["0x8"] == 0 and not native_rock.definition.push_zones.is_empty(),"Native starting rock preserves X-only push and authored limits")
	stop_audio(level); level.queue_free(); await process_frame
	print("Push rocks / bush cover and eating / fan and perfume / camera fixes: ",failures," failures")
	quit(1 if failures else 0)
