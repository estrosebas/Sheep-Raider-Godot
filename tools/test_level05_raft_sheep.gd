extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func ticks(count: int):
	for i in range(count): await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://raft_sheep05_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({})
	var level = load("res://scenes/levels/Level05.tscn").instantiate(); root.add_child(level); current_scene = level
	await ticks(10)
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false)
	var player = level.player
	player.set_physics_process(false); player.cinematic_controls_locked = false
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	player.global_position = Vector3(4,1,5)
	level.get_node("Sam_56").set_physics_process(false)
	level.get_node("bull_60").set_physics_process(false)
	for lure in get_nodes_in_group("sheep_attractors"): lure.remove_from_group("sheep_attractors")
	var raft = level.get_node("Raft_49")
	# Use the wide native channel so a bank cannot stop the transport fixture.
	raft.global_position = Vector3(-56.5,-.81,-25)
	raft.reset_motion()
	var sheep = level.get_node("Flock").sheep[0]
	sheep.reset_to_home()
	var original_home = sheep.home
	var floor_layers = sheep.platform_floor_layers
	var leave_mode = sheep.platform_on_leave
	sheep.global_position = raft.global_position+Vector3(.15,raft.deck.end.y+.005,.15)
	sheep.velocity = Vector3.ZERO; sheep.call_time = 0
	sheep.flock_target = null; sheep.flock_phase = "idle"; sheep.flock_timer = 0
	# The native current moves this ferry while Ralph works the shore buttons.
	var environment = level.get_node("LevelEnvironment")
	var zone = environment.water_at(raft.global_position)
	check(not zone.is_empty(),"Original raft49 starts inside a native water region")
	zone.flags = 0x20000000 # +source Z, 200u/s; no Wolf/fan needed.
	await ticks(5)
	var start = raft.global_position
	var relative = sheep.global_position-raft.global_position
	var left_deck = false
	var largest_drift = 0.0
	for i in range(180):
		player.cinematic_controls_locked = i>=45 and i<105
		await physics_frame
		left_deck = left_deck or not raft.is_rider(sheep)
		largest_drift = maxf(largest_drift,(sheep.global_position-raft.global_position-relative).length())
	print("Sheep-only raft travel: ",raft.global_position-start," largest relative drift: ",largest_drift," sheep phase: ",sheep.flock_phase)
	player.cinematic_controls_locked = false
	check(raft.global_position.distance_to(start)>1,"Current moves raft with only sheep aboard")
	check(not left_deck and largest_drift<.08,"Physics-active sheep rides once without drift, food or Ralph aboard")
	check(raft.rider_count==1 and sheep.moving_anchor==raft,"Occupancy and moving anchor count the lone sheep")
	check(sheep.home==original_home and not is_instance_valid(sheep.flock_target),"No invented food target or checkpoint-home movement")
	check(sheep.platform_floor_layers==0,"Explicit raft transport disables automatic duplicate carrying")
	# When stopped, the sheep must remain on deck for more than its idle timer.
	for entry in environment.rules.water: entry.flags = 0
	raft.reset_motion()
	await ticks(240)
	check(raft.is_rider(sheep) and sheep.moving_anchor==raft,"Sheep stays aboard after ferry stops, without lettuce")
	sheep.global_position.x = raft.global_position.x+.9
	await ticks(60)
	var centered = sheep.global_position-raft.global_position; centered.y = 0
	check(centered.length()<=.55 and raft.is_rider(sheep),"Without lures sheep returns within native half-metre anchor radius, not to its old flock")
	# Walking/carrying off restores ordinary platform behavior on land.
	sheep.global_position = player.global_position
	await ticks(2)
	check(sheep.moving_anchor==null,"Leaving raft releases moving anchor")
	check(sheep.platform_floor_layers==floor_layers and sheep.platform_on_leave==leave_mode,"Leaving raft restores ordinary moving floor behavior")
	level.queue_free(); await process_frame
	print("Level05 lone sheep ferry: ",failures," failures")
	quit(failures)
