extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func dispose(scene):
	for sound in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): sound.stop(); sound.stream = null
	scene.queue_free(); await process_frame
func open_studio():
	var scene = load(SaveFiles.STUDIO_SCENE).instantiate(); root.add_child(scene); current_scene = scene
	scene.player.restart_fade_remaining = 0; scene.player.restart_fade.set_amount(0)
	scene._process(0); scene.set_process(false); scene.arrival_movie.set_process(false)
	await physics_frame; await physics_frame
	return scene
func run():
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	SaveFiles.directory = "user://studio_arrival_test_%d"%Time.get_ticks_usec()
	SaveFiles.pending = {}; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_arrivals.clear(); SaveFiles.studio_initialized = true
	OriginalProgress.restore({})
	var seed_record = {"version":1,"level":"studio","checkpoint":{"position":[-4.62,.42,-4.55],"facing":0.0,"camera":[0,0,0]},"progress":OriginalProgress.snapshot(),"resume_checkpoint":{}}
	check(SaveFiles.write_slot(1,seed_record)==OK,"Create old save with zero extracted sheep")
	var level = Node.new(); root.add_child(level)
	OriginalProgress.complete_level("lvl_01")
	check(SaveFiles.save_level_completion(level)==OK,"New win autosaves before leaving the level")
	check(SaveFiles.studio_arrivals==["lvl_01"] and SaveFiles.read_slot(0).studio_arrivals==["lvl_01"],"Counter increase creates one persistent arrival")
	check(not SaveFiles.read_slot(1).progress.completed_levels.get("lvl_01",false),"Arrival does not overwrite manual slots")
	var scene = await open_studio()
	var movie = scene.arrival_movie
	check(movie.playing and movie.data.cine_id==0 and is_equal_approx(float(movie.data.duration),14.624),"Studio plays recovered Scene.WAR CIN0")
	check(movie.data.actors["2:15"].animation_ids["6"]=="walk3" and movie.sound_events.size()>0,"Native sheep walk, Ralph poses and sound cues are available")
	check(scene.player.cinematic_controls_locked and not scene.returned_sheep.lvl_01.visible,"Running sheep has no duplicate in the pen; player is locked")
	check(scene.panel.animation_player.current_animation=="17","Counter waits for the sheep to arrive")
	movie._process(8)
	check(movie.actors["2:15"].position.distance_to(Vector3(-3.43,0,-3.25))>5,"CIN0 moves sheep along its authored path")
	# Simulate closing/restarting halfway: the win is saved, arrival remains pending.
	await dispose(scene)
	SaveFiles.studio_initialized = false; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_arrivals.clear(); OriginalProgress.restore({})
	scene = await open_studio(); movie = scene.arrival_movie
	check(movie.playing and scene.arrival_queue==["lvl_01"],"Unfinished return survives restart from the autosave")
	movie._process(8)
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_sheep_arrival.png")
	movie._process(8)
	check(not movie.playing and not scene.player.cinematic_controls_locked and scene.player.visible,"Finishing restores gameplay and camera")
	check(scene.arrival_queue.is_empty() and scene.returned_sheep.lvl_01.visible and scene.panel.animation_player.current_animation=="16","Arrival reveals exactly one sheep and updates native counter")
	check(SaveFiles.read_slot(0).studio_arrivals.is_empty(),"Finished arrival is acknowledged on disk")
	check(SaveFiles.save_level_completion(level)==OK and SaveFiles.studio_arrivals.is_empty(),"Replaying the completed level does not queue another sheep")
	OriginalProgress.complete_level("lvl_02"); OriginalProgress.complete_level("lvl_03")
	check(SaveFiles.save_level_completion(level)==OK,"Two newly completed levels persist before studio entry")
	await dispose(scene); scene = await open_studio()
	check(scene.arrival_queue==["lvl_02","lvl_03"] and scene.panel.animation_player.current_animation=="16","Multiple pending arrivals retain the previously displayed count")
	scene.arrival_movie._process(15)
	check(scene.arrival_queue==["lvl_03"] and scene.returned_sheep.lvl_02.visible and not scene.returned_sheep.lvl_03.visible,"First arrival advances independently without revealing the next sheep")
	scene._process(0); scene.arrival_movie._process(15)
	check(scene.arrival_queue.is_empty() and scene.panel.animation_player.current_animation=="14","Second arrival completes and displays the final total")
	for i in range(OriginalProgress.TOTAL_SHEEP): OriginalProgress.complete_level("lvl_%02d"%i)
	scene.refresh_progress()
	var minimum = INF; var headings = {}; var poses = {}; var positions = {}
	for identity in scene.returned_sheep:
		var sheep = scene.returned_sheep[identity]
		check(TutorialProgress.contains(scene.source.sheep_collection_box,sheep.position),"Every sheep remains inside the native corral")
		positions[identity] = sheep.position
		headings[str(snappedf(sheep.rotation.y,.2))] = true; poses[sheep.idle_clip] = true
		for other in scene.returned_sheep.values():
			if sheep!=other: minimum = minf(minimum,sheep.position.distance_to(other.position))
	print("Corral minimum spacing: ",minimum)
	check(minimum>.8 and headings.size()>5 and poses.size()>=3,"Full flock has separation, varied headings and independent original idles")
	scene.refresh_progress()
	for identity in positions: check(scene.returned_sheep[identity].position==positions[identity],"Refreshing UI does not reshuffle the corral")
	if DisplayServer.get_name()!="headless":
		var view = Camera3D.new(); scene.add_child(view)
		view.position = Vector3(-9,6,-4); view.look_at(Vector3(-15.5,.3,-10)); view.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/studio_corral_layout.png")
	await dispose(scene)
	SaveFiles.studio_initialized = false; SaveFiles.resume_checkpoint = {}; SaveFiles.studio_arrivals.clear(); OriginalProgress.restore({})
	scene = await open_studio()
	check(not scene.arrival_movie.playing and scene.arrival_queue.is_empty(),"Later studio visits do not replay acknowledged arrivals")
	await dispose(scene); level.queue_free(); await process_frame
	print("Studio native sheep return / saved delta / restart / replay / corral layout: ",failures," failures")
	quit(failures)
