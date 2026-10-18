extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var sam = level.get_node("Sam_43")
	var player = level.player
	var director = level.get_node("DaffyLessons")
	await create_timer(.25).timeout
	check(player.cinematic_controls_locked and director.movies[0].playing,"Real opening camera begins during Sam START")
	var position = sam.global_position
	await create_timer(.5).timeout
	check(sam.initialized and sam.state == sam.State.GUARD and sam.clip == "head2","Sam completes START during CIN00 and selects corrected HEAD2")
	check(sam.visual.animation_player.current_animation == "head2","Guard pose is evaluated during the camera animation")
	check(sam.visual.legacy_skin.last_matrices[15].origin.y > 1.3,"Guard hand remains at forehead rather than twisted rest pose")
	var phase = sam.head_phase
	await create_timer(.25).timeout
	check(sam.head_phase != phase and sam.global_position.distance_to(position) < .02,"Watching animates without navigation during intro")
	# Even a noisy Ralph placed close by cannot trigger Sam while the movie holds him.
	player.global_position = sam.home+Vector3(0,0,.5)
	player.current_state = player.WolfState.WALK
	player.velocity = Vector3.RIGHT
	await create_timer(.1).timeout
	check(sam.state == sam.State.GUARD,"Cinematic still suppresses detection and attacks")
	director.movies[0].finish_sequence(true)
	await process_frame
	await process_frame
	if director.active_movie: director.active_movie.finish_sequence(true)
	check(not player.cinematic_controls_locked,"Intro releases controls normally")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.queue_free()
	await process_frame
	print("Sam intro initialization / native guard pose / cinematic freeze: ",failures," failures")
	quit(1 if failures else 0)
