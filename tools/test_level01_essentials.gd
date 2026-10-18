extends SceneTree
var failures = 0
func _init() -> void: call_deferred("run_tests")
func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		printerr(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func clean(scene) -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
func run_tests() -> void:
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	level.get_node("DaffyLessons").movies[0].played = true
	await frames(110)
	var player = level.get_node("Player")
	var sheep_count = 0
	for child in level.get_children():
		if child is OriginalSheep:
			sheep_count += 1
			check(child.is_on_floor(),"Original Sheep is grounded: "+child.name)
	check(sheep_count == 17,"All 17 original flock Sheep receive runtime physics")
	var sam = level.get_node("Sam_43")
	check(sam is OriginalSam and sam.is_on_floor() and sam.clip == "head2","Sam is initialized on floor with original lookout HEAD2, not RUN2")
	check(not level.has_node("Goal_115"),"Original invisible Goal trigger is not rendered as white sphere")
	for entity in level.entities:
		if int(entity["class_id"]) in ImportedLevel.LOGIC_CLASSES:
			var name = "%s_%d" % [entity["class_name"],int(entity["res"])]
			check(not level.has_node(name) and not level.get_node("OriginalObjectCollisions").has_node(name),"Logical manager is neither visible marker nor phantom solid: "+name)
	var scrolling = level.get_node("TextureScroll")
	scrolling.set_process(false)
	scrolling.ticks = 0
	scrolling.advance_rows(1)
	for region in scrolling.regions:
		var page = scrolling.pages[int(region["page"])]
		var r = region["rect"]
		var expected_row = posmod(-int(region["step"]),int(r[3]))
		check(page["image"].get_pixel(r[0],r[1]) == page["source"].get_pixel(r[0],r[1]+expected_row),"TexScroll respects original row direction inside each atlas rectangle")
		check(page["image"].get_pixel(255,255) == page["source"].get_pixel(255,255),"Scrolling leaves unrelated texture texels unchanged")
	var spray_count = 0
	for child in level.get_children():
		if child is OriginalSpriteEmitter:
			check(child.emitted_total > 0,"Water spray actually emits original sprites")
			spray_count += 1
	check(spray_count == 2,"Both recovered tall water surfaces have spray")
	var mailbox = level.get_node("Mailbox_61")
	var dynamite = level.get_node("Dynamite_70")
	var note = level.get_node("SignPostSimple_66")
	check(mailbox.items.size() == 2 and not dynamite.available and not note.available and not note.visible,"Source mailbox hides dynamite and note before delivery")
	player.global_position = mailbox.global_position+Vector3(0,0,1)
	player.velocity = Vector3.ZERO
	player.skeleton.rotation.y = PI
	await frames(40)
	print("Mailbox approach: player=",player.position," mailbox=",mailbox.position," interact=",mailbox.can_interact(player))
	check(mailbox.can_interact(player) and mailbox.interact(player),"Level01 mailbox uses original grounded/facing interaction and LETTER1A")
	await frames(220)
	check(dynamite.available and note.available and mailbox.opened and not player.cinematic_controls_locked,"Generated boxes land, OPEN1 releases both source contents and controls return")
	player.global_position = dynamite.global_position.lerp(note.global_position,.4)
	player.velocity = Vector3.ZERO
	await frames(30)
	check(player.global_position.distance_to(note.global_position) < note.read_distance and dynamite.can_pickup(player),"Fixture overlaps shortened sign radius and dynamite pickup radius")
	check(not note.can_interact(player),"Delivered note no longer intercepts E beside dynamite")
	player.inventory.interact_or_use()
	check(player.item_actions.busy and not note.opened,"Shared E dispatcher selects dynamite pickup rather than adjacent sign")
	await frames(85)
	check(player.inventory.state.count_class(2) == 1,"Dynamite arrives in shared inventory")
	player.inventory.state.select_class(2)
	player.inventory.equipped_id = dynamite.item_id
	player.inventory.equipped.emit(player.inventory.state.get_selected_object())
	check(dynamite.actor_visual.animation_player.current_animation == "link","Held dynamite uses original LINK animation")
	check(player.inventory.use_selected(),"R uses original PUT1A/B to plant and light dynamite")
	await frames(48)
	print("Planted dynamite: ",dynamite.state," fuse=",dynamite.fuse," sound=",dynamite.sound.playing," sparks=",dynamite.sparks.emitted_total)
	check(dynamite.state == "lit" and dynamite.fuse > 4 and dynamite.fuse < 5 and player.inventory.state.count_class(2) == 0,"Planting consumes inventory and starts original five-second fuse")
	await frames(10)
	check(dynamite.sparks.emitted_total > 0 and dynamite.sound.playing,"Original fuse sprites and positional loop actually play")
	var rocks = level.get_node("Rocks_68")
	dynamite.global_position = rocks.global_position+Vector3(1,0,0)
	player.global_position = Vector3(8.91,.15,12.73)
	player.velocity = Vector3.ZERO
	await frames(460)
	print("After blast: ",dynamite.state," rocks broken=",rocks.broken," visible=",rocks.visible," dynamite pos=",dynamite.global_position)
	check(rocks.broken and not rocks.visible,"Original three-metre explosion damages Rocks and completes BOOM01")
	check(dynamite.state == "respawn" and not dynamite.visible,"Original AEXPLOS1 BOOM completes before respawn wait")
	await frames(180)
	check(dynamite.available and dynamite.state == "idle" and dynamite.global_position.is_equal_approx(dynamite.home_position),"Spent dynamite returns to delivery location after explosion plus three seconds")
	check(player.inventory.state.count_class(2) == 0,"Respawned dynamite must be recollected, not auto-granted")
	clean(level)
	level.queue_free()
	await process_frame
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	await frames(10)
	var actor = lab.get_node("Player")
	check(lab.has_node("Item_2") and lab.has_node("Telescope") and lab.has_node("BlastRocks"),"Missing Level01 objects are available in laboratory")
	actor.global_position = lab.get_node("Telescope").global_position+Vector3(0,0,1)
	actor.velocity = Vector3.ZERO
	await frames(20)
	var telescope = lab.get_node("Telescope")
	check(telescope.interact(actor) and telescope.camera.current and actor.cinematic_controls_locked,"Lab telescope opens original zoomed camera and freezes Ralph")
	check(telescope.ui.visible and telescope.camera.fov < 15,"Original DAV telescope mask accompanies original focal length")
	check(telescope.camera.global_position.is_equal_approx(telescope.global_transform*telescope.optical_anchor),"Telescope camera is anchored inside the instrument, not 12m behind/above")
	var eye = telescope.camera.global_position
	Input.action_press("move_right")
	telescope._process(.1)
	Input.action_release("move_right")
	check(telescope.camera.global_position.is_equal_approx(eye) and not actor.visible,"Steering keeps optical position fixed and hides Ralph during telescope view")
	var use = InputEventAction.new()
	use.action = "action"
	use.pressed = true
	Input.parse_input_event(use)
	await frames(3)
	var release = InputEventAction.new()
	release.action = "action"
	release.pressed = false
	Input.parse_input_event(release)
	check(not telescope.viewing and not telescope.ui.visible,"Actual E input closes telescope once without reopening from inventory dispatcher")
	check(not actor.cinematic_controls_locked and actor.camera.current,"Leaving telescope restores previous camera and controls")
	check(actor.visible,"Leaving telescope restores Ralph's visibility")
	var bomb = lab.get_node("Item_2")
	bomb.ignite(actor.global_position)
	bomb.explode()
	print("Lab blast: player=",actor.global_position," bomb=",bomb.global_position," state=",actor.current_state," player group=",actor.is_in_group("player"))
	check(actor.current_state == actor.WolfState.BLAST_DEATH and actor.animation_player.current_animation == "blast_death","Nearby dynamite uses original Ralph EXPLOS1 death, not pit STRIKE2")
	clean(lab)
	await create_timer(.3).timeout
	lab.queue_free()
	await process_frame
	print("Level01 flock/water/mailbox/dynamite/rocks/telescope: ",failures," failures")
	quit(1 if failures else 0)
