extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr(message)
func advance(sam,seconds: float):
	var remaining=seconds
	while remaining>.000001:
		var dt=minf(.01,remaining)
		sam._process(dt); sam._physics_process(dt)
		remaining-=dt
		await physics_frame
func run():
	SaveFiles.startup_offered=true; SaveFiles.pending={}; SaveFiles.directory="user://sam_crush_test_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	var level=load("res://scenes/levels/Level04.tscn").instantiate(); root.add_child(level); current_scene=level
	await create_timer(.6).timeout
	for movie in level.get_node("LevelCinematics").movies.values():
		if movie.playing: movie.finish_sequence(true)
	level.get_node("LevelCinematics").set_process(false); level.get_node("DaffyLessons").set_process(false)
	var player=level.player; player.set_physics_process(false); player.cinematic_controls_locked=false
	player.restart_fade_remaining=0; player.restart_fade.set_amount(0)
	player.global_position=Vector3(7,17,17)
	var sam=level.get_node("Sam_42"); sam.set_physics_process(false); sam.set_process(false)
	var stone=level.get_node("TriggedStone_65"); stone.set_physics_process(false)
	var button=level.get_node("SensibleButton_39"); button.set_physics_process(false)
	var zone=stone.definition.crush_zones[0]
	var center=GameSpace.original_point((Vector3(zone.min[0],zone.min[1],zone.min[2])+Vector3(zone.max[0],zone.max[1],zone.max[2]))/2)
	sam.global_position=center; sam.rotation.y=0
	stone.set_switch(button,true); stone._physics_process(.99)
	check(stone.state==stone.State.ARMED,"Native rock waits the authored1000ms")
	stone._physics_process(.02); stone._physics_process(.6)
	check(sam.state!=sam.State.STUNNED,"Rock cannot crush before native11/16 of FALL1")
	stone._physics_process(.08)
	check(sam.state==sam.State.STUNNED and sam.clip=="squash" and sam.alert_level==-1,"Actual stone hit invokes native Sam KnockOut and hides detection HUD")
	check(absf(sam.rules.knockout_seconds-3)<.001,"Native DEATHDURATIONMS is3000ms for the lying phase")
	# The native stone repeats KILL_CRUSH while its impact region is active.
	sam._process(.2); sam.global_position=center; stone._physics_process(.1)
	check(sam.clip_time<.001 and sam.knockout_remaining==3,"Continuing stone contact refreshes KO before FALL1 ends")
	stone._physics_process(.2)
	check(stone.state==stone.State.SETTLE,"Rock completes FALL1 before its native fracture animation")
	var actual_time=0.0
	await advance(sam,1.64); actual_time+=1.64
	check(sam.state==sam.State.STUNNED and sam.knockout_phase==sam.KnockoutPhase.FALL and sam.clip=="squash","Sam plays the full1.65s SQUASH once, without looping")
	await advance(sam,.02); actual_time+=.02
	check(sam.knockout_phase==sam.KnockoutPhase.LYING and sam.clip=="squash1" and absf(sam.knockout_remaining-3)<.02,"Only after SQUASH finishes does the three-second lying timer start")
	await advance(sam,2.98); actual_time+=2.98
	check(sam.state==sam.State.STUNNED and sam.clip=="squash1","Sam remains flattened for the full authored3000ms")
	if DisplayServer.get_name()!="headless":
		var camera=Camera3D.new(); level.add_child(camera); camera.current=true
		camera.position=GameSpace.original_point(Vector3(4117,-345,3810)); camera.look_at(sam.global_position+Vector3.UP*.45)
		root.size=Vector2i(1280,720)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level04_sam_crushed.png")
		camera.queue_free()
	await advance(sam,.04); actual_time+=.04
	check(sam.knockout_phase==sam.KnockoutPhase.GET_UP and sam.clip=="squash2","Timer expiry starts native3.83s SQUASH2 recovery, without enabling pursuit")
	await advance(sam,3.79); actual_time+=3.79
	check(sam.state==sam.State.STUNNED and sam.clip=="squash2","Sam cannot move/detect until the get-up animation fully ends")
	await advance(sam,.05); actual_time+=.05
	check(sam.state==sam.State.CHASE and sam.clip=="start","Recovery finishes before native SetGoalWolf resumes pursuit")
	print("Sam native KO:1.65s fall +3s lying +3.83s get-up; observed ",actual_time,"s including frame boundaries")
	sam.on_rock_crush(stone); sam.reset_guard()
	check(sam.state==sam.State.GUARD and sam.clip=="head2" and sam.global_position.is_equal_approx(sam.home),"Checkpoint reset restores a normal guard during KO")
	# The original dark interior faces remain; selective backface culling
	# prevents their coplanar reverse triangles from obscuring the exterior.
	check(stone.visual.legacy_skin.materials.all(func(m): return m.shader.resource_path.ends_with("retro_opaque_single_sided.gdshader")),"Fracture mesh uses native single-sided rendering, retaining interior faces")
	for key in ["fall1","explod1"]:
		stone.start_clip(key,stone.State.FALL if key=="fall1" else stone.State.SETTLE)
		stone._physics_process(.85 if key=="fall1" else .15)
		var bounds:AABB=stone.visual.skeleton.get_node("Visual").custom_aabb
		check(bounds.position.z<-5,"Animated %s bounds follow geometry beyond the old fixed4m limit"%key)
		var skin=stone.visual.legacy_skin
		for surface in stone.visual.rig.surfaces.values():
			for i in range(surface.verts.size()):
				var v=surface.verts[i]; var bone=int(surface.bones[i])
				var point=skin.last_matrices[bone]*skin.inverse_rests[bone]*Vector3(v[0],v[1],v[2])
				check(bounds.has_point(point),"Actual animated stone vertex lies inside render-culling bounds")
	stone.reset_to_home()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop();node.stream=null
	level.queue_free(); await process_frame
	print("Level04 Sam crush / native phases / stone material and bounds: ",failures," failures")
	quit(failures)
