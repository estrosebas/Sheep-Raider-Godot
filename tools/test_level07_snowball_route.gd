extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://ball_route_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level07.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(50): await physics_frame
	var player = level.player; player.set_physics_process(false)
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false); player.cinematic_controls_locked = false; player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	for actor in get_nodes_in_group("sam_guards")+get_nodes_in_group("sheep_targets")+get_nodes_in_group("buried_minefields"): actor.set_physics_process(false)
	var ball = level.get_node("Snowball_63"); var initial = ball.global_position
	for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.FORWARD]:
		player.global_position = ball.global_position-direction*(ball.radius+.4)+Vector3(.06,0,.04)
		var ray = PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*2,player.global_position-Vector3.UP*4,1)
		ray.exclude = [player.get_rid(),ball.get_rid()]
		var hit = level.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): player.global_position.y = hit.position.y+.02
		player.set_state(player.WolfState.IDLE); player.velocity = Vector3.DOWN; player.move_and_slide()
		player.ground_distance = 0; player.last_ground_y = player.global_position.y; player.jump_origin_y = null
		check(ball.can_interact(player) and ball.interact(player),"Can re-engage actual snowball from next side of L route")
		while player.item_actions.busy: await physics_frame
		check(ball.push_direction==direction,"Native axis snapping removes small approach errors")
		Input.action_press("action")
		var before = ball.global_position
		for i in range(240 if direction==Vector3.RIGHT else (140 if direction==Vector3.BACK else 35)):
			ball.step_pusher(player,1.0/60); await physics_frame
		Input.action_release("action"); ball.stop_push(false)
		check((ball.global_position-before).dot(direction)>.5,"Ball moves on each segment, including reverse after growth")
		print("route ",direction," => ",ball.global_position," radius=",ball.radius)
		if direction==Vector3.RIGHT: check(ball.global_position.x>257 and absf(ball.global_position.z-initial.z)<.1,"First narrow native corridor reaches its L bend without diagonal drift")
		if direction==Vector3.BACK:
			check(ball.global_position.z>-224,"Second native corridor reaches the costume area")
			check(Vector2(ball.global_position.x-259.59,ball.global_position.z+222.4).length()<3,"Ball can be brought beside native sheep costume delivery")
	check(ball.radius>.8,"Native route grows the snowball while moving")
	for audio in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): audio.stop(); audio.stream = null
	level.queue_free(); await process_frame
	print("Level07 actual snowball L route / corner / costume / reverse: ",failures," failures")
	quit(failures)
