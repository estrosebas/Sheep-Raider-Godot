extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value,message):
	if not value: failures += 1; printerr(message)
func run():
	GameLocalization.config_path = "res://validation/startup_language_test.cfg"
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true
	SaveFiles.directory = "user://studio_startup_test_%d"%Time.get_ticks_usec()
	SaveFiles.studio_initialized = false; SaveFiles.resume_checkpoint = {}; OriginalProgress.restore({})
	var service = root.get_node_or_null("LanguageMenu")
	if not service:
		service = load("res://scripts/localization/language_menu.gd").new()
		service.name = "LanguageMenu"
		root.add_child(service)
	var wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	root.add_child(wheel)
	current_scene = wheel
	check(service.transition.overlay.color.a > .99,"Startup fades from black")
	await create_timer(1.1,true).timeout
	check(not service.transitioning and service.transition.overlay.color.a == 0,"Startup reveal completes")
	await wheel.confirm()
	await create_timer(2.2,true).timeout
	check(current_scene.scene_file_path == SaveFiles.STUDIO_SCENE,"Startup confirm reaches original studio beneath fade")
	check(not service.transitioning and service.transition.overlay.color.a == 0,"Exit fade releases new scene")
	for node in current_scene.find_children("*","AudioStreamPlayer",true,false)+current_scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.queue_free()
	await process_frame
	print("Language startup entry / exit fade: ",failures," failures")
	quit(1 if failures else 0)
