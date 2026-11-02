extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://mine_lifecycle_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level07.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(50): await physics_frame
	var player = level.player; player.set_physics_process(false)
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false); player.cinematic_controls_locked = false; player.restart_fade_remaining = 0
	for actor in get_nodes_in_group("sam_guards")+get_nodes_in_group("sheep_targets")+get_nodes_in_group("buried_minefields"): actor.set_physics_process(false)
	var mine = level.get_node("DefusableMine_73"); mine.set_physics_process(false)
	var origin = mine.reset_position
	player.global_position = Vector3(254,252,-225); player.set_state(player.WolfState.IDLE)
	player.velocity = Vector3.DOWN
	for i in range(25): player.move_and_slide(); await physics_frame
	mine.equip_to(player)
	check(mine.use_item(player).success,"Safe mine can be placed through actual held-item action")
	while player.item_actions.busy: await physics_frame
	check(mine.state==mine.State.REARMING and mine.global_position.distance_to(origin)>5,"Placed mine has a separate current position")
	check(mine.reset_position.is_equal_approx(origin),"Placement preserves native saved origin")
	player.global_position = Vector3(100,280,-300); player.cinematic_controls_locked = false
	mine.set_phase(mine.State.ARMED); mine.explode()
	check(not mine.available,"Exploding mine is unavailable for interaction")
	mine.item_step(float(mine.explosion.rig.animations.boom.duration)+.01)
	check(mine.state==mine.State.EXPLODED and not mine.original_visual.visible,"Explosion enters invisible spent phase")
	var placed = mine.global_position
	for i in range(10): mine.on_blast(placed); mine.item_step(1)
	check(mine.state==mine.State.EXPLODED and not mine.explosion.visible,"Repeated blasts do not retrigger hidden spent mine")
	var saved = mine.capture_world_state(); mine.reset_mine(); mine.restore_world_state(saved)
	check(mine.state==mine.State.EXPLODED and not mine.available and not mine.original_visual.visible,"Save/load preserves spent state without another explosion")
	mine.item_step(10.1)
	check(mine.state==mine.State.REARMING and mine.global_position.is_equal_approx(origin) and mine.visible and mine.original_visual.visible,"After20s mine visibly returns to native origin, not placed location")
	mine.clock = -float(mine.mine_definition.phase_seconds)-5.1; mine.item_step(5.1)
	check(mine.state==mine.State.ARMED,"Returned mine rearms normally")
	mine.store(); mine.on_blast(origin); mine.item_step(5)
	check(mine.state==mine.State.ARMED and not mine.visible,"Stored mine cannot acquire an invisible fuse")
	mine.reset_mine(); mine.set_phase(mine.State.SAFE); mine.on_blast(origin)
	check(mine.state==mine.State.SAFE,"Native blast handler ignores safe mine")
	for audio in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): audio.stop(); audio.stream = null
	level.queue_free(); await process_frame
	print("Mine placement / spent state / visibility / native respawn / persistence: ",failures," failures")
	quit(failures)
