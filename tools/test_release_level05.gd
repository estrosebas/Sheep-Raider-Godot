extends SceneTree
# Cold-start smoke for an actual signed, compiled content pack.
# Use an isolated --updates-test-config; never a player's update/save cache.
var failures = 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var client = root.get_node("ContentUpdates")
	check(client.mounted and client.current_sequence()==4,"Signed1.0.5 sequence4 mounted before gameplay autoloads")
	check(client.active.get("content_version","")=="1.0.5","Signed payload identifies the intended release")
	check(FileAccess.file_exists("res://scripts/player/ralph_controller.gd.remap"),"Gameplay uses exported compiled scripts")
	SaveFiles.startup_offered = true; SaveFiles.pending = {}
	SaveFiles.directory = "user://release105_test_%d"%Time.get_ticks_usec()
	OriginalProgress.restore({}); GameLocalization.select("es",false)
	var help = get_first_node_in_group("first_run_help")
	if help: help.automatic = false
	var level = load("res://scenes/levels/Level05.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in range(25): await physics_frame
	var movie = level.get_node("LevelCinematics").active_movie
	if movie: movie.finish_sequence(true)
	var actor = level.player
	actor.restart_fade_remaining = 0; actor.restart_fade.set_amount(0)
	check(level.manifest.level=="lvl_05" and level.entities.size()==74,"New level data and all74 native entities are packed")
	check(level.get_node_or_null("ClimbZone_0")!=null,"Native vine region is present in the exported build")
	for name in ["climb_up","climb_down","climb_left","climb_right","climb_idle"]:
		check(actor.animation_player.has_animation(name),"Compiled climbing animation: "+name)
	check(ResourceLoader.exists("res://assets/audio/sfx/climb_40.wav"),"Original grip loop is imported into the package")
	check(is_equal_approx(level.get_node("WorldEnvironment").environment.background_color.r,48.0/255),"River backdrop is included")
	var elastic = level.get_node("elastic_86").controller
	elastic.tie_first(level.get_node("ElasticTree_62"),actor)
	elastic.tree_b = level.get_node("ElasticTree_67"); elastic.mode = "strung"
	check(elastic.projection_for(actor).distance==40,"Clock access balance survives compilation and packaging")
	actor.global_position = Vector3(1,-3.98,-22.7); actor.velocity = Vector3.ZERO
	actor.set_state(actor.WolfState.FALL); await physics_frame
	var zone = level.get_node("ClimbZone_0")
	check(zone.interact(actor) and actor.current_state==actor.WolfState.CLIMB,"Compiled controller can acquire the native vines")
	actor.climb_motion.release(actor,false)
	check(not actor.climb_motion.active(),"Compiled controller releases cleanly")
	client.confirm_boot()
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.queue_free(); await process_frame
	print("Signed1.0.5 / compiled Level05 / climbing / elastic / native assets: ",failures," failures")
	quit(failures)
