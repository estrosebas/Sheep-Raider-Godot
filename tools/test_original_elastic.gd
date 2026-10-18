extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func equip(actor,item):
	actor.inventory.add_item({"id":item.item_id,"class_id":42,"label":item.item_label,"icon":item.icon_path,"kept":false},item)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://elastic_test_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await frames(12)
	# Preserve the native C++ regression independently of Level03's PC balance.
	for controller in get_nodes_in_group("elastic_controllers"):
		controller.two_anchor_max_length = controller.max_length
		controller.full_charge_threshold = 1.0; controller.minimum_launch_charge = 0.0
	var actor = lab.player; actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	var item = lab.get_node("Elastic"); var elastic = item.controller
	var a = lab.get_node("ElasticTree_A"); var b = lab.get_node("ElasticTree_B")
	actor.global_position = a.global_position+Vector3(.6,.01,0); await frames(4)
	equip(actor,item)
	check(item.holder==actor and item.class_id==42,"Elastic participates in shared inventory/equipment")
	check(a.can_interact(actor) and not b.can_interact(actor),"Native tree action radius .8m and vertical1.28m")
	check(item.use_item(actor).success,"First tie uses real PUT1A/PUT1B sequence")
	await frames(70)
	check(elastic.mode=="one" and elastic.tree_a==a and not actor.inventory.state.items.has(item.item_id),"First tie removes inventory record but retains deployed band")
	check(elastic.band.visible and not item.original_visual.visible,"Six-vertex band replaces held artwork")
	actor.global_position = b.global_position+Vector3(-.6,.01,0)
	check(b.interact(actor) and elastic.mode=="strung","Second tree ties without duplicating item")
	check(elastic.max_length==11.5 and elastic.projection_distance==50 and elastic.projection_height==5 and elastic.projection_speed==20,"Original Level03 per-item rules")
	actor.global_position = Vector3(-16,.01,-23.7); await frames(3)
	check(elastic.interact(actor) and not actor.item_actions.busy,"CTX_ELASTIC_PULL enters original DRAU1 directly")
	await frames(45)
	check(elastic.pulling and actor.animation_player.current_animation=="elastic_pull_idle","Pull idle uses extracted DRAU1 rather than empty-handed idle")
	check(not actor.inventory.can_open() and actor.can_use_item(),"Pulling prevents inventory changes while retaining E release")
	actor.camera_pivot.rotation.y = 0
	Input.action_press("move_backward"); await frames(40); Input.action_release("move_backward")
	check(actor.global_position.z>-22 and actor.animation_player.current_animation=="elastic_pull_move" and elastic.tension>0,"Actual movement stretches band using DRAU2 and native tension")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,900)
		var camera = Camera3D.new(); lab.add_child(camera)
		camera.position = Vector3(-11,3,-16); camera.look_at(Vector3(-16,1,-22)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/elastic_pull.png")
		actor.camera.current = true; camera.queue_free()
	var sheep = lab.get_node("ElasticSheep"); sheep.set_physics_process(false)
	sheep.global_position = actor.global_position+Vector3(.65,0,0)
	var origin = sheep.global_position
	check(elastic.find_launch_target(actor.global_position)==sheep,"Launch target search includes nearby sheep and excludes Ralph")
	elastic.release_pull()
	check(item.sound.stream and item.sound.stream.resource_path.ends_with("235.wav"),"Release plays recovered SND_SEAELAST235")
	check(not elastic.flight.is_empty() and actor.launch_controls_locked,"Release launches sheep and owns native aimed camera/input lock")
	await frames(15)
	check(sheep.global_position.distance_to(origin)>1 and sheep.global_position.y>origin.y+.1,"Sheep follows native sine arc in three collision substeps")
	await frames(200)
	check(elastic.flight.is_empty() and not actor.launch_controls_locked and actor.camera.current,"Projection restores camera and controls")
	# Cross the band on foot, stretch backwards, then jump to catapult Ralph.
	actor.global_position = Vector3(-16,.01,-24.15); actor.velocity = Vector3.ZERO
	actor.camera_pivot.rotation.y = 0; await frames(2)
	Input.action_press("move_backward"); await frames(42); Input.action_release("move_backward")
	check(elastic.engaged and elastic.tension>0,"Physical crossing engages band without E")
	Input.action_press("jump"); await frames(4); Input.action_release("jump")
	check(not elastic.flight.is_empty() and elastic.flight.target==actor,"Jump while stretching catapults Ralph through shared controller")
	await frames(200)
	check(elastic.flight.is_empty() and actor.elastic_motion_owner==null,"Self launch releases physics owner")
	actor.global_position = a.global_position+Vector3(.6,.01,0)
	check(a.interact(actor),"Can detach one end using native TAKE1A")
	await frames(45)
	check(elastic.mode=="one" and elastic.tree_a==b,"Detaching end retains opposite anchor")
	actor.global_position = b.global_position+Vector3(-.6,.01,0)
	check(b.interact(actor),"Can recover a singly tied elastic")
	await frames(70)
	check(elastic.mode=="item" and actor.inventory.state.items.has(item.item_id),"Recovered elastic returns to inventory through ItemFly")
	# A fall exceeding native max stretch must return to the authored destination, not die.
	var yoyo = lab.get_node("ElasticYoyo"); var ledge = lab.get_node("ElasticTree_Yoyo")
	actor.global_position = ledge.global_position+Vector3(.6,.01,0); await frames(4)
	equip(actor,yoyo); check(yoyo.use_item(actor).success,"Yo-yo fixture uses same inventory/tree action")
	await frames(70)
	actor.global_position = ledge.global_position+Vector3(4,-1,0); actor.velocity = Vector3.DOWN*8; actor.set_state(actor.WolfState.FALL)
	var retracted = false
	for i in range(270):
		await physics_frame
		if not yoyo.controller.retract.is_empty(): retracted = true
	check(retracted and actor.global_position.distance_to(Vector3(-31,14,-19))<.7 and actor.is_on_floor() and actor.current_state!=actor.WolfState.PIT_FALL,"Native max stretch /6.14m/s cosine pull-up returns Ralph onto actual platform")
	check(yoyo.controller.protects_from_void(actor),"One-end tether protects ordinary void detector")
	yoyo.restore()
	if DisplayServer.get_name()!="headless":
		actor.global_position = Vector3(-16,0,-22)
		elastic.tree_a = a; elastic.tree_b = b; elastic.mode = "strung"; item.show(); item.original_visual.hide(); elastic.draw_band()
		root.size = Vector2i(1280,900)
		var camera = Camera3D.new(); lab.add_child(camera); camera.position = Vector3(-9,6,-14)
		camera.look_at(Vector3(-16,1,-24)); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/elastic_lab.png")
	stop_audio(lab); lab.queue_free(); await process_frame
	# Verify actual authored anchors and optional checkpoint extension in Level03.
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(40)
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	var actual = level.get_node("elastic_104"); var tree = level.get_node("ElasticTree_99")
	check(actual.controller.max_length==11.5 and actual.controller.two_anchor_max_length==9.5 and actual.controller.minimum_launch_charge==1,"Level03 profile shortens two-end stretch and requires full launch while retaining reach between trees")
	check(actual is OriginalElasticItem and tree is OriginalElasticTree and get_nodes_in_group("elastic_trees").size()==4,"Level03 imports native item and all four reusable tree anchors")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_03/data/elastic.json"))
	var record = data.trees.filter(func(value): return int(value.res)==99)[0]
	check(tree.pull_up_point==GameSpace.original_point(Vector3(record.pull_up_point[0],record.pull_up_point[1],record.pull_up_point[2])),"Pull-up destination uses original BOX.min coordinates")
	actual.controller.tie_first(tree,level.player); actual.controller.tree_b = level.get_node("ElasticTree_101"); actual.controller.mode = "strung"
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint(); var snapshot = save.snapshot.duplicate(true)
	actual.controller.reset_item()
	check(save.restore_checkpoint(snapshot),"Existing checkpoint accepts elastic extension")
	check(actual.controller.mode=="strung" and actual.controller.tree_a==tree and actual.controller.tree_b==level.get_node("ElasticTree_101"),"Both authored anchors survive checkpoint restoration")
	level.player.respawned.emit()
	check(actual.controller.mode=="strung" and not actual.controller.engaged,"Native reset keeps strung band and clears rider state")
	for locale in ["en","it","pt_BR","es"]:
		GameLocalization.select(locale,false); actual.reload_localization()
		check(not actual.item_label.is_empty() and actual.controller.action_label(level.player)==GameLocalization.text("lvl_03",0,59),"Elastic retains native localized item/action strings: "+locale)
	stop_audio(level); level.queue_free(); await process_frame
	print("Original elastic / trees / yo-yo / object slingshot / self catapult / checkpoint: ",failures," failures")
	quit(failures)
