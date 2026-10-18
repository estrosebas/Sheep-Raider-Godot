extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://dynamite_lift03_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(20)
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var actor = level.player; actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	check(not actor.has_node("ElasticTuning"),"Suprimir development menu and HUD are no longer instantiated")
	var event = InputEventKey.new(); event.pressed = true; event.physical_keycode = KEY_DELETE
	Input.parse_input_event(event); await process_frame
	check(not paused and actor.mouse_captured,"Delete no longer opens debug overlay or pauses gameplay")
	var bomb = level.get_node("Dynamite_107"); var lift = level.get_node("Wooden Lift_56")
	var button = level.get_node("SensibleButton_54"); button.set_physics_process(false)
	var shape = lift.find_children("*","CollisionShape3D",false,false)[0]
	var surface = lift.global_position.y+shape.position.y+shape.shape.size.y*.5
	actor.global_position = Vector3(lift.global_position.x,surface+.02,lift.global_position.z)
	actor.velocity = Vector3.DOWN; actor.set_state(actor.WolfState.FALL)
	for i in range(30):
		await physics_frame
		if actor.is_on_floor(): break
	actor.inventory.add_item({"id":bomb.item_id,"class_id":2,"label":bomb.item_label,"icon":bomb.icon_path,"kept":false},bomb)
	check(actor.is_on_floor() and bomb.use_item(actor).success,"Real PUT1A/PUT1B starts placing dynamite on native lift56")
	# Raise during PUT1A, to catch stale placement probes as well as cargo tracking.
	lift.set_switch(button,true)
	await frames(48)
	check(bomb.state=="lit" and not bomb.available and bomb.deployed,"Bomb remains lit/non-pickable after placement")
	var follower = bomb.get_node_or_null("MovingSupport")
	check(follower and follower.support==lift,"Lit bomb is registered as moving lift cargo")
	actor.global_position = Vector3(15,0,3)
	actor.velocity = Vector3.ZERO
	var offset = lift.to_local(bomb.global_position)
	var previous_fuse = bomb.fuse; var start_y = bomb.position.y
	lift.set_switch(button,false)
	await frames(35)
	check(bomb.position.y<start_y-.5 and bomb.global_position.distance_to(lift.to_global(offset))<.03,"Bomb descends with native platform and retains local position")
	lift.set_switch(button,true); await frames(60)
	check(absf(lift.position.y-lift.on_y)<.01 and bomb.global_position.distance_to(lift.to_global(offset))<.03,"Bomb rises with platform to authored upper endpoint")
	check(bomb.fuse<previous_fuse and bomb.fuse>0 and bomb.fuse_seconds==5,"Following support neither resets nor extends the original5s fuse")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = lift.global_position+Vector3(-.25,1.4,.6)
		camera.look_at(bomb.global_position+Vector3.UP*.2); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level03_dynamite_lift.png")
	var explosions: Array = []
	bomb.exploded.connect(func(point): explosions.append(point))
	# Detonate during motion: the damage origin must be this tick's cargo position.
	lift.set_switch(button,false); bomb.fuse = .04
	await frames(4)
	check(explosions.size()==1 and absf(explosions[0].y-bomb.global_position.y)<.15 and explosions[0].y>3,"Blast origin follows elevated moving platform rather than old placement height")
	for i in range(600):
		await physics_frame
		if bomb.state=="idle" and not bomb.has_node("MovingSupport"): break
	check(bomb.state=="idle" and not bomb.has_node("MovingSupport") and bomb.available,"Respawn removes stale support and restores ordinary item state")
	# Direct/container release also discovers ground support; not just use_item.
	actor.global_position = Vector3(15,0,3)
	lift.set_switch(button,false); await frames(70)
	surface = lift.global_position.y+shape.position.y+shape.shape.size.y*.5
	bomb.ignite(Vector3(lift.global_position.x,surface,lift.global_position.z))
	await frames(3); lift.set_switch(button,true); await frames(30)
	check(bomb.get_node("MovingSupport").support==lift and bomb.position.y>surface+.5,"Lit items created without an explicit support also acquire the lift via floor probe")
	bomb.restore(); await frames(2)
	stop_audio(level); level.queue_free(); await process_frame
	print("Level03 dynamite / placement on moving lift / rise+descent / blast position / cleanup / disabled debug HUD: ",failures," failures")
	quit(failures)
