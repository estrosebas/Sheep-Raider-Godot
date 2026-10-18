extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func capture(camera: Camera3D, point: Vector3, offset: Vector3, path: String) -> void:
	camera.global_position = point+offset
	camera.look_at(point+Vector3.UP*.7)
	camera.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)

func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var visual = "--capture" in OS.get_cmdline_user_args()
	if visual:
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("TutorialIntro").set_process(false)
	level.get_node("CameraTraining").enabled = false
	level.get_node("TutorialProgress").set_physics_process(false)
	var player = level.get_node("Player")
	player.set_physics_process(false)
	var runner = level.get_node("RoadrunnerRace")
	runner.set_physics_process(false)
	check(not runner.actor.visible and runner.state == runner.State.WAIT,"Roadrunner starts hidden, separately from the intro actor")
	check(runner.actor.rig["animations"].has("run1"),"Road race uses original ABIPBIP RUN1")
	var run_clip = runner.actor.animation_player.get_animation("run1")
	check(run_clip.loop_mode == Animation.LOOP_LINEAR,"RUN1 interpolates through its last-to-first pose")
	player.global_position = Vector3.ZERO
	runner.advance(.016)
	check(runner.state == runner.State.WAIT,"Roadrunner does not appear outside BOX_DECL 666")
	player.global_position = TutorialProgress.center(runner.definition["trigger"])
	runner.advance(.016)
	check(runner.state == runner.State.ROAD and runner.actor.visible and runner.runs_started == 1,"Original BOX_DECL starts road chase")
	check(runner.road.speed == 1700 and runner.dust.capacity == 16,"Original first speed and trail pool")
	var cam = Camera3D.new()
	level.add_child(cam)
	if visual:
		level.get_node("HUD").hide()
		await capture(cam,runner.actor.global_position,Vector3(4,2,4),"res://validation/roadrunner_road.png")
	var entered_tunnel = false
	for i in range(2000):
		runner.advance(.016)
		if runner.road.to_index > 1 and runner.state != runner.State.WAIT:
			check(runner.road.speed == 1200,"Remaining segments use SPEED_TWO")
		if runner.state == runner.State.TUNNEL and not entered_tunnel:
			entered_tunnel = true
			check(runner.wall.rate == runner.road.rate and not runner.shadow.visible,"Last road segment starts TRAJ_WALL at road rate, removes shadow")
			if visual:
				for j in range(22): runner.advance(.016)
				await capture(cam,GameSpace.original_point(runner.wall.position),Vector3(5,2,-5),"res://validation/roadrunner_tunnel.png")
			else: runner._process(0)
			check(runner.actor.legacy_skin.materials[0].get_shader_parameter("tunnel_projection"),"Tunnel uses original screen translation/depth correction")
		if entered_tunnel and runner.state == runner.State.WAIT: break
	check(entered_tunnel and runner.state == runner.State.WAIT and not runner.actor.visible,"Roadrunner disappears and rearms after reaching tunnel end")
	check(runner.dust.spawned_total > 0,"Original road trail actually emits")
	check(not runner.actor.legacy_skin.materials[0].get_shader_parameter("tunnel_projection"),"Reset clears tunnel rendering")
	runner.advance(.016)
	check(runner.runs_started == 2,"Entering BOX_DECL can replay the run")
	player.respawned.emit()
	check(runner.state == runner.State.WAIT,"Checkpoint retry resets the race actor")
	if visual:
		var rocket = level.get_node("Rocket_77")
		player.global_position = Vector3(-99.42,9,-59.86)
		rocket.equip_to(player)
		rocket.use_item(player)
		rocket.mount_remaining = 0
		rocket.flight_time = 2
		rocket.heading = PI
		rocket.flight_speed = 8
		player.velocity = Vector3.ZERO
		rocket.flight_step(.016,Vector2(.2,.5),false)
		player.animation_player.seek(.3,true)
		player.animation_player.advance(0)
		player.legacy_skin.update_pose()
		rocket._update_held_position()
		rocket.rocket_visual.sample_animation("rocket3",.3,true)
		await capture(cam,player.global_position,Vector3(3,1,2),"res://validation/rocket_flight_original.png")
		rocket.finish_flight()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.3).timeout
	level.queue_free()
	await process_frame
	print("Original Roadrunner trigger/paths/tunnel/retry: ",failures," failures")
	quit(1 if failures else 0)
