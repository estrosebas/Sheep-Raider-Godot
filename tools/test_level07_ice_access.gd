extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://ice_access_%d"%Time.get_ticks_usec()
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level07.tscn").instantiate(); root.add_child(level); current_scene = level
	for i in range(50): await physics_frame
	var player = level.player; var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	cine.set_process(false); player.cinematic_controls_locked = false; player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	player.set_physics_process(false)
	for npc in get_nodes_in_group("sam_guards")+get_nodes_in_group("sheep_targets")+get_nodes_in_group("buried_minefields"): npc.set_physics_process(false)
	var cube = level.get_node("SlidingIceCube_33")
	var start = cube.global_position
	player.global_position = start+Vector3(-1.14,.15,2.2); player.set_state(player.WolfState.IDLE)
	var access = level.get_node("IceAccess")
	for i in range(110):
		access._physics_process(1.0/60)
		player.velocity = Vector3(0,-2,-2.5); player.move_and_slide()
		await physics_frame
		if player.global_position.z<start.z-1.45: break
	print("native narrow passage player=",player.global_position," cube=",start)
	check(player.global_position.z<start.z-1.35,"Ralph walks through the actual narrow rear passage beside cube33")
	check(is_equal_approx(player.get_node("CollisionShape3D").shape.radius,.18),"Native36cm solid width applies locally")
	check(cube.can_interact(player),"Player can initiate push from the far side")
	check(cube.interact(player),"Ice interaction begins")
	check(player.animation_player.current_animation=="ice_push_start","Dedicated native ICEPUSH1 pose plays")
	var elapsed = 0.0
	while player.item_actions.busy and elapsed<2:
		await physics_frame; elapsed += 1.0/60
	check(cube.global_position.z>start.z+1 and cube.speed>0,"Completing ICEPUSH1 starts cube slide in requested direction")
	check(player.animation_player.has_animation("ice_push_end"),"Native ICEPUSH2 recovery exists")
	player.global_position = Vector3(254,252,-225); access._physics_process(.016)
	check(is_equal_approx(player.get_node("CollisionShape3D").shape.radius,.35),"Normal capsule width restored away from ice")
	for audio in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): audio.stop(); audio.stream = null
	level.queue_free(); await process_frame
	print("Level07 native narrow ice passage / dedicated push states: ",failures," failures")
	quit(failures)
