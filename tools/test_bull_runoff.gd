extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_scripts(node: Node):
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): stop_scripts(child)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://bull_runoff_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(30): await physics_frame
	var cine = level.get_node("LevelCinematics")
	for movie in cine.movies.values():
		if movie.playing: movie.finish_sequence(true)
	stop_scripts(level)
	var player = level.player
	player.cinematic_controls_locked = false
	player.current_state = player.WolfState.FALL
	var bull = level.get_node("bull_60")
	var elastic = level.get_node("elastic_86").controller
	player.global_position = Vector3(35,-1,-28)
	bull.global_position = Vector3(32.4,4,-28)
	bull._set_state(bull.State.CHARGE,"run2")
	check(not bull.can_follow_over_edge(),"Carrying an unconnected elastic must not authorize runoff")
	bull._physics_process(1.0/60)
	check(bull.state==bull.State.RETURN_HOME,"Leaving the authored movement region normally returns home")
	elastic.tie_first(level.get_node("ElasticTree_71"),player)
	check(bull.can_follow_over_edge(),"One-ended tether inside native noReturnBox authorizes pursuit")
	player.global_position = Vector3(30,-1,-28)
	check(not bull.can_follow_over_edge(),"An attached elastic does not authorize runoff at other cliffs")
	player.global_position = Vector3(35,-1,-28)
	var boxes = bull.definition.no_return_boxes
	bull.definition.no_return_boxes = []
	check(not bull.can_follow_over_edge(),"Levels without a native noReturnBox retain ordinary boundaries")
	bull.definition.no_return_boxes = boxes
	bull.global_position = Vector3(32.4,4,-28)
	bull._set_state(bull.State.CHARGE,"run2")
	bull._physics_process(1.0/60)
	check(bull.state==bull.State.CHARGE,"Bull continues toward the rim instead of returning as soon as Ralph leaves")
	for i in range(180):
		bull._physics_process(1.0/60)
		if bull.state!=bull.State.CHARGE: break
	check(bull.state==bull.State.ESCAPE,"Charging across the actual Level05 rim enters native ESCAPE")
	check(bull.clip=="fall" and bull.velocity.is_equal_approx(Vector3(2,-10,0)),"Native FALL uses quarter horizontal speed and 10 m/s downward")
	bull._process(.1)
	check(bull.clip_time>0,"Escape advances the original FALL animation")
	check(bull.charge_sound.playing and bull.charge_sound.stream.resource_path.is_empty(),"Native sound 202 is playing as a duplicated loop")
	var before = bull.global_position
	player.cinematic_controls_locked = true
	bull._physics_process(.1)
	check(bull.global_position.is_equal_approx(before+Vector3(.2,-1,0)),"Falling uses direct translation even if Ralph's controls lock")
	bull.reset_to_home()
	check(bull.state==bull.State.ESCAPE and bull.global_position.distance_to(bull.home)>1,"Native Reset does not bring an escaping bull home")
	for i in range(240):
		bull._physics_process(1.0/60)
		if bull.escaped: break
	check(bull.escaped and not bull.visible and bull.collision_layer==0 and not bull.charge_sound.playing,"Leaving noReturnBox removes visual/collision/audio")
	player.respawned.emit()
	check(bull.escaped and not bull.visible,"Ordinary Ralph respawn does not resurrect the defeated bull")
	level.queue_free(); await process_frame
	print("Bull original runoff: ",failures," failures")
	quit(failures)
