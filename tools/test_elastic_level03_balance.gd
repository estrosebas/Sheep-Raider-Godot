extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func frames(n: int):
	for i in range(n): await physics_frame
func prepare(actor,elastic,a,b):
	Input.action_release("move_forward"); Input.action_release("move_backward"); Input.action_release("jump")
	elastic.reset_item(); elastic.tie_first(a,actor); elastic.tree_b = b; elastic.mode = "strung"
	actor.interrupt_actions(); actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	actor.cinematic_controls_locked = false; actor.tutorial_movement_locked = false
	actor.global_position = (a.global_position+b.global_position)*.5+Vector3(0,.08,.15)
	actor.camera_pivot.rotation.y = 0; actor.velocity = Vector3.ZERO
	actor.jump_origin_y = null; actor.floor_probe_warmup = 3
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://elastic_balance03_%d"%Time.get_ticks_usec()
	var lab = load("res://scenes/testing/ItemLab.tscn").instantiate(); root.add_child(lab); current_scene = lab
	await frames(15)
	var actor = lab.player; var item = lab.get_node("Elastic"); var elastic = item.controller
	var a = lab.get_node("ElasticTree_A"); var b = lab.get_node("ElasticTree_B")
	check(elastic.max_length==11.5 and elastic.two_anchor_max_length==9.5 and elastic.minimum_launch_charge==1,"Laboratory mirrors Level03 profile without reducing distance available to connect trees")
	prepare(actor,elastic,a,b); await frames(4)
	Input.action_press("move_forward"); await frames(40); Input.action_release("move_forward")
	check(elastic.engaged and elastic.tension>0 and elastic.tension<1 and elastic.flight.is_empty(),"Crossing and partial charge do not launch prematurely")
	check(elastic.stretch_audio.playing and elastic.stretch_audio.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and elastic.stretch_audio.stream.data==load("res://assets/levels/lvl_03/audio/284.wav").data,"Stretching plays original SEABOUCL284 as a separate uninterrupted loop")
	Input.action_press("jump"); await frames(4); Input.action_release("jump")
	check(elastic.flight.is_empty() and elastic.tension<1,"Airborne state at partial charge does not trigger a short projection")
	await frames(50)
	# Actual E/interaction route: a partial manual release must not shoot the sheep.
	prepare(actor,elastic,a,b); await frames(4)
	check(elastic.interact(actor),"Manual slingshot can be gripped at centre")
	Input.action_press("move_forward"); await frames(40); Input.action_release("move_forward")
	var sheep = lab.get_node("ElasticSheep"); sheep.set_physics_process(false)
	sheep.global_position = actor.global_position+Vector3(.75,0,0)
	check(elastic.tension>0 and elastic.tension<1,"Manual slingshot reaches partial charge")
	actor.inventory.interact_or_use()
	check(not elastic.pulling and elastic.flight.is_empty() and elastic.pending_shot.get("ratio",0)==0,"E releases partial tension without launching a sheep into the gap")
	check(not elastic.stretch_audio.playing,"Loop stops when releasing the elastic")
	sheep.global_position = Vector3(-15,0,-20)
	# Charge while walking: no jump is required; full range rather than a short arc.
	prepare(actor,elastic,a,b); await frames(4)
	Input.action_press("move_forward")
	var auto_launch = false; var early_launch = false
	for i in range(500):
		await physics_frame
		if not elastic.flight.is_empty():
			auto_launch = true; early_launch = elastic.flight.charge<1
			check(elastic.flight.distance==50 and elastic.flight.height==5,"Automatic full charge uses complete native50m/5m projection")
			break
	Input.action_release("move_forward")
	check(auto_launch and not early_launch,"Walking to shorter limit automatically launches only at100%, without pressing jump")
	check(not elastic.stretch_audio.playing,"Stretch loop stops on catapult launch")
	await frames(190)
	check(elastic.flight.is_empty() and actor.elastic_motion_owner==null and actor.is_on_floor() and actor.current_state!=actor.WolfState.PIT_FALL,"Full self projection lands on the laboratory floor and returns control")
	# Full manual shot follows the same charge gate, range and cleanup.
	prepare(actor,elastic,a,b); await frames(4); elastic.interact(actor)
	Input.action_press("move_forward")
	for i in range(500):
		await physics_frame
		if elastic.tension>=1: break
	check(elastic.tension==1 and elastic.pulling,"Manual slingshot can actually reach100%")
	sheep.global_position = actor.global_position+Vector3(.75,0,0)
	actor.inventory.interact_or_use(); Input.action_release("move_forward")
	check(not elastic.flight.is_empty() and elastic.flight.target==sheep and elastic.flight.distance==50,"Full manual release launches sheep with complete range")
	await frames(190)
	check(elastic.flight.is_empty() and not actor.launch_controls_locked and actor.camera.current,"Full sheep projection restores camera and input")
	stop_audio(lab); lab.queue_free(); await process_frame
	# The real Level03 gap: first50m contain a long stretch without ground.
	var level = load("res://scenes/levels/Level03.tscn").instantiate(); root.add_child(level); current_scene = level
	await frames(25)
	var manager = level.get_node("LevelCinematics")
	if manager.active_movie: manager.active_movie.finish_sequence(true)
	manager.set_process(false); level.get_node("DaffyLessons").set_process(false)
	level.get_node("Sam_63").set_physics_process(false)
	for candidate in level.get_node("Flock").sheep: candidate.set_physics_process(false)
	actor = level.player; elastic = level.get_node("elastic_104").controller
	a = level.get_node("ElasticTree_99"); b = level.get_node("ElasticTree_101")
	prepare(actor,elastic,a,b); await frames(6)
	Input.action_press("move_forward")
	var launched = false; var charge = 0.0; var travel = 0.0; var premature_pit = false
	for i in range(700):
		await physics_frame
		if not elastic.flight.is_empty():
			if not launched: charge = elastic.flight.charge; Input.action_release("move_forward")
			launched = true; travel = maxf(travel,elastic.flight.travelled)
		if launched and actor.current_state==actor.WolfState.PIT_FALL: premature_pit = true
		if launched and elastic.flight.is_empty() and actor.is_on_floor(): break
	Input.action_release("move_forward")
	print("Native gap: charge=",charge," travel=",travel," landing=",actor.global_position," grounded=",actor.is_on_floor())
	check(launched and charge==1 and travel>35 and not premature_pit and actor.is_on_floor(),"Level03 actual gap is crossed at full charge and ends on real terrain rather than midair pit death")
	prepare(actor,elastic,a,b); await frames(6); elastic.interact(actor)
	Input.action_press("move_forward")
	for i in range(500):
		await physics_frame
		if elastic.tension>=1: break
	var native_sheep = level.get_node("Flock").sheep[0]
	native_sheep.global_position = actor.global_position+Vector3(.75,0,0)
	check(elastic.pulling and elastic.tension==1,"Actual Level03 manual shot reaches full charge")
	actor.inventory.interact_or_use(); Input.action_release("move_forward")
	check(not elastic.flight.is_empty() and elastic.flight.target==native_sheep and elastic.flight.charge==1,"Level03 original sheep is projected with full charge")
	for i in range(190):
		await physics_frame
		if elastic.flight.is_empty(): break
	var probe = PhysicsRayQueryParameters3D.create(native_sheep.global_position+Vector3.UP,native_sheep.global_position-Vector3.UP*2,1)
	probe.exclude = [native_sheep.get_rid(),actor.get_rid()]
	check(elastic.flight.is_empty() and native_sheep.global_position.z>55 and not level.get_world_3d().direct_space_state.intersect_ray(probe).is_empty() and not actor.launch_controls_locked,"Full manual slingshot also crosses native gap and reaches terrain with restored controls")
	stop_audio(level); level.queue_free(); await process_frame
	print("Level03 elastic balance / SEABOUCL / full-charge catapult and slingshot / real gap: ",failures," failures")
	quit(failures)
