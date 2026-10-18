extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func ticks(count: int):
	for i in range(count): await physics_frame
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://raft_test_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({})
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene = level
	await ticks(6)
	var cinematics = level.get_node("LevelCinematics")
	for movie in cinematics.movies.values():
		if movie.playing: movie.finish_sequence(true)
	cinematics.set_process(false); level.get_node("DaffyLessons").set_process(false)
	for node in get_nodes_in_group("sharks")+[level.get_node("Sam_42"),level.get_node("bull_60")]: node.set_physics_process(false)
	var player = level.player
	player.cinematic_controls_locked = false; player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	var raft = level.get_node("Raft_40")
	check(raft is OriginalRaft and raft.initialized,"Raft53 owns its runtime controller")
	check(not level.get_node("OriginalObjectCollisions").has_node("Raft_40"),"No static duplicate left behind")
	var origin = raft.global_position
	player.global_position = origin+Vector3(.6,.12,.4)
	player.last_ground_y = player.global_position.y; player.safe_position = player.global_position
	player.velocity = Vector3.ZERO; player.set_state(player.WolfState.IDLE)
	player.water_motion.reset(player)
	await ticks(5)
	check(player.is_on_floor() and raft.is_rider(player),"Ralph stands on native deck above water")
	var fan = level.get_node("Fan_59") if level.has_node("Fan_59") else level.get_node("Mailbox_57").items[0]
	fan.equip_to(player); player.inventory.equipped_node = fan
	# Place the centre behind the facing cone: native holder-box overlap wins.
	player.skeleton.rotation.y = 0
	check(not ItemRules.in_fan_cone(player.global_position,player.item_facing(),raft.global_position),"Fixture exercises carrier-overlap rather than centre cone")
	check(raft.receives_fan_from(player,player.item_facing()),"Fan sees raft beneath its carrier")
	var relative = player.global_position-raft.global_position
	var started = raft.global_position
	fan.use_item(player)
	await ticks(120)
	print("raft travel ",raft.global_position-started," fan speed ",raft.fan_speed," rider relative ",player.global_position-raft.global_position," state ",player.current_state)
	check(raft.global_position.distance_to(started)>1,"Real equipped fan propels original level04 raft")
	check(absf(raft.fan_speed-3.5)<.001,"Native 350-unit speed and acceleration")
	check((player.global_position-raft.global_position-relative).length()<.08 and player.is_on_floor(),"Ralph carried once, with no sliding, double displacement or swimming")
	check(raft.wake.emitted_total>0,"Native ripple sprites follow movement")
	if DisplayServer.get_name()!="headless":
		var camera = Camera3D.new(); level.add_child(camera)
		camera.global_position = raft.global_position+Vector3(5,3.5,6)
		camera.look_at(raft.global_position+Vector3.UP*.7); camera.make_current()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_raft.png")
		camera.queue_free(); player.camera.make_current()
	fan.deactivate(); await ticks(110)
	check(raft.fan_speed==0,"Releasing the fan decelerates to rest")
	var stopped = raft.global_position; await ticks(10)
	check(raft.global_position.distance_to(stopped)<.001,"Still water does not drift")
	# An off-deck fan cannot propel a raft even when the cone reaches it.
	player.set_physics_process(false); player.global_position = raft.global_position+Vector3(0,1,3)
	fan.active = true; raft.on_fan_blow(Vector3.FORWARD,1); await ticks(3)
	check(raft.fan_speed==0,"Wolf must be aboard to power the raft")
	fan.deactivate(); fan.store(); player.inventory.equipped_node = null
	# Physics-active sheep and floor-following cargo share the displacement.
	raft.global_position = origin; raft.reset_to_home()
	var sheep = level.get_node("Flock").sheep[0]
	sheep.global_position = origin+Vector3(-.55,.125,-.4); sheep.velocity = Vector3.ZERO
	sheep.flock_target = null; sheep.call_time = 0; sheep.flock_phase = "idle"; sheep.flock_timer = 0
	var old_home = sheep.home
	var lettuce = ItemCatalog.create_item(3,"raft-test-lettuce"); level.add_child(lettuce)
	lettuce.deployed = true; lettuce.available = true; lettuce.position = origin+Vector3(.8,.125,-.8)
	var follower = preload("res://scripts/items/original_moving_support.gd").new(); follower.support = raft; lettuce.add_child(follower)
	player.global_position = origin+Vector3(.4,.12,.5); player.velocity = Vector3.ZERO
	await ticks(3)
	# Cargo deliberately provides no scent during this transport test.
	lettuce.remove_from_group("sheep_attractors")
	var cargo_relative = lettuce.global_position-raft.global_position
	var sheep_relative = sheep.global_position-raft.global_position
	player.set_physics_process(true); player.water_motion.reset(player); player.set_state(player.WolfState.IDLE)
	fan.equip_to(player); player.inventory.equipped_node = fan; fan.use_item(player)
	await ticks(45)
	check(absf(sheep.global_position.y-raft.surface_height())<.05 and raft.is_rider(sheep),"Live sheep retains deck collision")
	check(sheep.global_position.distance_to(origin+sheep_relative)>.15,"Sheep moves with raft")
	check(sheep.moving_anchor==raft and sheep.home==old_home,"Native sheep anchor preserves checkpoint home")
	check((lettuce.global_position-raft.global_position-cargo_relative).length()<.03,"Placed lettuce rides once through MovingSupport")
	fan.deactivate()
	var moved = raft.global_position; raft.reset_to_home()
	check(raft.global_position==moved,"Native RESET0 preserves raft position at respawn")
	raft.definition.reset_position = true; raft.reset_to_home()
	check(raft.global_position==origin,"Reusable RESET1 restores authored position")
	# Validate converted cardinal/diagonal water currents and flag priorities.
	for row in [[0x08000000,Vector3.LEFT],[0x10000000,Vector3.RIGHT],[0x20000000,Vector3.BACK],[0x40000000,Vector3.FORWARD]]:
		var flow = OriginalRaft.current_from_flags(row[0])
		var direction = Vector3(-sin(flow.heading),0,cos(flow.heading))
		check(direction.distance_to(row[1])<.001 and flow.speed==2,"Original water current flags "+str(row[0]))
	check(OriginalRaft.current_from_flags(0x4c800000).speed==1,"FLOW_SLOW takes precedence over FAST")
	# The raft's real body must stop at a bank without passing through it.
	player.set_physics_process(false); player.global_position = origin+Vector3(.4,.12,.5)
	var wall = StaticBody3D.new(); var wall_shape = CollisionShape3D.new(); wall_shape.shape = BoxShape3D.new()
	wall_shape.shape.size = Vector3(10,5,.3); wall.add_child(wall_shape); level.add_child(wall)
	wall.global_position = origin+Vector3(0,0,-2.3)
	await ticks(2)
	for i in range(90):
		raft.on_fan_blow(Vector3.BACK,1.0/60); await physics_frame
	check(raft.global_position.z>wall.global_position.z+.14-deck_min_z(raft),"Raft solid box stops against wall/bank")
	check(raft.global_position.y==origin.y,"Wall contact preserves authored water height")
	wall.queue_free(); raft.reset_motion()
	# Drive the same raft by a native current, with no Wolf or fan aboard.
	player.global_position = origin+Vector3(0,4,4)
	var environment = level.get_node("LevelEnvironment")
	var water = environment.rules.water.duplicate(true)
	for zone in environment.rules.water: zone.flags = 0x10800000 # +X, slow100u/s
	var current_start = raft.global_position
	await ticks(60)
	check(raft.global_position.x>current_start.x+.15 and raft.flow_speed>.45,"Water current moves empty raft using native acceleration")
	environment.rules.water = water; raft.reset_motion()
	# New saves retain raft position; legacy saves without rafts remain valid.
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	var saved = save.snapshot.duplicate(true); var saved_position = raft.global_position
	raft.global_position += Vector3(3,0,0)
	check(save.restore_checkpoint(saved),"Checkpoint with raft restores")
	check(raft.global_position.distance_to(saved_position)<.001,"Loaded raft returns to saved position")
	var legacy = saved.duplicate(true); legacy.world.erase("rafts")
	check(save.restore_checkpoint(legacy),"Older saves without raft field remain compatible")
	print("Level04 reusable raft failures: ",failures)
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame; quit(failures)

func deck_min_z(raft: OriginalRaft) -> float: return raft.deck.position.z
