extends SceneTree
func _init(): call_deferred("run")
func run():
	var controls=root.get_node("MobileControls");controls.set_enabled(true)
	var gate=load("res://scenes/startup/UpdateGate.tscn").instantiate()
	root.add_child(gate);current_scene=gate
	await create_timer(.15).timeout
	var point=root.get_final_transform()*gate.play.get_global_rect().get_center()
	var touch=InputEventScreenTouch.new();touch.index=0;touch.position=point;touch.pressed=true
	Input.parse_input_event(touch);Input.flush_buffered_events()
	await process_frame
	touch=InputEventScreenTouch.new();touch.index=0;touch.position=point;touch.pressed=false
	Input.parse_input_event(touch);Input.flush_buffered_events()
	await create_timer(.2).timeout
	var failures=0
	if not current_scene is OriginalLanguageWheel:
		failures+=1;printerr("Touch Play must bypass the game overlay and open the language wheel")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/update_gate_touch.png")
	if is_instance_valid(current_scene):
		for node in current_scene.find_children("*","AudioStreamPlayer",true,false):node.stop();node.stream=null
	print("Native updater touch Play / game HUD bypass: ",failures," failures")
	quit(failures)
