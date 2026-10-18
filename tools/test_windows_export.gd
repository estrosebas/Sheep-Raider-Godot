extends SceneTree

var failures = 0

func _init(): call_deferred("run")

func check(ok: bool, message: String):
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func run():
	SaveFiles.startup_offered = true
	SaveFiles.pending = {}
	SaveFiles.directory = "user://export_test_%d" % Time.get_ticks_usec()
	GameLocalization.config_path = SaveFiles.directory+"/language.cfg"
	OriginalProgress.restore({})
	GameLocalization.select("es",false)
	check(not GameLocalization.manifest.is_empty(),"Packed localization JSON")
	for locale in ["es","en","it","pt_BR"]:
		GameLocalization.select(locale,false)
		check(not GameLocalization.text("lvl_03",79,1).is_empty(),"Packed texts: "+locale)
		check(GameLocalization.voice_path(9).contains("/voices/"+locale+"/") and ResourceLoader.exists(GameLocalization.voice_path(9)),"Packed voices: "+locale)
	GameLocalization.select("es",false)
	for path in ["res://scenes/startup/LanguageWheel.tscn","res://scenes/hub/Studio.tscn","res://scenes/levels/Level00.tscn","res://scenes/levels/Level01.tscn","res://scenes/levels/Level02.tscn","res://scenes/levels/Level03.tscn","res://scenes/testing/ItemLab.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		current_scene = scene
		await create_timer(.3).timeout
		for scroll in scene.find_children("*","OriginalTextureScroll",true,false):
			check(not scroll.pages.is_empty(),"Packed scrolling texture: "+path)
		var music = scene.get_node_or_null("BGMPlayer")
		if music != null:
			check(music.stream != null and music.playing,"Packed music: "+path)
		print("Loaded from export: ",path)
		for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
			node.stop()
			node.stream = null
		scene.queue_free()
		await process_frame
		await process_frame
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/catalog.json"))
	if catalog is Dictionary:
		var player = OriginalMusicSegment.new()
		root.add_child(player)
		for track in catalog.tracks:
			check(player.play_segment(track),"Packed music segment")
		player.stop_selection()
		player.queue_free()
	print("Windows packed-resource smoke test: ",failures," failures")
	quit(failures)
