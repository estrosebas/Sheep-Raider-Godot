extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func stop_audio(scene):
	for node in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
func leaf_spot(zone,player) -> Vector3:
	var rect = Rect2(zone.polygon[0],Vector2.ZERO)
	for p in zone.polygon: rect = rect.expand(p)
	for x in range(int(floor(rect.position.x)),int(ceil(rect.end.x))):
		for z in range(int(floor(rect.position.y)),int(ceil(rect.end.y))):
			var point = Vector2(x+.1,z+.1)
			if not Geometry2D.is_point_in_polygon(point,zone.polygon) or not Geometry2D.is_point_in_polygon(point+Vector2(.02,0),zone.polygon): continue
			var query = PhysicsRayQueryParameters3D.create(Vector3(point.x,3,point.y),Vector3(point.x,-2,point.y),1)
			query.exclude = [player.get_rid()]
			var hit = player.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and absf(hit.position.y-zone.global_position.y)<.5: return hit.position+Vector3.UP*.01
	return Vector3.INF
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; SaveFiles.directory = "user://level04_mechanics_test_%d"%Time.get_ticks_usec()
	GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.6).timeout
	var player = level.player
	var director = level.get_node("LevelCinematics"); director.set_process(false)
	for movie in director.movies.values(): if movie.playing: movie.finish_sequence(true)
	var elf = level.get_node("DaffyLessons"); elf.set_process(false)
	player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	var guard = level.get_node("Sam_42"); guard.set_physics_process(false)
	var bull = level.get_node("bull_60"); bull.set_physics_process(false)
	var zone = level.get_node("HeapOfLeaf_72"); zone.set_physics_process(false)
	level.get_node("HeapOfLeaf_73").set_physics_process(false)
	var approach = Vector3.FORWARD
	for i in range(32):
		var offset = Vector3(sin(i*TAU/32),0,cos(i*TAU/32))*2.3
		var point = guard.home+offset
		var ground_ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*2,2)
		var ground = player.get_world_3d().direct_space_state.intersect_ray(ground_ray)
		if not ground.is_empty() and absf(ground.position.y-guard.home.y)<.5:
			player.global_position = ground.position+Vector3.UP*.02; approach = offset.normalized(); break
	player.set_state(player.WolfState.IDLE)
	player.skeleton.rotation.y = atan2(-approach.x,-approach.z)
	await create_timer(.2).timeout
	check(player.is_on_floor(),"Flute test starts with Ralph grounded")
	player.set_physics_process(false)
	var flute = level.get_node("Flute_74")
	player.inventory.animate_selection = false
	check(player.inventory.add_item({"id":flute.item_id,"class_id":41,"label":flute.item_label,"icon":flute.icon_path,"kept":false},flute),"Native flute equips through inventory")
	player.animation_player.advance(0); player.legacy_skin.update_pose(); flute._update_held_position()
	check(flute.holder==player and flute.global_transform.is_equal_approx(flute.attachment_transform(player)),"Flute attaches to original hand joint18")
	check(flute.use_item(player).success,"Flute can start on real terrain")
	check(player.current_state==player.WolfState.FLUTE_IDLE and player.animation_player.current_animation=="flute_idle","Native FLUTE1 pose is used")
	check(flute.sound.playing and flute.sound.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Native tune37 loops without retriggering")
	flute._update_held_position(); flute.item_step(.02)
	check(guard.state==guard.State.HYPNOTIZED and guard.alert_level<0 and guard.clip=="hypnos1","Flute starts hypnosis from watch state and clears alert")
	check(flute.notes.size()>0,"Original DAV209 music notes spawn")
	check(flute.detection_report().get("class_id",-1)==1,"Shared HUD receives native Sam nearest-target feedback")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var saved_point = player.global_position
		var saved_yaw = player.skeleton.rotation.y
		player.global_position = Vector3(5,.02,0); player.skeleton.rotation.y = 0
		player.animation_player.seek(.5,true); player.animation_player.advance(0); player.legacy_skin.update_pose()
		flute._update_held_position(); flute.item_step(.02)
		var camera = Camera3D.new(); level.add_child(camera)
		var target = player.global_position+Vector3.UP
		for i in range(32):
			var point = player.global_position+Vector3(cos(i*TAU/32)*3.5,1.6,sin(i*TAU/32)*3.5)
			var ray = PhysicsRayQueryParameters3D.create(point,target,3); ray.exclude=[player.get_rid(),guard.get_rid()]
			if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): camera.position=point; break
		camera.look_at(target); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_flute_pose.png")
		camera.queue_free(); player.camera.make_current()
		player.global_position = saved_point; player.skeleton.rotation.y = saved_yaw
		player.legacy_skin.update_pose(); flute._update_held_position()
	var clip_length = float(guard.visual.rig.animations.hypnos1.duration)
	guard._process(clip_length+.01); guard._physics_process(.016)
	check(guard.clip=="hypnos2","Sam finishes HYPNOS1 before looping HYPNOS2")
	player.global_position += approach*.5; flute._update_held_position()
	var start = guard.global_position
	for i in range(30):
		flute.item_step(1.0/60); guard._physics_process(1.0/60); guard._process(1.0/60)
	check(guard.global_position.distance_to(start)>.05 and Vector2(guard.velocity.x,guard.velocity.z).length()<=2.001,"Hypnotized Sam follows at native2m/s")
	guard.flute_zones = [{"min":[int(guard.global_position.x*100)-1,-1000,int(-guard.global_position.z*100)-1],"max":[int(guard.global_position.x*100)+1,1000,int(-guard.global_position.z*100)+1]}]
	guard.investigate_point = guard.global_position+Vector3(0,0,3)
	start = guard.global_position
	guard._physics_process(.016)
	check(Vector2(guard.global_position.x-start.x,guard.global_position.z-start.z).length()<.001,"Hypnosis respects authored movement boundary")
	flute.deactivate(); guard.flute_timer = 0; guard._physics_process(.02); guard._physics_process(.02)
	check(guard.state==guard.State.RETURN_HOME,"Sam returns when flute refresh expires")
	guard._enter(guard.State.CHASE,"run1"); guard.on_flute(player.global_position,[])
	check(guard.state==guard.State.CHASE,"Flute does not interrupt an active chase")
	guard.reset_guard(); flute.store(); player.inventory.equipped_id = ""
	player.interrupt_actions(); player.set_physics_process(false)
	check(bull.grounded and absf(bull.home.y-.001)<.2,"Bull source pivot snaps onto floor")
	var spot = leaf_spot(zone,player)
	check(spot!=Vector3.INF,"Original irregular leaf polygon has a real terrain interior")
	if spot!=Vector3.INF:
		player.global_position = spot; player.set_state(player.WolfState.SNEAK)
		bull.reset_to_home(); zone.positions.clear(); zone._physics_process(.016)
		check(bull.state==bull.State.ASLEEP,"Stationary actor on leaves produces no noise")
		player.global_position.x += .02; zone._physics_process(.016)
		check(zone.noise_count>0 and zone.emitter.emitting and zone.sound.playing,"Moving in native leaf polygon makes original rustle and particles")
		check(bull.state==bull.State.WAKING and bull.clip=="up1a","Sneaking through leaves wakes its native guardian")
		zone.emitter._process(.21)
		check(zone.emitter.emitted_total>0,"Leaf emitter uses native sprites")
		bull._process(float(bull.visual.rig.animations.up1a.duration)+.01); bull._physics_process(.016)
		check(bull.state==bull.State.CHARGE,"Bull wakes completely before charging")
		player.global_position = bull.global_position+Vector3(0,0,5)
		bull.charge_target = player.global_position; bull._physics_process(.016)
		check(is_equal_approx(Vector2(bull.velocity.x,bull.velocity.z).length(),8.0),"Bull charges at native8m/s")
		player.global_position = bull.global_position+Vector3(0,0,1)
		bull._physics_process(.016)
		check(player.current_state==player.WolfState.SAM_DEATH and player.death_animation_override=="bull_death" and bull.hit_count>0,"Bull contact invokes native PUNCH6 death")
	player.respawn_at_checkpoint(); player.restart_fade_remaining = 0; player.restart_fade.set_amount(0)
	check(bull.state==bull.State.ASLEEP and bull.global_position.distance_to(bull.home)<.01,"Bull and leaf state reset on player respawn")
	var leaf = level.get_node("Leaf_109")
	check(leaf.grounded and leaf.animating,"Ambient leaf uses grounded home and authored nonloop FLY")
	leaf._process(2)
	check(not leaf.animating and not leaf.visual.visible and leaf.timer>=.75 and leaf.timer<=2.25,"Ambient leaf ends its motion and waits original random interval")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,900)
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = bull.home+Vector3(4,2.2,5); camera.look_at(bull.home+Vector3.UP*.8); camera.current = true
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_bull_grounded.png")
	stop_audio(level); level.queue_free(); await process_frame
	print("Level04 original flute/hypnosis / leaf noise polygons / bull attack / ambient leaf: ",failures," failures")
	quit(failures)
