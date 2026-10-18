extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://sneak_idle_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab=load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene=lab
	await create_timer(.6).timeout
	var player=lab.player
	Input.action_press("sneak"); await create_timer(.2).timeout
	check(player.current_state==player.WolfState.SNEAK and player.animation_player.current_animation=="sneak_idle","Holding sneak while stationary uses STAND11 and preserves stealth state")
	check(is_equal_approx(player.animation_player.get_animation("sneak_idle").length,2.46) and player.animation_player.get_animation("sneak_idle").loop_mode==Animation.LOOP_LINEAR,"Original 2.46s idle loops")
	check(player.sneak_step_count==0 and not player.sneak_audio_player.playing,"Stationary stealth has no steps")
	if DisplayServer.get_name()!="headless":
		var camera=Camera3D.new(); lab.add_child(camera); camera.make_current()
		camera.global_position=player.global_position+Vector3(3,1.5,4); camera.look_at(player.global_position+Vector3.UP*.9)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/sneak_idle.png")
	Input.action_press("move_right"); await create_timer(.35).timeout
	check(player.animation_player.current_animation=="sneak","Moving in stealth uses moving animation")
	Input.action_release("move_right"); await create_timer(.15).timeout
	var steps=player.sneak_step_count
	check(player.animation_player.current_animation=="sneak_idle","Stopping returns to native stealth idle")
	await create_timer(.3).timeout
	check(player.sneak_step_count==steps,"Pausing does not add or reset the quiet-step sequence")
	Input.action_release("sneak"); await create_timer(.1).timeout
	check(player.current_state==player.WolfState.IDLE and player.animation_player.current_animation!="sneak_idle","Releasing sneak returns to normal idle")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
	lab.queue_free(); await process_frame
	print("Native STAND11 / stationary stealth / moving stealth / silent rest / release: ",failures," failures")
	quit(failures)
