extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	seed(97231)
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await create_timer(.2).timeout
	var flock = level.get_node("Flock")
	level.player.set_physics_process(false)
	level.get_node("Sam_43").set_physics_process(false)
	flock.set_physics_process(false)
	var times = {}
	var speeds = {}
	for sheep in flock.sheep:
		sheep.set_physics_process(false)
		sheep.visual.set_process(false)
		sheep.begin_random_idle(true)
		times[snappedf(sheep.visual.idle_time,.01)] = true
		speeds[sheep.visual.idle_speed] = true
		check(sheep.idle_loops >= 5 and sheep.idle_loops <= 10,"Native initial idle-loop range")
	check(times.size() > 3 and speeds.size() > 2,"Sheep start with independent phases and native speeds")
	var actors_seen = {}
	var peak = 0
	for tick in range(800):
		flock._physics_process(.1)
		var active = 0
		for sheep in flock.sheep:
			sheep._physics_process(.1)
			sheep.visual.idle_time += .1*sheep.visual.idle_speed
			if sheep.visual.idle_clip in ["stand4","bah"] and not sheep.sleepy:
				active += 1
				actors_seen[sheep] = true
		peak = maxi(peak,active)
	check(peak == 1,"At most one ambient variant at a time throughout 80 seconds")
	check(actors_seen.size() >= 3,"Different sheep receive ambient variants over time")
	# Interrupt the owner with carrying; another sheep must not remain blocked.
	var owner = flock.idle_variant_owner
	if is_instance_valid(owner):
		owner.carried_by = level.player
		var other = flock.sheep[0] if flock.sheep[0] != owner else flock.sheep[1]
		check(flock.claim_idle_variant(other),"Interrupted owner releases the ambient slot")
		owner.carried_by = null
		flock.release_idle_variant(other)
	for sheep in flock.sheep: sheep.reset_to_home()
	check(flock.idle_variant_owner == null,"Checkpoint reset clears ambient ownership")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Sheep independent phases / speeds / single ambient owner: ",failures," failures; peak=",peak," distinct sheep=",actors_seen.size())
	quit(1 if failures else 0)
