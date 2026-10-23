extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func key(mine,direction: int,arrow = false):
	var event = InputEventKey.new(); event.pressed = true
	event.physical_keycode = ([KEY_UP,KEY_RIGHT,KEY_LEFT,KEY_DOWN] if arrow else [KEY_W,KEY_D,KEY_A,KEY_S])[direction]
	mine._input(event)
func run():
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://mine_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level06.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(45): await physics_frame
	var director = level.get_node("LevelCinematics")
	if director.active_movie: director.active_movie.finish_sequence(true)
	director.movies[0].played = true
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	var encounter = level.get_node("SamFluteEncounter")
	encounter.set_process(false)
	var sam = level.get_node("Sam_41")
	var mine = level.get_node("DefusableMine_64")
	check(get_nodes_in_group("defusable_mines").size()==11,"All eleven mines instantiate shared controller")
	check(not level.player.inventory.state.items.has("lvl_06:78"),"Fresh entry does not grant an unsolicited flute")
	var flute = level.get_node("Flute_78")
	var mailbox = level.get_node("Mailbox_54")
	var flute_record = {"id":flute.item_id,"class_id":41,"label":flute.item_label,"icon":flute.icon_path,"kept":false}
	level.player.inventory.add_item(flute_record,flute,false)
	check(not mailbox.has_pending_delivery(level.player),"Mailbox recognizes the exact flute already in inventory")
	mailbox._deliver(level.player)
	check(not mailbox.opened and mailbox.boxes.is_empty(),"Owned flute cannot produce a duplicate delivery")
	level.player.inventory.state.remove(flute.item_id)
	mailbox._deliver(level.player)
	check(mailbox.opened and mailbox.boxes.size()==1,"Missing flute is delivered once through its mailbox")
	level.player.inventory.add_item(flute_record,flute,false); flute.store()
	for entry in encounter.definition.staged_mines:
		check(not level.get_node("DefusableMine_%d"%int(entry.resource)).enabled,"Cinematic mines remain disabled before Sam encounter")
	for instance in get_nodes_in_group("defusable_mines"):
		instance.set_physics_process(false)
		var code = int(instance.mine_definition.props["0x0"])
		for index in range(instance.mine_definition.pattern.size()): check(int(instance.mine_definition.pattern[index])==((code>>(index*2))&3),"Pattern matches original native two-bit code")
	# Validate the actual native CIN2 dispatch, consumption and resulting state.
	sam.initialized = true; sam.state = sam.State.GUARD
	sam.on_flute(sam.global_position,[])
	check(encounter.pending,"Sam requests native flute cinema, rather than hypnosis")
	encounter._process(0)
	check(director.active_movie==director.movies[2] and director.movies[2].playing,"Original CIN2 starts")
	check(not level.player.inventory.state.items.has("lvl_06:78"),"Sam removes the flute before cinematic playback")
	director.movies[2].finish_sequence(false)
	check(encounter.phase_two and sam.state==sam.State.PATROL and sam.patrol_points.size()==41,"CIN2 unlocks original 41-point second patrol")
	for entry in encounter.definition.staged_mines:
		var deployed = level.get_node("DefusableMine_%d"%int(entry.resource))
		var point = entry.position
		check(deployed.enabled and deployed.visible and deployed.global_position.distance_to(GameSpace.original_point(Vector3(point[0],point[1],point[2])))<.001,"Cinematic deploys each mine at final authored position")
	sam.on_flute(sam.global_position,[]); check(not encounter.pending,"Second patrol ignores flute encounter retrigger")
	var before = sam.global_position
	level.player.cinematic_controls_locked = false; level.player.global_position = Vector3(70,20,70)
	for i in range(25): await physics_frame
	check(sam.global_position.distance_to(before)>.2,"Patrol actually moves in physics")
	# Correct sequences, including repeated directions and both keyboard layouts.
	for instance in get_nodes_in_group("defusable_mines"):
		instance.begin_defuse(level.player)
		for i in range(instance.mine_definition.pattern.size()):
			instance.clock = instance.step_start+1.05; instance.step_defuse()
			check(instance.shown_direction==int(instance.mine_definition.pattern[i]),"Playback highlights authored direction on the beat")
			instance.clock = instance.step_start+(3.5 if i==instance.mine_definition.pattern.size()-1 else 1.5); instance.step_defuse()
		check(instance.state==instance.State.INPUT,"Playback hands control back after native final pause")
		for i in range(instance.mine_definition.pattern.size()):
			instance.clock = instance.step_start+1
			key(instance,int(instance.mine_definition.pattern[i]),i%2==0)
			instance.clock = instance.step_start+1.5; instance.step_defuse()
		check(instance.state==instance.State.SAFE and not instance.session and not level.player.cinematic_controls_locked,"Full native pattern disarms and releases player")
	# Timing failures: wrong key, early input, late input, duplicate and no press.
	for mode in range(5):
		mine.reset_mine(); mine.begin_defuse(level.player); mine.set_phase(mine.State.INPUT)
		var expected = int(mine.mine_definition.pattern[0])
		mine.clock = mine.step_start+([1.0,.5,1.4,1.0,1.0][mode])
		if mode!=4: key(mine,(expected+1)%4 if mode==0 else expected)
		if mode==3: key(mine,expected)
		mine.clock = mine.step_start+1.5; mine.step_defuse()
		check(mine.state==mine.State.EXPLODING and mine.sound.playing and not mine.session,"Invalid rhythm explodes with original sound and unlocks player")
	# Joystick path emits arrow edges; holding it must not generate duplicates.
	mine.reset_mine(); mine.begin_defuse(level.player); mine.set_phase(mine.State.INPUT); mine.clock = mine.step_start+1
	var mobile = preload("res://scripts/input/mobile_controls.gd").new()
	root.add_child(mobile); mobile.set_process(false)
	mobile.context = "menu"; mobile.unit = 1; mobile.stick_origin = Vector2.ZERO
	var expected = int(mine.mine_definition.pattern[0]); var vector = [Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN][expected]*80
	mobile.update_stick(vector); Input.flush_buffered_events(); await process_frame
	check(mine.hit and not mine.failed,"Mobile joystick drives the same directional input")
	mobile.update_stick(vector); await process_frame
	check(mine.hit and not mine.failed,"Held joystick is edge-triggered")
	mobile.update_stick(Vector2.ZERO); mobile.release_all(); mobile.free(); mine.end_session()
	# Active scan -> native fuse -> BOOM -> 20s disappearance -> 5s rearm.
	mine.reset_mine(); mine.global_position = Vector3(65,20,65)
	level.player.global_position = mine.global_position
	level.player.cinematic_controls_locked = false
	mine.clock = 1.6-float(mine.mine_definition.phase_seconds)
	mine.item_step(0)
	check(mine.state==mine.State.COUNTDOWN,"Expanding active wave detects a nearby actor")
	level.player.global_position = Vector3(80,20,80)
	mine.item_step(.17); check(mine.state==mine.State.EXPLODING,"Native 0x2aa fuse triggers BOOM")
	mine.item_step(float(mine.explosion.rig.animations.boom.duration)+.01)
	check(mine.state==mine.State.EXPLODED and not mine.original_visual.visible,"Explosion completes before disappearance timer")
	mine.item_step(20.01); check(mine.state==mine.State.REARMING,"Mine returns after twenty seconds")
	mine.clock = -float(mine.mine_definition.phase_seconds)-5.1; mine.item_step(5.1)
	check(mine.state==mine.State.ARMED,"Returned mine rearms after five seconds in dormant phase")
	# Save/load phase and safe state, then respawn.
	for instance in get_nodes_in_group("defusable_mines"): instance.reset_mine()
	mine.set_phase(mine.State.SAFE)
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint(); var record = save.snapshot.duplicate(true)
	check(SaveFiles.valid(record) and record.world.controllers.SamFluteEncounter.phase_two,"Save schema retains encounter phase")
	mine.reset_mine(); check(save.restore_checkpoint(record),"Checkpoint restores optional controller states")
	check(encounter.phase_two and mine.state==mine.State.SAFE and sam.state==sam.State.PATROL,"Reload restores second patrol and disarmed mine")
	await process_frame
	check(not level.player.inventory.state.items.has("lvl_06:78"),"Respawn does not restore confiscated flute")
	if DisplayServer.get_name()!="headless":
		mine.begin_defuse(level.player); mine.clock = mine.step_start+1; mine.step_defuse()
		root.size = Vector2i(1280,720)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level06_mine_panel.png")
		mine.end_session()
	for sound in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	level.queue_free(); await process_frame
	print("Native Sam flute encounter / staged mines / patrol / patterns / rhythm / keyboard / joystick / save: ",failures," failures")
	quit(failures)
