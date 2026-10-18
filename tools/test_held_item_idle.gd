extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://held_idle_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.2).timeout
	var actor = lab.player; actor.set_physics_process(false); actor.set_process(false)
	actor.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.global_position = Vector3.ZERO; actor.skeleton.rotation = Vector3.ZERO
	actor.restart_fade_remaining = 0; actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	actor.inventory.animate_selection = false
	var lettuce = lab.get_node("Item_3")
	actor.inventory.add_item({"id":lettuce.item_id,"class_id":3,"label":"Lechuga","icon":lettuce.icon_path,"kept":false},lettuce)
	actor._process(0)
	check(actor.animation_player.current_animation=="held_item_idle" and actor.run_data.animations.held_item_idle.original_name=="stand10","Equipping lettuce uses native STAND10 rather than empty-handed idle")
	actor.animation_player.seek(.3,true); actor.animation_player.advance(0); actor.apply_legacy_reaction_pose(); lettuce._update_held_position()
	var hand = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[18]
	check(lettuce.global_position.distance_to(hand.origin)<.001,"Salad attaches to original hand18 with no invented offset")
	var basis = hand.basis*GameSpace.EXPORT_TO_GODOT
	check(lettuce.global_basis.x.distance_to(basis.x)<.001 and lettuce.global_basis.y.distance_to(basis.y)<.001,"Lettuce LINK preserves the native wrist orientation")
	check(lettuce.original_visual.animation_player.current_animation=="link" and lettuce.original_visual.position.y==0,"Held lettuce uses LINK and removes planted visual offset")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,900)
		var camera = Camera3D.new(); lab.add_child(camera)
		camera.position = Vector3(2,1.4,3); camera.look_at(Vector3(0,.85,0)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/lettuce_original_hand_idle.png")
	var idle = actor.original_idle
	idle.loops_remaining = 0; idle.elapsed = 0; idle.step(actor,.86)
	check(idle.clip=="held_item_fidget" and actor.run_data.animations[idle.clip].original_name=="stand9","Native item idle interleaves one STAND9 fidget")
	idle.step(actor,.81)
	check(idle.clip=="held_item_idle" and idle.loops_remaining in range(5),"Fidget returns to STAND10 for native random0..4 loops")
	actor.set_state(actor.WolfState.WALK); actor.set_state(actor.WolfState.IDLE)
	check(actor.animation_player.current_animation=="held_item_idle","Stopping after movement returns directly to held-item idle")
	check(actor.item_actions.begin([{"clip":"throw_end"}]),"Existing object action still starts while holding lettuce")
	actor.item_actions._process(1)
	check(not actor.item_actions.busy and actor.animation_player.current_animation=="held_item_idle","Finishing an object action restores correct held idle immediately")
	for kind in [2,7,39,66]:
		lettuce.store()
		var item = lab.get_node("Item_%d"%kind)
		actor.inventory.equipped_node = item; item.equip_to(actor)
		actor.original_idle.reset(actor)
		check(actor.animation_player.current_animation=="held_item_idle","Shared native held idle applies to item class%d"%kind)
		item.store()
	var rocket = lab.get_node("Item_10"); actor.inventory.equipped_node = rocket; rocket.equip_to(actor)
	idle.reset(actor); idle.step(actor,5)
	check(idle.clip=="rocket_idle" and actor.run_data.animations[idle.clip].original_name=="rocket1","Back-mounted rocket keeps native ROCKET1 rather than hand pose or item fidget")
	rocket.store(); actor.inventory.equipped_node = null
	actor._process(0)
	check(actor.animation_player.current_animation=="idle","Empty hands recover normal STAND0 and its variants")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame
	print("Original held STAND10 / STAND9 / lettuce LINK / item transitions / ROCKET1: ",failures," failures")
	quit(failures)
