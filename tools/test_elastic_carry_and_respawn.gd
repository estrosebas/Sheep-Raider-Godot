extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://elastic_carry_test_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await frames(12)
	var actor = lab.player
	var item = lab.get_node("ElasticYoyo")
	var elastic = item.controller
	var tree = lab.get_node("ElasticTree_Yoyo")
	var sheep = lab.get_node("ElasticSheep")
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.set_physics_process(false)
	# Stand below the yo-yo ledge, with the sheep within the ordinary pickup arc.
	actor.global_position = Vector3(-31,.05,-19); actor.velocity = Vector3.DOWN
	actor.move_and_slide()
	actor.skeleton.rotation.y = 0
	sheep.global_position = actor.global_position+Vector3(0,0,.6)
	sheep.set_physics_process(false)
	item.holder = actor
	actor.inventory.add_item({"id":item.item_id,"class_id":42,"label":item.item_label,"icon":item.icon_path,"kept":true},item,false)
	elastic.tie_first(tree,actor)
	check(sheep.interact(actor),"Normal pickup action accepts sheep while singly tethered")
	await frames(100)
	check(actor.carried_sheep==sheep and elastic.interacting,"Pickup keeps attached sheep and marks the tether interaction")
	actor.set_physics_process(true)
	var returned = false
	for i in range(250):
		await physics_frame
		if not elastic.retract.is_empty(): returned = true
		if returned and elastic.retract.is_empty(): break
	check(returned,"Picking sheep below anchor-3m triggers original pull-up branch")
	check(actor.carried_sheep==sheep and actor.global_position.y>13 and actor.elastic_motion_owner==null,"Ralph returns to ledge with sheep and releases elastic motion ownership")
	await frames(8)
	check(actor.is_on_floor(),"Carrier settles on upper ledge")
	# Sam death must detach the one-ended band and insert one stored item.
	actor.set_state(actor.WolfState.SAM_DEATH)
	actor.respawn_at_checkpoint()
	check(elastic.mode=="item" and elastic.tree_a==null and not elastic.band.visible,"Sam respawn clears anchor, band and movement ownership")
	check(actor.inventory.state.items.has(item.item_id) and actor.inventory.state.count_class(42)==1,"Elastic returns once to inventory on Sam respawn")
	check(not item.available and not item.deployed and not item.visible and item.holder==null,"Returned elastic is stored, not a world pickup or held prop")
	check(actor.inventory.pickup_nodes.get(item.item_id)==item and actor.inventory.state.items[item.item_id].kept,"Inventory retains pickup identity and kept status")
	check(item.original_visual.visible,"Stored elastic restores its model for the next equip")
	elastic.on_respawn()
	check(actor.inventory.state.count_class(42)==1,"Repeated reset does not duplicate elastic")
	# A line tied between two trees stays placed after respawn (native Reset).
	var strung = lab.get_node("Elastic").controller
	strung.tie_first(lab.get_node("ElasticTree_A"),actor)
	strung.tree_b = lab.get_node("ElasticTree_B"); strung.mode = "strung"
	strung.on_respawn()
	check(strung.mode=="strung" and is_instance_valid(strung.tree_b),"Respawn preserves a line between two trees")
	lab.queue_free(); await process_frame
	# Loading a saved deployed tether must not also return it to inventory.
	var level = load("res://scenes/levels/Level05.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(10)
	var cine = level.get_node("LevelCinematics")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.set_physics_process(false)
	var saved_item = level.get_node("elastic_86")
	level.player.inventory.add_item({"id":saved_item.item_id,"class_id":42,"label":saved_item.item_label,"icon":saved_item.icon_path,"kept":true},saved_item,false)
	saved_item.controller.tie_first(level.get_node("ElasticTree_62"),level.player)
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	var record = save.snapshot.duplicate(true)
	check(save.restore_checkpoint(record),"Checkpoint with a deployed elastic loads")
	check(saved_item.controller.mode=="one" and not level.player.inventory.state.items.has(saved_item.item_id),"Checkpoint restoration keeps tether deployed without inventory duplication")
	level.player.respawn_at_checkpoint()
	check(saved_item.controller.mode=="item" and level.player.inventory.state.count_class(42)==1,"Later ordinary respawn returns the restored tether once")
	level.queue_free(); await process_frame
	print("Elastic carry and Sam respawn: ",failures," failures")
	quit(failures)
