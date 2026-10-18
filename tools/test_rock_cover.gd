extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_scene(scene):
	Input.action_release("sneak"); Input.action_release("move_forward"); Input.action_release("move_left")
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.queue_free(); await process_frame
func settle(actor,rock):
	actor.interrupt_actions(); actor.camera_pivot.rotation = Vector3.ZERO
	actor.global_position = rock.global_position+Vector3(0,.02,1.0)
	await create_timer(.2).timeout
func run():
	SaveFiles.startup_offered = true; SaveFiles.studio_initialized = true; SaveFiles.pending = {}; SaveFiles.directory = "user://cover_test_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.4).timeout
	var actor = lab.player; var rock = lab.get_node("CoverRock_0")
	check(actor.animation_player.has_animation("cover_enter") and actor.animation_player.has_animation("cover_hidden") and actor.run_data.animations.cover_enter.original_name=="hide1" and actor.run_data.animations.cover_hidden.original_name=="hide2","Native HIDE1/HIDE2 exported into shared Ralph animation bank")
	check(actor.animation_player.get_animation("cover_hidden").loop_mode==Animation.LOOP_LINEAR,"Hidden pose repeats native HIDE2")
	await settle(actor,rock)
	check(not actor.rock_cover.active(),"Touching cover without Ctrl does not hide")
	Input.action_press("sneak"); Input.action_press("move_forward")
	await create_timer(.1).timeout
	check(actor.current_state==actor.WolfState.COVER_ENTER and actor.rock_cover.rock==rock,"Ctrl toward native rock enters cover at the original edge gap")
	Input.action_release("move_forward")
	await create_timer(1.1).timeout
	check(actor.current_state==actor.WolfState.COVER_HIDDEN and actor.animation_player.current_animation=="cover_hidden","Entry finishes in native hidden loop without moving or idle takeover")
	check(not actor.sneak_audio_player.playing,"Stationary hidden pose does not play tiptoe steps")
	check(actor.hidden_from_observer(rock.global_position-Vector3(0,0,3)) and not actor.hidden_from_observer(rock.global_position+Vector3(0,0,3)),"Original half-space hides opposite-side observers but preserves same-side visibility")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); lab.add_child(camera); camera.position = rock.global_position+Vector3(2.3,1.6,3.5); camera.look_at(rock.global_position+Vector3.UP*.6); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/rock_cover_lab.png")
	Input.action_press("move_left")
	await create_timer(.1).timeout
	check(actor.current_state==actor.WolfState.SNEAK and not actor.rock_cover.active() and Vector2(actor.velocity.x,actor.velocity.z).length()<=actor.sneak_speed+.01,"Leaving sideways with Ctrl resumes quiet SNEAK immediately")
	Input.action_release("move_left"); Input.action_release("sneak")
	await settle(actor,rock)
	Input.action_press("sneak"); await create_timer(.2).timeout
	check(actor.rock_cover.active(),"Ctrl while stopped next to rock also enters cover")
	Input.action_release("sneak"); await create_timer(.1).timeout
	check(not actor.rock_cover.active(),"Releasing Ctrl cancels cover")
	await stop_scene(lab)
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	var cinematics = level.get_node("LevelCinematics"); if cinematics.active_movie: cinematics.active_movie.finish_sequence(true)
	cinematics.set_process(false)
	var lessons = level.get_node("DaffyLessons"); lessons.set_process(false)
	var sam = level.get_node("Sam_63"); sam.set_physics_process(false)
	actor = level.player; actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	rock = level.get_node("HiddenRocks_81")
	check(get_nodes_in_group("rock_cover").size()==8,"All eight native cover rocks are active in level03")
	await settle(actor,rock)
	Input.action_press("sneak"); await create_timer(1.2).timeout
	sam.global_position = rock.global_position-Vector3(0,0,3); sam.state = sam.State.GUARD; sam.alert_level = 1; sam.relative_angle = 0
	lessons.daffy.global_position = sam.global_position; lessons.daffy.rotation.y = 0; lessons.head_yaw = 0
	check(actor.rock_cover.active() and not sam.can_detect_player() and lessons.detect_player()==0,"Real Sam and Lucas cones cannot detect native rock-hidden Ralph")
	sam.global_position = rock.global_position+Vector3(0,0,3); sam.relative_angle = 0
	lessons.daffy.global_position = sam.global_position; lessons.daffy.rotation.y = PI
	check(sam.can_detect_player() and lessons.detect_player()==6,"Both observers can detect Ralph after moving to his exposed side")
	actor.interrupt_actions()
	check(not actor.rock_cover.active() and actor.current_state==actor.WolfState.IDLE,"Cinematics/item actions cancel cover cleanly")
	await stop_scene(level)
	print("Shared rock cover / native animations / Ctrl entry-exit / lab / level03 / Sam-Lucas visibility: ",failures," failures")
	quit(failures)
