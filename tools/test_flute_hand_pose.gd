extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://flute_pose_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	var player = lab.player; player.set_physics_process(false); player.set_process(false)
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.global_position = Vector3(0,.01,4); player.skeleton.rotation = Vector3.ZERO
	var flute = lab.get_node("Item_41"); flute.set_physics_process(false)
	flute.equip_to(player); player.inventory.equipped_node = flute
	var native_length = Vector3(-.1888,-.105,-.4688).distance_to(Vector3(.0612,.05,.09))
	var camera = Camera3D.new(); lab.add_child(camera); camera.global_position = player.global_position+Vector3(2,1.1,2)
	camera.look_at(player.global_position+Vector3.UP); camera.make_current(); root.size = Vector2i(1280,720)
	for clip in ["held_item_idle","flute_idle","flute_walk","flute_fidget"]:
		flute.active = clip in ["flute_idle","flute_walk"]
		player.set_state(player.WolfState.FLUTE_WALK if clip=="flute_walk" else player.WolfState.FLUTE_IDLE if flute.active else player.WolfState.IDLE)
		player.play_anim(clip)
		for at in [.0,.35,.6]:
			player.animation_player.seek(at,true); player.animation_player.advance(0); player.apply_legacy_reaction_pose()
			flute._update_held_position(); flute.item_step(0)
			check(flute.original_visual.animation_player.current_animation=="link","Held flute keeps native LINK during "+clip)
			check(flute.original_visual.skeleton.get_bone_pose_scale(1).is_equal_approx(Vector3.ONE),"No extra flute squash/stretch during "+clip)
			check(flute.original_visual.skeleton.get_bone_pose_rotation(1).is_equal_approx(Quaternion.IDENTITY),"No second flute rotation over hand during "+clip)
			var hand = player.skeleton.global_transform*player.legacy_skin.last_matrices[18]
			check(flute.global_position.distance_to(hand.origin)<.0001,"Flute pivot follows native hand18 exactly")
			var expected_basis = hand.basis*GameSpace.EXPORT_TO_GODOT
			check(flute.global_basis.is_equal_approx(expected_basis),"Flute uses native wrist orientation, without guessed offset")
			var end_a = flute.global_transform*Vector3(-.1888,-.105,-.4688)
			var end_b = flute.global_transform*Vector3(.0612,.05,.09)
			check(absf(end_a.distance_to(end_b)-native_length)<.0001,"Rigid prop retains dimensions during "+clip)
			if DisplayServer.get_name()!="headless":
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://validation/flute_%s_%02d.png"%[clip,int(at*100)])
	# A render-pose update must move the held item immediately, with no item
	# physics tick in between (regression for the one-frame hand lag).
	player.play_anim("flute_idle"); player.animation_player.seek(.2,true); player.animation_player.advance(0)
	player.apply_legacy_reaction_pose(); var before = flute.global_position
	player.animation_player.seek(.6,true); player.animation_player.advance(0); player.apply_legacy_reaction_pose()
	check(flute.global_position.distance_to(before)>.05,"Prop updates on the displayed hand pose without waiting for physics")
	check(flute.global_transform.is_equal_approx(flute.attachment_transform(player)),"Displayed hand and prop attachment are synchronized")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame; print("Flute hand pose: ",failures," failures"); quit(failures)
