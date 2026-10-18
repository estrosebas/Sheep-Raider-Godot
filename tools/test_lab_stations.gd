extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value, message):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true
	SaveFiles.directory = "user://lab_stations_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await create_timer(.3).timeout
	var player = lab.player
	player.set_physics_process(false)
	check(player.inventory.allow_world_placement,"Lab allows placing lettuce")
	for i in range(5):
		var door = lab.get_node("LevelDoor_%02d" % i)
		check(door.position.x == 20 and ResourceLoader.exists(door.level_scene),"Doors are on the side and retain their level destinations")
		check(not door.sequential_progress and door.is_unlocked(),"Laboratory doors remain unlocked for development tests")
		var label = lab.get_node("DoorFloorLabel_%02d" % i)
		check(label.text == "NIVEL %02d" % i and label.position.y < .1 and is_equal_approx(label.rotation.x,-PI/2),"Door names lie on the floor")
	var sheep = lab.get_node("LettuceSheep")
	var supply = lab.get_node("LettuceSupply_0")
	check(supply.original_visual != null and supply.available,"Supply uses original lettuce visual")
	check(sheep.global_position.distance_to(supply.global_position) > ItemRules.LETTUCE_RADIUS,"Supply is outside sheep attraction until placed")
	# Exercise actual pickup/use animation and safe placement, then sheep following.
	player.global_position = Vector3(14,.01,-11)
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	player.skeleton.rotation.y = PI
	player.inventory.animate_selection = false
	player.inventory.add_item({"id":supply.item_id,"class_id":3,"label":"Lechuga","icon":supply.icon_path,"kept":false},supply)
	await process_frame
	check(supply.holder == player,"Lab supply can be equipped")
	check(player.inventory.use_selected(),"Lab lettuce starts original placement animation")
	player.item_actions.set_process(false)
	for i in range(4):
		if player.item_actions.busy: player.item_actions._process(10)
	check(supply.deployed and supply.available and supply.holder == null,"Lettuce safely placed in lab")
	var distance = sheep.global_position.distance_to(supply.global_position)
	await create_timer(1.0).timeout
	check(sheep.global_position.distance_to(supply.global_position) < distance,"Sheep follows placed lettuce")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/music/catalog.json"))
	var music = lab.get_node("MusicPreview")
	check(catalog.tracks.size() == 13,"Catalog includes all thirteen original PC music files")
	for i in range(13):
		var pad = lab.get_node("MusicPad_%02d" % i)
		pad._on_body_entered(sheep)
		pad._on_body_entered(player)
		check(music.selected.get("id","") == pad.track.id,"Player selects native track by entering pad")
		check(music.stream.loop_begin == 0 and music.stream.loop_end == int(pad.track.end_sample),"Native full-file loop uses exact source sample end")
		check(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Selected track loops")
	var segment = catalog.tracks[0].duplicate(true)
	segment.start_time = .1
	segment.loop_start = .2
	segment.end_time = .4
	segment.erase("end_sample")
	check(music.play_segment(segment),"Segment player accepts a subsection of the same asset")
	check(music.stream.loop_begin == 3200 and music.stream.loop_end == 6400,"Subsection loops only its configured start and end")
	segment.end_time = .15
	check(not music.play_segment(segment),"Invalid interval is rejected without replacing playback")
	lab.get_node("MusicPad_13")._on_body_entered(player)
	check(not music.playing and music.selected.is_empty(),"Stop pad stops preview")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new()
		lab.add_child(camera)
		camera.position = Vector3(3,43,37)
		camera.look_at(Vector3(0,0,1))
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/lab_stations.png")
		camera.position = Vector3(-18,13,26)
		camera.look_at(Vector3(-18,0,12))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/lab_music_pads.png")
	for node in lab.find_children("*","AudioStreamPlayer",true,false)+lab.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.queue_free()
	await process_frame
	print("Lab stations / original music segments: ",failures," failures")
	quit(1 if failures else 0)
