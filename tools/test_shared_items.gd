extends SceneTree

const Catalog = preload("res://scripts/items/item_catalog.gd")
const Rules = preload("res://scripts/items/item_rules.gd")
var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func select(inventory: Node, kind: int) -> void:
	inventory.state.select_class(kind)
	var item = inventory.state.get_selected_object()
	inventory.equipped_id = str(item.get("id", ""))
	inventory.equipped.emit(item)

func collect_fixture(item: GameItem, inventory: Node) -> bool:
	# Each item's use is exercised here; full pickup presentation is tested in test_mailbox.
	item.owning_inventory = inventory
	return inventory.add_item({"id":item.item_id,"class_id":item.class_id,"label":item.item_label,"icon":item.icon_path,"kept":item.kept},item)

func run_tests() -> void:
	check(is_equal_approx(Rules.magnet_strength(0.6), 6.0), "Original magnet curve is strongest at 60u")
	check(is_zero_approx(Rules.magnet_strength(0.4)) and is_zero_approx(Rules.magnet_strength(4.1)), "Magnet inner dead zone and 400u range")
	check(Rules.in_fan_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -3.9)), "Fan hits within original 4m cone")
	check(not Rules.in_fan_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(3, 0, 0)), "Fan rejects sideways target")
	check(not Rules.in_fan_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -4.1)), "Fan rejects out-of-range target")
	check(is_equal_approx(Rules.perfume_distance(Rules.PERFUME_BLOW_MAX), 19.99951171875), "Original perfume wind buildup cap")
	check(is_equal_approx(Rules.rocket_fuel_step(3.0, true, 0.5), 2.0), "Boost burns fuel twice as fast")

	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var player = lab.get_node("Player")
	player.set_physics_process(false)
	for i in range(3):
		await physics_frame
		player._physics_process(1.0/60)
	player.capture_mouse(false)
	player.position = Vector3(0, 0.02, 0)
	player.skeleton.rotation.y = 0.0
	player.animation_player.advance(0.01)
	player.apply_legacy_reaction_pose()
	var inv = player.inventory
	for node in lab.get_children():
		if node is GameItem:
			node.set_physics_process(false)
	check(inv.open_wheel() and inv.wheel_open, "Empty inventory opens with a visible cloud")
	await process_frame
	check(inv.wheel_open and player.inventory_controls_locked, "Empty wheel stays open and locks player")
	inv.close_wheel()
	check(not player.inventory_controls_locked, "Empty wheel release restores control")
	check(player.item_facing().is_equal_approx(Vector3.BACK), "Items follow corrected positive-Z character facing")

	var magnet = lab.get_node("Item_66")
	check(collect_fixture(magnet,inv), "Collect reusable magnet")
	check(magnet.active and magnet.holder == player, "Selected magnet activates in the hand")
	var drop_event = InputEventAction.new()
	drop_event.action = "drop_item"
	drop_event.pressed = true
	inv._input(drop_event)
	check(magnet.holder == player and inv.state.items.has(magnet.item_id) and not magnet.deployed,"Disabled generic drop cannot remove equipped items even when placement is allowed")
	magnet._update_held_position()
	var target = lab.get_node("Metal_0")
	target.global_position = magnet.global_position + Vector3.FORWARD * 1.0
	magnet.item_step(0.1)
	check(target in magnet.caught and magnet.caught.size() <= 4, "Magnet accepts magnetic targets and caps list at four")
	var initial_velocity = target.linear_velocity
	magnet.item_step(0.1)
	await physics_frame
	check(not target.linear_velocity.is_zero_approx() or not initial_velocity.is_zero_approx(), "Movable metal receives attraction impulse")

	var perfume = lab.get_node("Item_39")
	check(collect_fixture(perfume,inv), "Collect shared perfume")
	check(not magnet.active and magnet.caught.is_empty(), "Changing selected item releases magnetic targets")
	check(inv.use_selected(), "Perfume starts original placement")
	player.item_actions.set_process(false)
	for i in range(6):
		if player.item_actions.busy: player.item_actions._process(10)
	check(perfume.active and perfume.deployed and not inv.state.items.has(perfume.item_id), "Perfume places on ground and becomes an independent scent source")
	var fan = lab.get_node("Item_7")
	check(collect_fixture(fan,inv), "Collect shared fan")
	check(inv.use_selected() and fan.active, "Fan action starts blowing")
	fan._update_held_position()
	perfume.global_position = fan.global_position + player.item_facing() * 1.2
	perfume.global_position.y = 0.02
	for step in range(4):
		fan.item_step(0.25)
		perfume.item_step(0.25)
	check(perfume.blow_time > 0.0 and perfume.can_smell_from(perfume.global_position+player.item_facing()*3), "Fan extends scent reach downwind toward the bottle")
	var buildup = perfume.blow_time
	check(inv.use_selected() and not fan.active and not fan.sound.playing, "Fan toggles off and releases its audio")
	perfume.item_step(0.5)
	check(perfume.blow_time < buildup, "Perfume wind decays after fan stops")

	var lettuce = lab.get_node("Item_3")
	check(collect_fixture(lettuce,inv) and inv.use_selected(), "Lettuce places through generic item use")
	for i in range(6):
		if player.item_actions.busy: player.item_actions._process(10)
	check(lettuce.scent_strength() == 6.0, "Placed lettuce attracts within original query radius")
	var sheep = lab.get_node("Sheep")
	sheep.set_physics_process(false)
	for metal in get_nodes_in_group("magnetic_targets"):
		metal.global_position = Vector3(20, 1, 20)
	sheep.global_position = lettuce.global_position + Vector3(1.0, 0, 0)
	await physics_frame
	sheep._physics_process(0.1)
	check(sheep.velocity.x < 0, "Sheep response follows lettuce")
	for tick in range(30):
		lettuce.eat(0.1)
	check(not lettuce.available and not lettuce.visible and lettuce.respawn_time == 10.0, "Eating consumes lettuce after three seconds")
	lettuce.item_step(10.0)
	check(lettuce.available and lettuce.visible and lettuce.global_position == lettuce.home_position, "Lettuce returns to its original home after ten seconds")

	var sheep_costume = lab.get_node("Item_80")
	check(collect_fixture(sheep_costume,inv) and player.item_costume == "sheep", "Equip global sheep costume")
	await process_frame
	check(player.costume_visual != null and player.costume_visual.skeleton.get_bone_count() == 14, "Sheep costume has its original animated player model")
	check(not player.skeleton.get_node("MeshInstance3D").visible, "Costume replaces the visible Ralph model")
	sheep.global_position = player.global_position + Vector3.FORWARD * 2.0
	check(inv.use_selected() and sheep.call_actor == player, "Sheep costume calls nearby sheep")
	var ghost_costume = lab.get_node("Item_125")
	check(collect_fixture(ghost_costume,inv) and player.item_costume == "ghost", "Switch to global ghost costume")
	await process_frame
	check(player.costume_visual.skeleton.get_bone_count() == 29, "Ghost costume has its original animated player model")
	var ghost = lab.get_node("GhostTarget")
	ghost.global_position = player.global_position + Vector3.FORWARD * 2.0
	check(inv.use_selected() and ghost.scared_time > 0.0, "Ghost costume broadcasts boo to compatible ghosts")
	select(inv, 7)
	await process_frame
	check(player.item_costume.is_empty() and player.skeleton.get_node("MeshInstance3D").visible, "Unequipping a costume restores Ralph")

	var rocket = lab.get_node("Item_10")
	check(collect_fixture(rocket,inv) and inv.use_selected(), "Rocket starts through reusable inventory use")
	inv._input(drop_event)
	check(player.active_rocket == rocket and inv.state.items.has(rocket.item_id),"Disabled drop cannot dismount or discard an active rocket")
	var starting_height = player.global_position.y
	var starting_fuel = rocket.fuel
	for step in range(36):
		rocket.flight_step(1.0/60, Vector2.ZERO, false)
	check(player.global_position.y > starting_height and rocket.fuel < starting_fuel, "Rocket launch actually moves the player and burns fuel")
	check(not inv.open_wheel(), "Wheel cannot interrupt an active rocket flight")
	var fuel = rocket.fuel
	rocket.flight_step(0.1, Vector2(0, -1), true)
	check(is_equal_approx(rocket.fuel, fuel-0.2) and player.velocity.y > 0, "Rocket boost and climb controls")
	check(inv.use_selected() and player.active_rocket == null and not rocket.sound.playing, "Action dismounts rocket and releases engine audio")
	check(inv.state.count_class(10) == 0 and rocket.spent,"Dismount consumes Rocket from inventory")
	rocket.restore()
	check(collect_fixture(rocket,inv),"Returned Rocket can be collected again")
	rocket.fuel = 0.01
	rocket.health = 2.0
	check(inv.use_selected(), "A fueled rocket can relaunch")
	rocket.flight_step(rocket.mount_remaining, Vector2.ZERO, false)
	rocket.flight_step(0.1, Vector2.ZERO, false)
	check(player.active_rocket == null and rocket.fuel == 0.0, "Fuel depletion ends rocket flight")
	check(not inv.use_selected(), "An empty rocket refuses to launch")
	rocket.restore()
	check(rocket.fuel == rocket.fuel_seconds and rocket.health == rocket.durability, "Rocket rollback resets per-instance fuel and damage")

	var animation = player.animation_player.get_animation("run")
	var scale_tracks = 0
	for track in range(animation.get_track_count()):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			scale_tracks += 1
	check(scale_tracks == 31, "Run retains scale tracks for every original joint")
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play_anim("run")
	player.animation_player.advance(0.0)
	player.apply_legacy_reaction_pose()
	check(player.skeleton.get_bone_pose_scale(22).x < 0.01 and player.skeleton.get_bone_pose_scale(25).z > 2.0, "RUNF2 collapses thighs and stretches rotating feet")
	var material = player.skeleton.get_node("MeshInstance3D").mesh.surface_get_material(0)
	check(material.get_shader_parameter("use_legacy_skin"), "Renderer uses independent original part scales")
	var first = player.legacy_skin.last_matrices[25]
	player.animation_player.advance(animation.length)
	player.apply_legacy_reaction_pose()
	check(first.is_equal_approx(player.legacy_skin.last_matrices[25]), "Run loops continuously without a rest-pose reset")
	player.set_state(player.WolfState.IDLE)
	select(inv, 80)
	await process_frame
	inv.state.reset()
	await process_frame
	check(player.item_costume.is_empty() and player.skeleton.get_node("MeshInstance3D").visible, "Inventory reset also clears a worn costume")
	for kind in Catalog.CLASSES:
		var direct_item = Catalog.CLASSES[kind].new()
		check(direct_item.class_id == kind, "Global item classes have their own class ID")
		direct_item.free()

	lab.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Shared item mechanics: %d failures" % failures)
	quit(1 if failures else 0)
