extends SceneTree

# Offline directed shots using actual game scenes, rigs and animations.
# --script tools/capture_presentation.gd -- --shot=sam --still
# --fixed-fps 30 --script tools/capture_presentation.gd -- --shot=sam --frames
const FPS = 30
const SHOTS = {
	"ralph":"res://scenes/levels/Level00.tscn",
	"sam":"res://scenes/levels/Level01.tscn",
	"forest":"res://scenes/levels/Level02.tscn",
	"elastic":"res://scenes/levels/Level03.tscn",
	"canyon":"res://scenes/levels/Level03.tscn",
	"studio":"res://scenes/hub/Studio.tscn",
	"race":"res://scenes/levels/Level00.tscn",
	"strike":"res://scenes/levels/Level01.tscn",
	"crush":"res://scenes/levels/Level03.tscn"
}
const ACTION_DURATIONS = {"race":2.0,"strike":5.0,"crush":5.0}
var shot = "ralph"
var still = false
var frame_capture = false
var scene: Node3D
var player: RalphController
var camera: Camera3D
var target = Vector3.ZERO
var eye = Vector3.ZERO
var elastic: OriginalElasticController
var guard: OriginalSam
var pull_start = Vector3.ZERO
var duration = 7.0
var started_action = false
var runner: OriginalRoadrunner
var race_path = OriginalPathFollower.new()
var rock
var rock_trajectory: Array = []
var landing = Vector3.ZERO
var rock_impact_played = false
var camera_exclusions: Array[RID] = []

func _init():
	# Use a portrait viewport for our offscreen frame captures.
	root.size = Vector2i(720,1280)
	root.content_scale_size = Vector2i(720,1280)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg == "--still": still = true
		if arg == "--frames": frame_capture = true
	call_deferred("run")

func run():
	if not SHOTS.has(shot):
		printerr("Unknown shot: ",shot); quit(1); return
	seed(20261014)
	SaveFiles.startup_offered = true
	SaveFiles.pending = {}
	SaveFiles.directory = "user://presentation_capture_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({})
	GameLocalization.select("es",false)
	duration = float(ACTION_DURATIONS.get(shot,7.0))
	root.size = Vector2i(720,1280)
	root.content_scale_size = Vector2i(720,1280)
	scene = load(SHOTS[shot]).instantiate()
	root.add_child(scene); current_scene = scene
	player = scene.get_node("Player")
	# Stop auto tutorials before their first tick. Their actual actors stay visible.
	for name in ["TutorialIntro","CameraTraining","DaffyLessons","PorkyLessons","LevelCinematics"]:
		var manager = scene.get_node_or_null(name)
		if not manager: continue
		manager.set_process(false); manager.set_physics_process(false)
		if "movies" in manager:
			for movie in manager.movies.values():
				movie.set_process(false)
				if movie.playing: movie.finish_sequence(true)
	for i in range(20): await physics_frame
	player.set_physics_process(false); player.set_process(false)
	player.visible = true
	player.cinematic_controls_locked = false
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play_anim("idle")
	for node in scene.find_children("*","CanvasLayer",true,false): node.hide()
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	for actor in get_nodes_in_group("sam_guards"):
		actor.set_physics_process(false); actor.set_process(false)
	camera = Camera3D.new(); scene.add_child(camera)
	root.audio_listener_enable_3d = true
	camera.fov = 54; camera.near = .05; camera.far = 400
	configure_shot()
	for body in scene.find_children("*","CharacterBody3D",true,false): camera_exclusions.append(body.get_rid())
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Eight warmup frames are consistently trimmed by the assembler.
	for i in range(8):
		update_shot(0)
		await process_frame
		await RenderingServer.frame_post_draw
	print("PRESENTATION_START ",shot," frame=",Engine.get_process_frames())
	var count = 1 if still else roundi(FPS*duration)
	var frame_dir = "res://videos/ralph-wolf-demo/raw/"+shot
	if frame_capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frame_dir))
	if still and ACTION_DURATIONS.has(shot):
		for i in range(FPS*3):
			update_shot(float(i)/FPS)
			await process_frame
			await RenderingServer.frame_post_draw
	for frame in range(count):
		var time = 3.0 if still else float(frame)/FPS
		update_shot(time)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame_capture:
			var error = root.get_texture().get_image().save_png(frame_dir+"/frame_%04d.png"%frame)
			if error != OK: printerr("Could not capture frame: ",error); quit(1); return
		if frame == 0 or frame == count-1:
			root.get_texture().get_image().save_png("res://videos/ralph-wolf-demo/raw/%s_%s.png"%[shot,"start" if frame==0 else "end"])
		if ACTION_DURATIONS.has(shot) and frame in [45,75,105]:
			root.get_texture().get_image().save_png("res://videos/ralph-wolf-demo/raw/%s_%03d.png"%[shot,frame])
	print("PRESENTATION_END ",shot," frame=",Engine.get_process_frames())
	if ACTION_DURATIONS.has(shot):
		print("PRESENTATION_ACTION ",shot," started=",started_action," state=",player.current_state," death=",player.death_animation_override)
	scene.queue_free(); await process_frame
	quit()

func configure_shot():
	match shot:
		"ralph":
			player.global_position = Vector3(-95.42,4.01,-59.86)
			player.skeleton.rotation.y = PI-.35
			target = player.global_position+Vector3.UP*.95
			eye = Vector3(2.4,1.45,-4.6)
		"sam":
			guard = scene.get_node("Sam_43")
			guard.reset_guard(); guard.clip = "head2"
			player.hide()
			target = guard.home+Vector3.UP*.9
			eye = Vector3(3.7,1.35,5.7)
		"forest":
			guard = scene.get_node("Sam_51")
			guard.reset_guard(); guard.clip = "head2"
			player.hide()
			target = guard.home+Vector3.UP*.9
			eye = Vector3(-5,2.5,8)
		"elastic":
			elastic = scene.get_node("elastic_104").controller
			elastic.tree_a = scene.get_node("ElasticTree_99")
			elastic.tree_b = scene.get_node("ElasticTree_101")
			elastic.mode = "strung"; elastic.item.show(); elastic.item.original_visual.hide()
			player.global_position = (elastic.tree_a.global_position+elastic.tree_b.global_position)/2+Vector3(0,.02,-2.5)
			pull_start = player.global_position
			player.skeleton.rotation.y = 0
			elastic.wolf = player; elastic.pulling = true; elastic.mode = "pulled"
			elastic.set_physics_process(false)
			player.play_anim("elastic_pull_idle")
			target = player.global_position+Vector3.UP*.9
			eye = Vector3(2.8,2,-6.5)
		"canyon":
			player.hide()
			target = Vector3(-4,4,10)
			eye = Vector3(-1,29,60)
			camera.fov = 62
		"studio":
			target = player.global_position+Vector3(1,.95,0)
			eye = Vector3(-1.2,1.4,6.7)
			player.skeleton.rotation.y = 0
		"strike":
			guard = scene.get_node("Sam_43")
			guard.initialized = true; guard.reset_guard()
			player.global_position = guard.home+Vector3(.8,0,0)
			player.skeleton.rotation.y = -PI/2
			target = guard.home+Vector3.UP*.8
			eye = Vector3(.2,1.55,6)
		"crush":
			var environment = scene.get_node("LevelEnvironment")
			environment.set_physics_process(false)
			for board in environment.seesaws: board.set_physics_process(false)
			for body in scene.find_children("*","CharacterBody3D",true,false): body.set_physics_process(false)
			rock = scene.get_node("Rock_60")
			rock_trajectory = environment.seesaws.filter(func(board):return int(board.definition.res)==52)[0].definition.trajectories[1]
			landing = OriginalSeesaw.source_point(rock_trajectory[2])
			var query = PhysicsRayQueryParameters3D.create(landing+Vector3.UP*8,landing-Vector3.UP*10,1)
			query.exclude = [player.get_rid(),rock.get_rid()]
			var hit = player.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): landing.y = hit.position.y
			player.global_position = landing
			player.skeleton.rotation.y = .4
			rock.global_position = OriginalSeesaw.source_point(rock_trajectory[0])
			target = landing+Vector3.UP*.8
			eye = Vector3(-4,4,7)
			camera.fov = 60
		"race":
			scene.get_node("TutorialProgress").set_physics_process(false)
			runner = scene.get_node("RoadrunnerRace")
			runner.set_physics_process(false); runner.reset()
			race_path.start(runner.definition.road,player.run_speed)
			# Place Ralph in the real BOX_DECL, already on the authored road.
			for i in range(20): race_path.step(16)
			player.global_position = GameSpace.original_point(race_path.position)
			player.skeleton.rotation.y = race_path.heading
			target = player.global_position+Vector3.UP*.9
			eye = Vector3(1,3,-9)
			camera.fov = 62

func update_shot(time: float):
	if ACTION_DURATIONS.has(shot):
		update_action(time)
		return
	var progress = clampf(time/7,0,1)
	# Consistent lateral travel with a gentle push toward the subject.
	var angle = lerpf(-.1,.12,progress)
	camera.global_position = target+eye.rotated(Vector3.UP,angle)*lerpf(1.08,.92,progress)
	camera.look_at(target)
	if is_instance_valid(guard):
		guard.head_yaw = lerpf(-.7,.7,progress)
		guard._process(1.0/FPS)
	player.animation_player.advance(1.0/FPS)
	player.legacy_skin.update_pose()
	if is_instance_valid(elastic):
		player.global_position = pull_start+Vector3.FORWARD*progress*1.2
		elastic.handle = player.global_position
		elastic.tension = lerpf(.3,.65,progress)
		elastic.draw_band()

func update_action(time: float):
	var delta = 1.0/FPS
	if time>0:
		match shot:
			"strike":
				if time>=.4 and not started_action:
					guard._catch_player(); started_action = true
				if started_action:
					guard._physics_process(delta)
				guard._process(delta)
			"crush":
				if time>=.7 and not started_action:
					rock.launch(rock_trajectory); started_action = true
				if started_action:
					for i in range(2): rock._physics_process(delta/2)
					if rock.arc.is_empty() and not rock_impact_played:
						rock_impact_played = true
						if not rock.impact_sound_path.is_empty():
							rock.impact_sound.stream = load(rock.impact_sound_path); rock.impact_sound.play()
				if player.death_animation_override=="crush_death":
					player.global_position.y = minf(player.global_position.y,rock.bottom())
			"race":
				if not started_action:
					player.set_state(player.WolfState.RUN_START)
					var road_position = player.global_position
					player.global_position = TutorialProgress.center(runner.definition.trigger)
					runner.advance(0)
					player.global_position = road_position
					started_action = true
				if time>.8 and player.current_state==player.WolfState.RUN_START: player.set_state(player.WolfState.RUN)
				if time>.8: player.update_run_sound()
				race_path.step(33)
				player.global_position = GameSpace.original_point(race_path.position)
				player.skeleton.rotation.y = race_path.heading
				runner.advance(delta)
				player.run_dust.update_dust(delta,true,player.global_position,player.item_facing(),player.run_speed,player.run_speed)
				var separation = player.global_position.distance_to(runner.actor.global_position)
				target = player.global_position.lerp(runner.actor.global_position,.4 if separation<25 else 0)+Vector3.UP*.9
				eye = Vector3(1,3,-9).rotated(Vector3.UP,race_path.heading-PI)*(1+minf(.4,separation*.02))
		var previous = player.state_time
		player.state_time += delta
		player.advance_animation_sound_cues(previous,player.state_time)
		player.animation_player.advance(delta)
		player.apply_legacy_reaction_pose()
	var desired = target+eye.rotated(Vector3.UP,lerpf(-.06,.06,clampf(time/duration,0,1)))
	var query = PhysicsRayQueryParameters3D.create(target,desired,1)
	query.exclude = camera_exclusions; query.hit_back_faces = true
	var hit = scene.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired = hit.position+hit.normal*.2
	if time<=0: camera.global_position = desired
	else: camera.global_position = camera.global_position.lerp(desired,.2)
	# Recheck the smoothed path as well: interpolation must not cross a cliff.
	query.to = camera.global_position
	hit = scene.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): camera.global_position = hit.position+hit.normal*.2
	camera.look_at(target)
	camera.current = true
