extends SceneTree
const Controls = preload("res://scripts/input/platform_controls.gd")
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func key(code: Key, pressed: bool) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code; event.pressed = pressed
	return event
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://web_controls_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab); current_scene = lab
	await create_timer(.4).timeout
	check(Controls.key_label("sneak")=="Ctrl","Desktop retains Ctrl")
	Controls.configure_web()
	check(InputMap.event_is_action(key(KEY_C,true),"sneak") and not InputMap.event_is_action(key(KEY_CTRL,true),"sneak"),"Web uses C and removes Ctrl binding")
	check(OriginalLevelDialogue.clean("$B_SNEAK$")=="C","Tutorial displays actual platform binding")
	Input.parse_input_event(key(KEY_C,true))
	Input.action_press("move_forward")
	await physics_frame; await physics_frame; await physics_frame
	check(Input.is_action_pressed("sneak") and lab.player.current_state==lab.player.WolfState.SNEAK,"C plus forward actually enters Ralph sneak state")
	Input.parse_input_event(key(KEY_C,false)); Input.action_release("move_forward")
	await physics_frame
	check(not Input.is_action_pressed("sneak"),"Releasing C stops sneak")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame
	InputMap.load_from_project_settings()
	check(Controls.key_label("sneak")=="Ctrl","Project defaults remain Ctrl for native exports")
	print("Platform sneak bindings / actual movement / tutorial hints: ",failures," failures")
	quit(failures)
