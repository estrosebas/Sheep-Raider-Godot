extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_scene(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	scene.queue_free(); await process_frame
func run():
	SaveFiles.startup_offered = true
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await create_timer(.3).timeout
	var player = lab.player; player.set_physics_process(false); player.velocity = Vector3.ZERO
	var bush = lab.get_node("Bush")
	player.global_position = bush.global_position
	bush.wear(player); bush._process(4)
	check(bush.hidden_from_sam() and is_equal_approx(bush.scent_strength(),2.5),"Hidden bush attracts only inside adjusted2.5m radius")
	var sheep = lab.get_node("Sheep"); sheep.set_physics_process(false)
	sheep.global_position = player.global_position+Vector3.RIGHT*4; sheep.velocity = Vector3.ZERO
	sheep._physics_process(.016)
	check(sheep.attraction_target!=bush and Vector2(sheep.velocity.x,sheep.velocity.z).length()<.01,"Laboratory sheep ignores a worn bush four metres away")
	sheep.global_position = player.global_position+Vector3.RIGHT*2
	var before = sheep.global_position.distance_to(player.global_position)
	sheep._physics_process(.016)
	check(sheep.attraction_target==bush and sheep.visual.idle_clip=="walk3","Nearby lab sheep uses native WALK3 rather than sliding without animation")
	for i in range(90): sheep._physics_process(.016)
	var distance = Vector2(sheep.global_position.x-player.global_position.x,sheep.global_position.z-player.global_position.z).length()
	check(distance<before and distance>=1.1 and distance<=1.25 and sheep.visual.idle_clip=="stand1" and bush.eaten_time>0,"Sheep stops at native1.2m and plays eating pose")
	await stop_scene(lab)
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	level.get_node("DaffyLessons").set_process(false); level.get_node("Sam_51").set_physics_process(false)
	player = level.player; player.set_physics_process(false); player.cinematic_controls_locked = false; player.tutorial_movement_locked = false
	var flock = level.get_node("Flock"); flock.set_physics_process(false); sheep = flock.sheep[0]
	for other in flock.sheep:
		other.set_physics_process(false)
		if other!=sheep: other.sleepy = true
	player.global_position = player.respawn_ground_position(sheep.home+Vector3.RIGHT*4)
	player.velocity = Vector3(0,-1,0); player.move_and_slide(); player.velocity = Vector3.ZERO
	bush = preload("res://scripts/items/original_bush.gd").new(); level.add_child(bush); bush.position = player.global_position
	bush.wear(player); bush._process(4)
	# Even a prior food-chain origin near Ralph must not extend bush detection.
	sheep.last_food_position = player.global_position
	flock._physics_process(.016)
	check(flock.attraction(sheep)!=bush,"Level02 bush range is measured from sheep, not old lettuce position")
	sheep.global_position = player.global_position+Vector3.RIGHT*2
	sheep.global_position.y = player.global_position.y; sheep.flock_target = null
	flock._physics_process(.016)
	check(flock.attraction(sheep)==bush,"Level02 flock detects a worn bush only nearby")
	for i in range(100): sheep._physics_process(.1)
	check(sheep.visual.idle_clip=="walk3" or sheep.flock_phase=="eat","Level02 native turn/look transitions lead to WALK3 approach")
	sheep.global_position = player.global_position+Vector3.RIGHT*3.2
	flock._physics_process(.016)
	check(flock.attraction(sheep)!=bush,"Existing reservation cannot keep pursuing a bush beyond2.5m")
	await stop_scene(level)
	print("Worn bush range / native WALK3 /120-unit eating distance / no stale reservations: ",failures," failures")
	quit(failures)
