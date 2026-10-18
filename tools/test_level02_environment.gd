extends SceneTree
var failures = 0
func _init(): call_deferred("run")
func check(value: bool,message: String):
	if not value: failures += 1; printerr(message)
func run():
	SaveFiles.startup_offered = true; SaveFiles.pending = {}; GameLocalization.select("es",false)
	var level = load("res://scenes/levels/Level02.tscn").instantiate(); root.add_child(level); current_scene = level
	await create_timer(.3).timeout
	var player = level.player; player.set_physics_process(false); player.set_process(false)
	var lessons = level.get_node("DaffyLessons"); lessons.set_process(false)
	var environment = level.get_node("LevelEnvironment"); environment.set_physics_process(false)
	level.get_node("Sam_51").set_physics_process(false)
	player.global_position = Vector3(7,0,-45); lessons._process(.3)
	check(lessons.active_movie==null,"Lucas leaves a two-metre clearance after the initial rock")
	player.global_position = Vector3(9,0,-45); player.push_target = level.get_node("Rock_49"); lessons._process(.3)
	check(lessons.active_movie==null,"Lucas does not interrupt active rock pushing even past the clearance")
	player.push_target = null; player.tutorial_movement_locked = false; lessons._process(.3)
	check(lessons.active_movie != null,"Two metres beyond the old trigger and after pushing finishes, Lucas starts the tutorial")
	lessons.movies[1].finish_sequence(true); await process_frame
	lessons.menu.hide(); player.cinematic_controls_locked = false
	lessons.intro_finished = true; lessons.introduction_seen = true
	player.global_position = lessons.daffy.global_position+Vector3(5,0,0); player.velocity = Vector3.RIGHT; player.set_state(player.WolfState.SNEAK)
	lessons.head_yaw = 0; check(lessons.detect_player()==0,"Side-on sneaking Ralph is outside the visual cone")
	lessons._watch_head(0); check(absf(lessons.portrait.rotation.y)>1,"HUD head turns sideways relative to Ralph instead of falsely showing a frontal view")
	player.set_state(player.WolfState.WALK); check(lessons.detect_player()==3,"Walking sideways triggers hearing, independently of vision, as in the source")
	var fish = environment.fish[0]; var before: Vector3 = fish.visual.global_position
	environment._physics_process(.2)
	check(fish.visual.global_position.distance_to(before)>.1 and fish.visual.rig.animations.has("pirana1"),"Piranhas swim along native water zones with original swim and bite clips")
	var scrolling = level.get_node("TextureScroll")
	check(scrolling.regions.size()==8 and scrolling.pages.size()>0,"Eight original river atlas regions are animated")
	check(level.find_children("WaterSpray*","",false,false).size()>0,"River structures have water spray emitters")
	var shape: CollisionShape3D = environment.seesaw.get_child(0)
	check(shape.shape is BoxShape3D and shape.shape.size.x>8 and shape.shape.size.z>1,"Seesaw uses native nine-metre contact box despite non-solid source flag")
	var board = environment.seesaw
	var hit = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(board.global_position+Vector3.UP*3,board.global_position+Vector3.DOWN))
	check(not hit.is_empty() and hit.collider == board,"A real physics ray hits the seesaw's playable surface")
	var lettuce = level.get_node("Salad_74")
	check(lettuce.original_visual.idle_clip=="objet" and lettuce.original_visual.animation_player.assigned_animation=="objet","Lettuce spawns in native Salad OBJET pose rather than the tilted STAND pose")
	check(lettuce.rotation.is_equal_approx(Vector3.ZERO) and lettuce.original_visual.rig.get("rotation_order","")=="ZXY","Lettuce uses unrotated source entity and corrected native bone convention")
	player.global_position = Vector3(-10,-7,15); player.set_state(player.WolfState.FALL); player.velocity = Vector3.DOWN
	check(not player.check_void_below(),"A missing floor ray over native water cannot replace piranha death with a void fall")
	player.water_motion.step(player,.01)
	environment._physics_process(.01)
	check(not environment.attack.is_empty() and not player.cinematic_controls_locked and player.current_state==player.WolfState.SWIM,"Water entry starts shared swimming without freezing Ralph during the attack delay")
	player.water_motion.step(player,.5); environment._physics_process(.5)
	check(not environment.attack.biting and player.current_state==player.WolfState.SWIM,"Piranha does not attack during the first half second of immersion")
	player.water_motion.step(player,.51)
	environment._physics_process(1.01)
	check(player.animation_player.current_animation=="piranha_death" and player.death_animation_override=="piranha_death","Water attack uses Ralph PIRANA1 rather than normal void death")
	check(environment.attack.visual.animation_player.current_animation=="pirana1","Fish uses original matching bite animation")
	check(player.camera.get_parent()==level and player.camera.global_position.distance_to(player.global_position)<6,"Piranha death gets a close fixed camera outside the spring arm")
	# The native sounds belong to PIRANA1's fish track, not Ralph's empty cue list.
	for audio in player.animation_sfx_players: audio.stop()
	environment._physics_process(.6) # Existing bite time ~1.01 -> crosses 1.50.
	check(player.animation_sfx_players.any(func(audio): return audio.playing and audio.stream.resource_path.ends_with("/77.wav")),"Piranha bite fires original sound77 at 1.50 seconds")
	environment._physics_process(.8)
	check(player.animation_sfx_players.any(func(audio): return audio.playing and audio.stream.resource_path.ends_with("/138.wav")),"Piranha bite fires original water sound138 at 2.34 seconds")
	player.respawn_at_checkpoint(); player.restart_fade_remaining = 0
	check(player.water_motion.zone.is_empty(),"Respawn clears shared water state")
	player.global_position = Vector3(-10,-7.2,15)
	for i in range(120): player.water_motion.step(player,.016)
	check(player.current_state==player.WolfState.SWIM and player.animation_player.current_animation in ["swim2","swim4"],"Shared water controller supports safe sustained swimming/wading when no hazard is stepped")
	player.global_position = Vector3(100,1,100); player.water_motion.step(player,.016)
	check(player.current_state==player.WolfState.FALL and player.water_motion.zone.is_empty(),"Leaving a water region restores normal falling")
	player.global_position = Vector3(-10,-6.2,15); player.velocity = Vector3(0,-30,0)
	var entry_height = player.global_position.y
	for i in range(65):
		player.water_motion.step(player,1.0/60)
		environment._physics_process(1.0/60)
		await physics_frame
	check(player.global_position.y<entry_height-1 and not environment.attack.is_empty() and environment.attack.biting,"High entry preserves fall momentum, submerges Ralph and triggers piranha after one second")
	player.respawn_at_checkpoint(); player.restart_fade_remaining = 0
	player.global_position = Vector3(-10,-8,15); player.velocity = Vector3.ZERO
	player.water_motion.step(player,.016); player.water_motion.sinking = false
	var swim_height = player.global_position.y
	Input.action_press("run")
	for i in range(30): player.water_motion.step(player,1.0/60); await physics_frame
	Input.action_release("run")
	check(player.global_position.y<swim_height-.2,"Shift moves the swimmer down")
	swim_height = player.global_position.y; player.velocity.y = 0
	Input.action_press("jump")
	for i in range(60): player.water_motion.step(player,1.0/60); await physics_frame
	Input.action_release("jump")
	check(player.global_position.y>swim_height+.5 and player.current_state==player.WolfState.SWIM,"Space moves the swimmer up without switching to jumping")
	player.respawn_at_checkpoint(); player.restart_fade_remaining = 0
	var camera_parent = player.camera.get_parent()
	player.set_state(player.WolfState.FALL); player.set_state(player.WolfState.PIT_FALL)
	var view = player.camera.global_transform
	player.global_position += Vector3(4,-15,2)
	await physics_frame; await physics_frame
	check(player.camera.global_transform.is_equal_approx(view),"Direct fall camera remains fixed after SpringArm internal updates and player motion")
	player.respawn_at_checkpoint(); player.restart_fade_remaining = 0
	check(player.camera.get_parent()==camera_parent and not player.camera.top_level,"Respawn restores camera to its original spring arm")
	var perfume = level.get_node("Perfume_77") if level.has_node("Perfume_77") else level.get_node("Mailbox_67").items[0]
	var fan = level.get_node("Mailbox_66").items[0]
	var sheep = level.get_node("Flock").sheep[0]
	perfume.global_position = sheep.home-Vector3(0,0,10); perfume.active = true; perfume.deployed = true; perfume.available = true; perfume.show()
	player.global_position = perfume.global_position-Vector3(0,0,2); player.skeleton.rotation = Vector3.ZERO
	fan.equip_to(player); fan.active = true
	for i in range(100):
		# Perfume-before-fan is the problematic real sibling order.
		perfume.item_step(.05); fan.item_step(.05); perfume.scent._process(.05)
	check(perfume.blow_time>4 and perfume.wind_this_frame and perfume.can_smell_from(sheep.home),"Fan propagates perfume to sheep with either update order")
	check(perfume.scent.emitted_total>0,"Perfume emits original visible scent sprites")
	level.get_node("Flock")._physics_process(.016)
	check(level.get_node("Flock").reservations.has(perfume),"Real level02 flock reacts to blown perfume")
	for node in level.find_children("*","AudioStreamPlayer",true,false)+level.find_children("*","AudioStreamPlayer3D",true,false): node.stop(); node.stream = null
	level.process_mode = Node.PROCESS_MODE_DISABLED; level.queue_free(); await process_frame
	print("Level02 environment fixes: ",failures," failures"); quit(failures)
