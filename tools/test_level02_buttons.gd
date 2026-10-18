extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value: bool,message: String):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_51").set_physics_process(false)
	level.get_node("LevelEnvironment").set_physics_process(false)
	var button = level.get_node("SensibleButton_45"); button.set_physics_process(false)
	var lift = level.get_node("Wooden Lift_47"); lift.set_physics_process(false)
	var flock = level.get_node("Flock"); flock.set_physics_process(false)
	for sheep in flock.sheep: sheep.set_physics_process(false)
	check(button.visual.animation_player.assigned_animation=="off" and not button.pressed,"Button starts raised using native OFF pose")
	check(button.definition.targets.size()==1 and int(button.definition.targets[0])==47 and is_equal_approx(lift.on_y,5.8) and is_equal_approx(lift.speed,1.2),"Native button ID list links lift 47 with authored 5.8m endpoint / 1.2m per second")
	check(level.get_node("OriginalObjectCollisions").get_node_or_null("Wooden Lift_47")==null,"Lift has no static duplicate collider")
	player.global_position = button.global_position
	await physics_frame; await physics_frame
	button._physics_process(.016)
	check(button.pressed and button.visual.animation_player.assigned_animation=="on","Ralph overlap presses the original ON pose")
	var before = lift.position.y; lift._physics_process(1)
	check(is_equal_approx(lift.position.y,before+1.2),"Pressing the button raises the moving platform at source speed")
	player.global_position = Vector3(100,10,100)
	await physics_frame; await physics_frame
	button._physics_process(.016); lift._physics_process(1)
	check(not button.pressed and button.visual.animation_player.assigned_animation=="off" and is_equal_approx(lift.position.y,before),"Releasing button raises its cap and returns the platform")
	var sheep = flock.sheep.filter(func(s): return not s.sleepy)[0]
	for other in flock.sheep: other.global_position = Vector3(100,10,100); other.flock_target = null
	sheep.global_position = button.global_position+Vector3(2,0,0)
	sheep.button_think_timer = .5; flock._physics_process(.1)
	check(flock.attraction(sheep)==null,"Sheep waits for its staggered thinking slot rather than instant attraction")
	flock._physics_process(.5)
	check(flock.attraction(sheep)==button,"An awake sheep within six metres reserves the pressure button")
	var approach_start: Vector3 = sheep.global_position
	sheep._physics_process(.1)
	check(sheep.flock_phase=="button_turn" and Vector2(sheep.global_position.x-approach_start.x,sheep.global_position.z-approach_start.z).length()<.01,"Sheep first turns in place instead of rushing toward the button")
	var saw_look = false; var saw_walk = false; var max_speed = 0.0
	for frame in range(600):
		sheep._physics_process(1.0/60)
		saw_look = saw_look or sheep.flock_phase=="button_look"
		saw_walk = saw_walk or sheep.visual.idle_clip=="walk3"
		max_speed = maxf(max_speed,Vector2(sheep.velocity.x,sheep.velocity.z).length())
		await physics_frame
	check(saw_look and saw_walk and max_speed<=2.501,"Original turn/look/WALK3 sequence keeps native 250 units per second")
	button._physics_process(.016)
	check(sheep.global_position.distance_to(button.global_position)<.3 and sheep.visual.idle_clip=="stand2" and button.occupants.has(sheep),"Sheep physically approaches centre, stands and holds the button without eating audio")
	lift.set_physics_process(true); button.set_physics_process(true)
	player.global_position = lift.global_position+Vector3(0,.23,0); player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	var rider_y = player.global_position.y
	for frame in range(120): await physics_frame
	check(player.global_position.y>rider_y+1 and absf(player.global_position.y-lift.global_position.y-.21)<.15,"Moving lift physically carries Ralph with its collider")
	var plant = level.get_node("Salad_74")
	plant.global_position = lift.global_position+Vector3(0,.215,0)
	plant.holder = null; plant.available = true; plant.deployed = true
	# Deliberately omit a placement support: saved/previously placed items must
	# discover it themselves, including after the platform starts descending.
	await physics_frame; await physics_frame
	for other in flock.sheep: other.global_position = Vector3(100,10,100)
	var original_height = plant.global_position.y
	for frame in range(90): await physics_frame
	check(plant.global_position.y<original_height-1 and absf(plant.global_position.y-lift.global_position.y-.215)<.06,"Placed lettuce follows a descending lift using automatic support ray")
	plant.global_position = Vector3(100,10,100)
	player.set_physics_process(false); player.global_position = Vector3(100,10,100)
	lift.set_physics_process(false); button.set_physics_process(false)
	sheep.flock_target = null; sheep.global_position = button.global_position+Vector3(6.1,0,0); sheep.button_think_timer = 0
	flock._physics_process(.016); check(flock.attraction(sheep)==null,"Buttons do not attract sheep beyond native six-metre search")
	sheep.global_position = button.global_position+Vector3(2,1.6,0); sheep.button_think_timer = 0
	flock._physics_process(.016); check(flock.attraction(sheep)==null,"Button search enforces native 1.5m height difference")
	sheep.global_position = button.global_position; sheep.flock_target = button; sheep.button_think_timer = 0
	var lettuce = level.get_node("Salad_74"); lettuce.global_position = button.global_position+Vector3(2,0,0); lettuce.available = true; lettuce.respawn_time = 0
	flock._physics_process(.016)
	check(flock.attraction(sheep)==lettuce,"Native score penalty lets nearby food take priority over a held button")
	button.definition.props["0x8"] = 14
	check(button.scent_strength()==0,"Native NO_SHEEP buttons remain excluded from sheep attraction")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED; level.queue_free(); await process_frame
	print("Level02 original buttons / lift / sheep: ",failures," failures"); quit(failures)
