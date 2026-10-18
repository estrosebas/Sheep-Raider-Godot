extends SceneTree

var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run_tests() -> void:
	SaveFiles.startup_offered = true # Ignore player save startup UI in this fixture.
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	var mailbox = level.get_node("Mailbox_54")
	var rocket = level.get_node("Rocket_77")
	var training = level.get_node("CameraTraining")
	training.enabled = false
	level.get_node("TutorialIntro").set_process(false)
	check(not rocket.available and not rocket.visible,"Mailbox hides its original export-518 content before order")
	check(mailbox.items.size() == 1 and mailbox.items[0] == rocket,"Recovered export resolves original Rocket 77")
	player.global_position = mailbox.global_position+Vector3(0,0,1)
	player.skeleton.rotation.y = PI
	await frames(12)
	print("Mailbox origin=",mailbox.global_position," player=",player.global_position," boxes=",mailbox.definition["boxes"])
	check(mailbox.can_interact(player),"Source box-gap/facing scan allows adjacent grounded Ralph")
	player.skeleton.rotation.y = 0
	check(not mailbox.can_interact(player),"Mailbox rejects Ralph facing away")
	player.skeleton.rotation.y = PI
	check(mailbox.interact(player),"Action begins original LETTER1A")
	check(player.item_actions.busy and not player.can_use_inventory(),"Delivery action blocks run/jump/inventory")
	check(not mailbox.opened,"MSG_USE waits for the hit animation")
	await frames(38)
	check(mailbox.opened and mailbox.boxes.size() == 1,"End of LETTER1A dispatches one delivery")
	check(not mailbox.interact(player),"Cannot order twice")
	var box = mailbox.boxes[0]
	var high = box.global_position.y
	await frames(50)
	check(not is_instance_valid(box) or box.global_position.y < high,"Delivery box descends against real world collision")
	await frames(150)
	check(rocket.available and rocket.visible,"Landing releases the original item")
	check(not player.item_actions.busy and player.camera.current,"Delivery restores player camera and input")
	print("Released Rocket position=",rocket.global_position)
	player.global_position = rocket.global_position+Vector3(0,0,0.7)
	await frames(12)
	check(rocket.collect(player.inventory),"E pickup starts original TAKE1A")
	check(not player.inventory.state.items.has(rocket.item_id),"Object is not added before pickup completes")
	await frames(10)
	player.interrupt_actions()
	check(rocket.available and rocket.visible and not player.item_actions.busy,"Interrupted TAKE1A restores the loose item without adding it")
	check(rocket.collect(player.inventory),"Interrupted pickup can be retried")
	await frames(70)
	check(player.inventory.state.items.has(rocket.item_id) and not rocket.visible and rocket.holder == null,"TAKE1B flies item into inventory, then removes it from world")
	check(player.inventory.open_wheel(),"Stored Rocket can be selected with Tab")
	player.inventory.state.select_class(10)
	player.inventory.close_wheel()
	await frames(36)
	check(rocket.visible and rocket.holder == player,"TAKE4 equips Rocket after reverse inventory flight")
	rocket._update_held_position()
	check(rocket.global_transform.is_equal_approx(rocket.attachment_transform(player)),"Rocket follows original back joint 3 and carry offset")
	check(rocket.global_position.distance_to(player.item_hand_position()) > 0.2,"Rocket is attached to back rather than hand")
	rocket.fuel = 1
	player.inventory.open_wheel()
	player.inventory.close_wheel()
	await frames(45)
	check(not rocket.visible and rocket.holder == null and player.inventory.state.items.has(rocket.item_id),"Choosing empty hands plays PUT4, flies the item away and keeps inventory contents")
	check(rocket.fuel == rocket.fuel_seconds,"MSG_INVENTORY_STORED refills the original Rocket")
	player.inventory.open_wheel()
	player.inventory.state.select_class(10)
	player.inventory.close_wheel()
	await frames(36)
	check(player.inventory.use_selected(),"Equipped Rocket starts original mount sequence")
	check(player.animation_player.current_animation == "rocket_mount","ROCKET0 precedes ignition on the ground")
	await frames(80)
	check(player.animation_player.current_animation == "rocket_ride" and rocket.active,"ROCKET2 transitions into ROCKET3 flight")
	player.interrupt_actions()
	check(player.active_rocket == null and not rocket.active,"Dialogue interrupts Rocket flight and audio")
	player.respawn_at_checkpoint()
	await frames(1)
	check(not mailbox.opened and not rocket.available and not rocket.visible,"Uncommitted order rolls back to closed mailbox without loose content")
	# A committed mailbox stays delivered, even if the released item is still on ground.
	mailbox._deliver(player)
	await frames(180)
	mailbox.commit()
	mailbox.rollback()
	check(mailbox.opened and rocket.available,"Checkpoint preserves a delivered mailbox")
	mailbox._release_camera()
	training._enter_stage(16)
	player.global_position = TutorialProgress.center(training.data["slots"][16]["box"])
	training._stage_reached()
	check("buzón" in " ".join(training.dialogue_pages) and int(training.data["slots"][16]["voice_id"]) == 85,"Mailbox lesson uses source trigger and voice 85 across automatic subtitle pages")
	training._show_dialogue(17)
	check("Tab" in " ".join(training.dialogue_pages) and int(training.data["slots"][17]["voice_id"]) == 86,"Rocket lesson uses original voice 86 and PC controls")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(0.3).timeout
	level.queue_free()
	await process_frame
	print("Mailbox/item animation: ",failures," failures")
	quit(1 if failures else 0)
