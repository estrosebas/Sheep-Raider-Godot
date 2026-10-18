extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	SaveFiles.studio_initialized = true
	SaveFiles.directory = "user://mouse_test_%d" % Time.get_ticks_usec()
	SaveFiles.pending = {}
	GameLocalization.select("es",false)
	var lab = load(SaveFiles.STUDIO_SCENE).instantiate()
	root.add_child(lab); current_scene = lab
	await create_timer(.2).timeout
	var player = lab.player
	player.set_physics_process(false)
	player.restart_fade_remaining = 0
	var rotation = player.camera_pivot.rotation
	# Simulate a browser rejecting startup capture or releasing pointer lock:
	# desired mode stays true, but the actual OS/browser mode is visible.
	player.mouse_captured = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var motion = InputEventMouseMotion.new(); motion.relative = Vector2(50,15)
	player._unhandled_input(motion)
	check(player.camera_pivot.rotation == rotation,"Visible cursor must not rotate the gameplay camera")
	var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	player._unhandled_input(click)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"Click retries capture even when desired state was already true")
	player._unhandled_input(motion)
	check(player.camera_pivot.rotation != rotation,"Captured cursor drives camera")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player._unhandled_input(click)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"Click reacquires capture after external release")
	var menu = lab.get_node("PauseMenu")
	menu.open_menu()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and paused,"Pause releases cursor")
	menu.close_menu()
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused,"Desktop resume restores captured cursor")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.queue_free(); await process_frame
	print("Mouse capture / browser-release recovery / camera / pause: ",failures," failures")
	quit(failures)
