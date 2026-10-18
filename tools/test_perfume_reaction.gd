extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func fixture(path: String):
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var scene = load(path).instantiate(); root.add_child(scene); current_scene = scene
	await create_timer(.3).timeout
	var player = scene.get_node("Player"); player.set_physics_process(false); player.set_process(false)
	for child in scene.get_children():
		if child is OriginalSheep or child is OriginalSam or child.name in ["Flock","DaffyLessons","LevelEnvironment"]: child.set_physics_process(false); child.set_process(false)
	player.cinematic_controls_locked = false
	return scene
func clean(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.process_mode = Node.PROCESS_MODE_DISABLED; scene.queue_free(); await process_frame
func run():
	for laboratory in [false,true]:
		var scene = await fixture("res://scenes/testing/ItemLab.tscn" if laboratory else "res://scenes/levels/Level02.tscn")
		var player = scene.get_node("Player")
		var sheep = scene.get_node("Sheep") if laboratory else scene.get_node("Flock").sheep[0]
		var perfume = scene.get_node("Item_39") if laboratory else scene.get_node("Mailbox_67").items[0]
		var fan = scene.get_node("Item_7") if laboratory else scene.get_node("Mailbox_66").items[0]
		perfume.set_physics_process(false); fan.set_physics_process(false)
		perfume.global_position = sheep.global_position-Vector3(0,0,5 if laboratory else 10); perfume.active = true; perfume.deployed = true; perfume.available = true; perfume.show()
		player.global_position = perfume.global_position-Vector3(0,0,2); player.skeleton.rotation = Vector3.ZERO
		fan.equip_to(player); fan.active = true; player.inventory.equipped_node = fan
		for i in range(100): perfume.item_step(.05)
		if not laboratory:
			scene.get_node("Flock")._physics_process(.016)
			sheep = scene.get_node("Flock").reservations.get(perfume)
		check(sheep!=null,"Level scent selects an eligible nearest sheep")
		if sheep == null: await clean(scene); continue
		var before: Vector3 = sheep.global_position
		var clips = {}; var feedback = false
		var hud: OriginalLettucePrompt
		for child in player.get_node("ActionPrompt").get_children():
			if child is OriginalLettucePrompt: hud = child
		for i in range(240):
			perfume.item_step(.05)
			sheep._physics_process(.05)
			clips[sheep.visual.idle_clip] = true
			hud._process(.05)
			feedback = feedback or (hud.visible and hud.result.get("sheep",false))
			await physics_frame
		check(clips.has("stand2") and clips.has("smel1") and clips.has("walk2"),"Perfume runs original turn/sniff/hopping clips in "+("lab" if laboratory else "level"))
		check(sheep.global_position.distance_to(before)>.5,"Perfume produces real sheep movement")
		check(feedback,"Blowing fan displays the original sheep crayon HUD after detection")
		check(not sheep.sheep_audio.playing,"Perfume never starts lettuce eating audio")
		fan.active = false; perfume.item_step(.6); hud._process(.6)
		check(fan.detection_report().is_empty() and not hud.visible,"Fan report and HUD disappear when blowing stops")
		await clean(scene)
	print("Original perfume sheep animation / feedback / lab: ",failures," failures"); quit(failures)
