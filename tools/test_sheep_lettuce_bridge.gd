extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value: bool,message: String):
	if not value:
		failures += 1
		printerr(message)
func frames(count: int):
	for i in range(count): await physics_frame
func carry(player, sheep):
	sheep.carried_by = player
	player.carried_sheep = sheep
	sheep.carry_controller = OriginalSheepCarry.new()
	sheep.visual.idle("stand8")
	sheep.get_node("CollisionShape3D").set_deferred("disabled",true)
	sheep.add_collision_exception_with(player)
func run():
	SaveFiles.startup_offered = true
	var level = load("res://scenes/levels/Level01.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("DaffyLessons").movies[0].played = true
	level.get_node("PorkyLessons").set_process(false)
	await frames(30)
	var player = level.player
	level.get_node("Sam_43").set_physics_process(false)
	level.get_node("Flock").set_physics_process(false)
	for sheep in level.get_node("Flock").sheep: sheep.set_physics_process(false)
	var sheep = level.get_node("Sheep_52")
	var salad = level.get_node("PorkyLessons").salads[0]
	# Controlled floor away from scenery, edges and a wall are real physics.
	var floor = StaticBody3D.new()
	floor.position = Vector3(200,-.1,200)
	var box = CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	box.shape.size = Vector3(10,.2,10)
	floor.add_child(box)
	level.add_child(floor)
	player.global_position = Vector3(200,.005,200)
	player.skeleton.rotation.y = 0
	await frames(20)
	check(player.is_on_floor(),"Placement fixture is on a real floor")
	player.set_physics_process(false)
	carry(player,sheep)
	await frames(2)
	check(not OriginalPlacement.probe(player,sheep,false).is_empty(),"Eight body samples accept clear floor in front")
	var wall = StaticBody3D.new()
	wall.position = player.global_position+player.item_facing()*.7+Vector3.UP*.5
	var wall_shape = CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new()
	wall_shape.shape.size = Vector3(2,1,.2)
	wall.add_child(wall_shape)
	level.add_child(wall)
	await frames(2)
	check(OriginalPlacement.probe(player,sheep,false).is_empty(),"Static volume sweep rejects wall along putdown route")
	check(sheep.interact(player),"Blocked drop still starts original PUT2A attempt")
	await frames(55)
	check(player.carried_sheep == sheep and not player.cinematic_controls_locked,"Blocked drop keeps sheep and releases controls")
	wall.queue_free()
	await frames(2)
	player.global_position.z = 204.7
	check(OriginalPlacement.probe(player,sheep,false).is_empty(),"No supporting floor beyond edge rejects putdown")
	player.global_position.z = 200
	check(sheep.interact(player),"Clear ground starts PUT2A/B")
	await frames(55)
	check(player.carried_sheep == null and sheep.global_position.distance_to(player.global_position+player.item_facing()*.92) < .05,"Successful putdown lands on queried ground at native 92-unit offset")
	# Both item use buttons must place through PUT1A/B, not teleport instantly.
	salad.available = true
	salad.show()
	player.inventory.animate_selection = false
	check(player.inventory.add_item({"id":salad.item_id,"class_id":3,"label":"Lechuga","icon":salad.icon_path,"kept":false},salad),"Fixture equips a real original lettuce")
	var obstruction = StaticBody3D.new()
	obstruction.position = player.global_position+Vector3.UP*.12
	var obstruction_shape = CollisionShape3D.new()
	obstruction_shape.shape = BoxShape3D.new()
	obstruction_shape.shape.size = Vector3(.25,.1,.25)
	obstruction.add_child(obstruction_shape)
	level.add_child(obstruction)
	await frames(2)
	check(player.inventory.use_selected(),"Blocked lettuce placement begins original attempt")
	player.item_actions._process(.38)
	check(player.animation_player.current_animation == "placement_refused" and salad.holder == player and player.inventory.state.items.has(salad.item_id),"Rejected lettuce placement plays native STANDNO and retains item")
	player.item_actions._process(1.1)
	obstruction.queue_free()
	await frames(2)
	check(player.inventory.use_selected(),"Lettuce begins native placement animation")
	check(player.animation_player.current_animation == "throw_place" and salad.holder == player,"PUT1A keeps lettuce in hand until release")
	await frames(50)
	check(salad.deployed and salad.available and salad.holder == null and not player.inventory.state.items.has(salad.item_id),"PUT1B finishes with world lettuce removed from inventory")
	check(salad.original_visual.idle_clip == "objet","Dropped lettuce retains source OBJET rather than planted STAND pose")
	salad.original_visual.sample_animation("objet",0)
	var leaf_minimum = INF
	for surface in salad.original_visual.rig.surfaces.values():
		for i in range(surface.verts.size()):
			var v = surface.verts[i]
			var joint = int(surface.bones[i])
			var point = salad.original_visual.legacy_skin.last_matrices[joint]*salad.original_visual.legacy_skin.inverse_rests[joint]*Vector3(v[0],v[1],v[2])
			leaf_minimum = minf(leaf_minimum,(salad.original_visual.global_transform*point).y)
	check(leaf_minimum >= -.02 and leaf_minimum < .1,"Placed OBJET lettuce lies on actual floor")
	# Source XZ, Y, 90% warning threshold and class scoring.
	sheep.global_position = player.global_position+Vector3(5.9,0,0)
	sheep.sleepy = false
	var guidance = OriginalLettuceGuidance.query(salad,player.global_position,11)
	check(not guidance.is_empty() and guidance.near_limit and is_equal_approx(guidance.distance,5.9),"Sheep indicator warns at 90% of source six-metre range")
	sheep.global_position.x = player.global_position.x+6.01
	check(OriginalLettuceGuidance.query(salad,player.global_position,11).is_empty(),"Sheep beyond six metres cannot see lettuce")
	sheep.global_position = player.global_position+Vector3(1,1.51,0)
	check(OriginalLettuceGuidance.query(salad,player.global_position,11).is_empty(),"Source 150-unit vertical cutoff is respected")
	sheep.global_position = player.global_position+Vector3(1,0,0)
	var other = level.get_node("PorkyLessons").salads[1]
	other.available = true
	other.global_position = player.global_position+Vector3(2,0,0)
	check(not OriginalLettuceGuidance.query(salad,player.global_position,3).is_empty(),"Separate lettuce spacing indicator sees next leaf in chain")
	# Real animation and collision of the two source bridge halves.
	var bridge = level.get_node("bridge_40")
	var peer = level.get_node("bridge_41")
	bridge.set_physics_process(false)
	player.global_position = Vector3(7,.05,-25)
	sheep.global_position = Vector3(200,0,200)
	bridge._physics_process(.24)
	check(bridge.state == "idle","Ralph alone does not break bridge")
	sheep.global_position = player.global_position+Vector3(1,0,0)
	bridge._physics_process(.24)
	check(bridge.state == "creak","Sheep and Ralph separated on the bridge also create load")
	sheep.global_position = Vector3(200,0,200)
	bridge._physics_process(.01)
	check(bridge.state == "idle" and not bridge.frozen,"Bridge cancels collapse when sheep leaves before the limit")
	carry(player,sheep)
	for i in range(7): bridge._physics_process(.24)
	check(bridge.state == "creak" and bridge.frozen and player.tutorial_movement_locked,"Native POSE2 loops freeze Ralph at creak count six")
	check(bridge.audio.stream.resource_path.ends_with("105.wav"),"POSE2 uses original creaking sound105")
	for i in range(6): bridge._physics_process(.24)
	await frames(2)
	check(bridge.state == "breaking" and peer.state == "breaking" and bridge.collider.disabled and peer.collider.disabled,"Count twelve starts BRAKE2 and removes both bridge floors")
	check(sheep.dead and player.current_state == player.WolfState.PIT_FALL,"Bridge collapse kills sheep and Ralph through shared failure path")
	player.checkpoint_position = Vector3(200,.005,200)
	player.checkpoint_facing = 0
	sheep.respawn_position = Vector3(201,.005,201)
	sheep._step_death(7.1)
	await frames(2)
	check(not sheep.dead and bridge.state == "idle" and not bridge.collider.disabled and player.global_position.distance_to(player.checkpoint_position) < .03,"Sheep pit failure restores checkpoint and complete bridge")
	player.restart_fade_remaining = 0
	player.restart_fade.set_amount(0)
	var bomb = level.get_node("Dynamite_64") if level.has_node("Dynamite_64") else null
	for node in level.get_children():
		if node is DynamiteItem: bomb = node
	sheep.global_position = Vector3(203,.005,200)
	bomb.ignite(sheep.global_position)
	bomb.explode()
	check(sheep.dead and sheep.get_meta("death_cause") == "burn","Actual dynamite explosion blackens and kills sheep")
	sheep._step_death(3.1)
	check(not sheep.dead and not player.tutorial_movement_locked and player.restart_fade_remaining > 0,"Generic sheep death restarts checkpoint after native three-second delay and fades back in")
	sheep.global_position = Vector3(500,-2,500)
	sheep.last_floor_y = 0
	check(sheep._check_fatal_drop() and sheep.dead,"A free sheep falling without ground enters failure, not infinite fall")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	await create_timer(.1).timeout
	level.queue_free()
	await frames(2)
	print("Original lettuce / placement safety / sheep loss / bridge: ",failures," failures")
	quit(1 if failures else 0)
