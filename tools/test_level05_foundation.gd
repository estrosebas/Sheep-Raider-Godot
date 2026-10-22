extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)

func run():
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	GameLocalization.select("es",false)
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://level05_foundation_test_%d"%Time.get_ticks_usec()
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(50): await physics_frame
	check(level.manifest.level=="lvl_05" and level.entities.size()==74,"74 original Lv05 entities")
	check(level.get_node("WorldEnvironment").environment.background_color.to_html(false)=="302840","WAR05 backdrop matches source RGB used by the river gradient material")
	var gradient_edge_vertices = 0
	var terrain: ArrayMesh = level.get_node("Scenery").mesh
	for surface in range(terrain.get_surface_count()):
		if terrain.surface_get_name(surface)!="mat_page_-1": continue
		var arrays = terrain.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in range(points.size()):
			if points[i].y<0 and colors[i].to_html(false)=="302840": gradient_edge_vertices += 1
	check(gradient_edge_vertices>1500,"River's original untextured material terminates at the exact backdrop color without a seam")
	var shape: ConcavePolygonShape3D = level.get_node("Collision/CollisionShape3D").shape
	check(shape.get_faces().size()==7124*3 and level.get_node("Scenery").mesh.get_surface_count()>0,"Native terrain and editor-visible textured mesh")
	var cine = level.get_node("LevelCinematics")
	check(cine.intro_id==0 and cine.active_movie==cine.movies[0],"Native intro0 starts through entry controller")
	check(cine.movies[0].data.actors.is_empty() and not level.has_node("DaffyLessons"),"No invented Daffy dialogue on a camera-only level")
	if cine.movies[0].playing: cine.movies[0].finish_sequence(true)
	level.player.restart_fade_remaining = 0; level.player.restart_fade.set_amount(0)
	await create_timer(.2).timeout
	check(level.player.is_on_floor(),"Spawn rests on native terrain")
	check(level.get_node("Flock").sheep.size()==1,"Single native sheep is gameplay-active")
	check(level.get_node("Checkpoints").entries.size()==5,"Five native checkpoint entries")
	check(level.get_node("Sam_56").initialized,"Sam uses reusable guard logic")
	check(level.get_node("bull_60").grounded,"Bull starts on terrain")
	var environment = level.get_node("LevelEnvironment")
	check(not environment.rules.water.is_empty() and environment.fish.size()==1,"Shared swimming and native piranha hazard")
	check(level.get_node("Raft_47") is OriginalRaft and level.get_node("Raft_49") is OriginalRaft,"Two fan-driven rafts use native dimensions")
	check(level.get_node("TimeKeeper_61").level_id=="lvl_05" and level.get_node("Goal_96").level_id=="lvl_05","Clock and goal use persistent level05 identity")
	var mailbox = level.get_node("Mailbox_59")
	check(mailbox.items.size()==1 and mailbox.items[0] is OriginalElasticItem,"Native mailbox delivers elastic")
	check(level.get_node("Mailbox_58").items[0] is FanItem,"Other mailbox delivers fan")
	check(get_nodes_in_group("elastic_trees").size()==6,"Six original elastic anchor trees")
	var gate = level.get_node("FallingGate_72")
	check(gate.definition.directory.ends_with("gate_models/4"),"Gate swaps to AGRILL05 instead of placeholder model")
	var switch = level.get_node("SensibleButton_54")
	gate.set_switch(switch,true); gate._process(10)
	check(gate.opened,"Native button target opens alternate gate")
	gate.set_switch(switch,false); gate._process(10)
	check(not gate.opened,"Gate closes when released")
	var platform = level.get_node("RCarpetMobile_52")
	platform.set_physics_process(false)
	var home = platform.global_position
	platform.set_switch(level.get_node("SensibleButton_50"),true); platform._physics_process(1)
	check(is_equal_approx(platform.distance,4) and platform.global_position.distance_to(home)>3.9,"Native platform moves at 4 metres/s")
	platform.set_switch(level.get_node("SensibleButton_50"),false); platform._physics_process(1)
	check(platform.global_position.is_equal_approx(home),"Native platform returns after button release")
	platform.set_distance(2)
	var save = level.get_node("CheckpointSave"); save.capture_checkpoint()
	check(SaveFiles.valid(save.snapshot) and SaveFiles.write_slot(1,save.snapshot)==OK,"Level05 manual checkpoint save")
	platform.set_distance(0)
	check(save.restore_checkpoint(SaveFiles.read_slot(1)) and is_equal_approx(platform.distance,2),"Checkpoint restores moving platform position")
	check(SaveFiles.scene_for_level("lvl_05").ends_with("Level05.tscn"),"Studio detects imported level scene")
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1280,720)
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = Camera3D.new(); level.add_child(camera)
		camera.position = Vector3(48,42,43); camera.look_at(Vector3(-12,1,-22)); camera.current = true
		for i in range(5): await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/level05_overview.png")
	level.queue_free(); await process_frame
	print("Level05 foundation: ",failures," failures")
	quit(failures)
