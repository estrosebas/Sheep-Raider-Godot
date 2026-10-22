extends "res://scripts/items/sheep_item_receiver.gd"
class_name OriginalSheep

var definition: Dictionary
var carried_by: RalphController
var visual: OriginalCinematicActor
var hint: Label3D
var respawn_position: Variant = null
var home: Vector3
var carry_heading = 0.0
var flock: OriginalFlock
var flock_target: Node3D
var flock_phase = "idle"
var flock_timer = 0.0
var button_think_timer = 0.0
var button_think_due = false
var last_food_position: Variant = null
var idle_cycles = 0
var sheep_audio: AudioStreamPlayer3D
var sleepy = false
var sleeping_visual: OriginalCinematicActor
var sleep_think = 0.0
var idle_loops = 6
var carry_controller: OriginalSheepCarry
var dead = false
var death_time = 0.0
var last_floor_y = 0.0
var seesaw_support: OriginalSeesaw
var moving_anchor: Node3D
var moving_anchor_radius = .5
var anchor_floor_layers = -1
var anchor_on_leave = -1
var seesaw_arc: Dictionary = {}
var launch_board: OriginalSeesaw
var goal_putdown_target: Variant = null
var scent_reaction = preload("res://scripts/actors/original_sheep_scent.gd").new()
# Native joint18/-7 attachment; carry pose supplies the height.
@export var carry_visual_lift = 0.0
@export_file("*.tscn") var visual_scene = "res://assets/items/sheep/worn.tscn"
@export var idle_animation = "stand1"
@export_file("*.tscn") var sleeping_scene = "res://assets/levels/lvl_01/sheep_sleep/worn.tscn"

func _ready() -> void:
	super._ready()
	add_to_group("grounded_npcs")
	add_to_group("world_interactables")
	add_to_group("blast_targets")
	process_priority = 110
	# Raft transport (priority50) precedes sheep AI and floor resolution.
	process_physics_priority = 100
	visual = load(visual_scene).instantiate()
	add_child(visual)
	visual.idle(idle_animation)
	var shape = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	# Native model1 collision record: (-35,-80,-35)..(35,0,35).
	box.size = Vector3(.7,.8,.7)
	shape.shape = box
	shape.position.y = .4
	add_child(shape)
	hint = Label3D.new()
	hint.text = "E · Cargar oveja"
	hint.position.y = 1.2
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.pixel_size = .005
	add_child(hint)
	hint.hide()
	home = position
	last_floor_y = global_position.y
	call_deferred("snap_to_ground")
	sheep_audio = AudioStreamPlayer3D.new()
	sheep_audio.max_distance = 20
	add_child(sheep_audio)
	sleepy = int(definition.get("props",{}).get("0x0",0)) & 1 != 0
	if sleepy:
		sleeping_visual = load(sleeping_scene).instantiate()
		add_child(sleeping_visual)
		sleeping_visual.idle("sleep1")
		sleeping_visual.idle_time = randf()*float(sleeping_visual.rig.animations.sleep1.duration)
		sleep_think = randf()
		visual.hide()

func snap_to_ground() -> void:
	# Imported entities receive their authored transform after add_child/_ready.
	# A first-frame ray can miss before physics registers the scenery; the home
	# must still be the actual spawn rather than the temporary origin (0,0,0).
	home = global_position
	last_floor_y = global_position.y
	var ray = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position-Vector3.UP*20)
	ray.collision_mask = 1
	var exclusions: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("grounded_npcs"): exclusions.append(actor.get_rid())
	ray.exclude = exclusions
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = hit["position"].y+.001
		home = global_position

func can_interact(actor: RalphController) -> bool:
	if dead or not seesaw_arc.is_empty(): return false
	if not actor.can_use_item(): return false
	if carried_by == actor: return actor.is_on_floor()
	if is_instance_valid(carried_by) or not actor.is_on_floor(): return false
	if flock and flock.restricted(self): return false
	if is_instance_valid(actor.inventory.equipped_node): return false
	var difference = global_position-actor.global_position
	var horizontal = Vector2(difference.x,difference.z).length()
	return horizontal <= 1.25 and absf(difference.y) <= .8 and (horizontal < .05 or actor.item_facing().dot(Vector3(difference.x,0,difference.z).normalized()) >= 0)

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	if carried_by == actor:
		return actor.item_actions.begin([
			{"clip":"sheep_drop","enter":func(): visual.idle("stand2"),"exit":func():
				var placement = OriginalPlacement.probe(actor,self,false)
				if placement.is_empty():
					visual.idle("stand8")
					actor.item_actions.stages[actor.item_actions.index+1] = {"clip":"sheep_carry_idle","duration":.25}
					return
				drop()
				global_position = placement.position},
			{"clip":"sheep_drop_end"}])
	return actor.item_actions.begin([
		{"clip":"sheep_lift","enter":func(): actor.item_actions.face(global_position),"exit":func():
			clear_moving_anchor()
			carry_heading = rotation.y-actor.skeleton.rotation.y
			carried_by = actor
			actor.carried_sheep = self
			carry_controller = OriginalSheepCarry.new()
			if sleeping_visual: sleeping_visual.hide()
			visual.show()
			sheep_audio.stop()
			add_collision_exception_with(actor)
			get_node("CollisionShape3D").set_deferred("disabled",true)
			visual.idle("stand2")},
		{"clip":"sheep_lift_end"}])

func move_carrier(delta: float) -> void:
	if not is_instance_valid(carried_by): return
	if not carry_controller: carry_controller = OriginalSheepCarry.new()
	carry_controller.step(self,delta)

func drop() -> void:
	if not is_instance_valid(carried_by): return
	var actor = carried_by
	actor.carried_sheep = null
	carried_by = null
	carry_controller = null
	global_position = actor.global_position+actor.item_facing()*.85
	rotation.y = actor.skeleton.rotation.y+carry_heading
	velocity = Vector3.ZERO
	visual.idle("stand1")
	remove_collision_exception_with(actor)
	get_node("CollisionShape3D").set_deferred("disabled",false)

func set_moving_anchor(support: Node3D,radius: float):
	# Sheep::MSG_SET_ANCHOR; preserve the level's respawn/home position.
	if not support is OriginalRaft and anchor_floor_layers>=0: clear_moving_anchor()
	if support is OriginalRaft:
		# Raft applies Translate explicitly; suppress Godot's second platform
		# displacement, including inherited velocity on stepping off the deck.
		if anchor_floor_layers<0:
			anchor_floor_layers = platform_floor_layers
			anchor_on_leave = platform_on_leave
		platform_floor_layers = 0
		platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	moving_anchor = support; moving_anchor_radius = radius

func clear_moving_anchor():
	moving_anchor = null
	if anchor_floor_layers>=0:
		platform_floor_layers = anchor_floor_layers
		platform_on_leave = anchor_on_leave
		anchor_floor_layers = -1; anchor_on_leave = -1

func reset_to_home() -> void:
	clear_moving_anchor()
	clear_seesaw_launch()
	seesaw_support = null
	scent_reaction.reset(self)
	dead = false
	death_time = 0
	get_node("CollisionShape3D").set_deferred("disabled",false)
	OriginalBurntTint.apply(visual.legacy_skin,false)
	if is_instance_valid(carried_by): drop()
	global_position = respawn_position if respawn_position != null else home
	last_floor_y = global_position.y
	velocity = Vector3.ZERO
	flock_target = null
	last_food_position = null
	flock_phase = "idle"
	if sheep_audio: sheep_audio.stop()
	if visual: begin_random_idle(true)

func goal_position() -> Vector3:
	# Attached ScnObjects retain the carrier's gameplay position, not render height.
	return carried_by.global_position if is_instance_valid(carried_by) else global_position

func _physics_process(delta: float) -> void:
	if dead:
		_step_death(delta)
		return
	if not seesaw_arc.is_empty():
		clear_moving_anchor()
		step_seesaw_launch(delta)
		return
	if is_instance_valid(seesaw_support):
		if carried_by or not seesaw_support.covers(global_position,.35) or absf(global_position.y-seesaw_support.sheep_surface_height(self))>.6:
			seesaw_support = null
		else:
			rest_on_seesaw(seesaw_support)
	if not carried_by and _check_fatal_drop(): return
	if is_instance_valid(carried_by): return
	if is_instance_valid(moving_anchor) and not moving_anchor.is_rider(self): clear_moving_anchor()
	if not flock:
		var perfume: PerfumeItem
		var nearest = INF
		for source in get_tree().get_nodes_in_group("sheep_attractors"):
			if source is PerfumeItem and source.can_smell_from(global_position):
				var distance = global_position.distance_squared_to(source.global_position)
				var closest = true
				for other in get_tree().get_nodes_in_group("sheep_targets"):
					if other == self or not other is OriginalSheep or other.dead or other.sleepy or other.carried_by: continue
					if source.can_smell_from(other.global_position) and other.global_position.distance_squared_to(source.global_position)<distance: closest = false; break
				if closest and distance < nearest: nearest = distance; perfume = source
		if scent_reaction.step(self,perfume,delta): return
		super._physics_process(delta)
		# The laboratory receiver moves physically but does not select a rig clip.
		if is_instance_valid(attraction_target) and attraction_target.is_in_group("bushes"):
			flock_target = attraction_target
			flock_phase = "approach" if Vector2(velocity.x,velocity.z).length()>.05 else "eat"
			var clip = "walk3" if flock_phase=="approach" else "stand1"
			if visual.idle_clip != clip: visual.idle_speed = 1.0; visual.idle(clip)
		elif is_instance_valid(flock_target) and flock_target.is_in_group("bushes"):
			flock_target = null; flock_phase = "idle"; visual.idle(idle_animation)
		return
	if flock.guard.player.cinematic_controls_locked: return
	if sleepy:
		if sleeping_visual: sleeping_visual.show()
		visual.hide()
		velocity = Vector3(0,0 if is_on_floor() else maxf(-20,velocity.y-29*delta),0)
		move_and_slide()
		sleep_think += delta
		if sleep_think >= 1.0:
			sleep_think = 0
			if sheep_audio.playing:
				if randi_range(0,1) == 0: sheep_audio.stop()
			elif randi_range(0,15) == 0: _play_flock_sound(274,true)
		return
	flock_timer += delta
	call_time = maxf(0,call_time-delta)
	var target = flock.attraction(self)
	if target is PerfumeItem:
		flock_target = target
		flock.release_idle_variant(self)
		scent_reaction.step(self,target,delta)
		return
	scent_reaction.reset(self)
	if target != flock_target:
		flock_target = target
		flock.release_idle_variant(self)
		visual.idle_speed = 1.0
		if not target: last_food_position = null
		flock_phase = ("approach" if last_food_position != null else "smell") if target else "idle"
		flock_timer = 0
		sheep_audio.stop()
		visual.idle(("walk1" if last_food_position != null else "smel1") if target else idle_animation)
		if target is OriginalPressureButton or (is_instance_valid(target) and target.is_in_group("bushes")):
			flock_phase = "button_turn"
			visual.idle_speed = randi_range(12,20)/16.0
			visual.idle("walk1") # Native ATTR_TURN, in place.
	var destination = global_position
	if is_instance_valid(flock_target):
		if flock_target is OriginalPressureButton or flock_target.is_in_group("bushes"):
			var facing = flock_target.global_position-global_position
			rotation.y = lerp_angle(rotation.y,atan2(facing.x,facing.z),minf(1,TAU*delta))
			var clip_duration = float(visual.rig.animations[visual.idle_clip].duration)/visual.idle_speed
			if flock_phase == "button_turn" and flock_timer >= clip_duration:
				flock_phase = "button_look"; flock_timer = 0
				visual.idle_speed = randi_range(16,20)/16.0; visual.idle("stand2")
			elif flock_phase == "button_look" and flock_timer >= clip_duration:
				flock_phase = "approach"; flock_timer = 0
				visual.idle_speed = randi_range(12,20)/16.0; visual.idle("walk3")
		if flock_phase == "smell" and flock_timer >= float(visual.rig["animations"]["smel1"]["duration"]):
			flock_phase = "approach"
			visual.idle("walk1")
		if flock_phase in ["approach","eat","button_stand"]: destination = flock_target.scent_position()
	elif call_time > 0 and is_instance_valid(call_actor) and not flock.restricted(self):
		destination = call_actor.global_position
		flock_phase = "approach"
	elif flock_phase == "idle" and flock_timer > float(visual.rig["animations"][visual.idle_clip]["duration"])/visual.idle_speed:
		flock_timer = 0
		idle_loops -= 1
		if idle_loops <= 0:
			if visual.idle_clip == idle_animation:
				if flock.claim_idle_variant(self):
					var variant = ["stand4","bah"][randi_range(0,1)]
					idle_loops = randi_range(1,3) if variant == "stand4" else randi_range(1,2)
					visual.idle_speed = randi_range(12,20)/16.0
					visual.idle(variant)
					if variant == "bah":
						sheep_audio.stream = preload("res://assets/items/audio/sheep_bleat.wav")
						sheep_audio.play()
				else:
					idle_loops = 1 # Retry at a later idle-loop boundary, never as a queue.
			else:
				flock.release_idle_variant(self)
				begin_random_idle(false)
	var on_moving_anchor = is_instance_valid(moving_anchor) and moving_anchor.is_rider(self)
	if not on_moving_anchor: clear_moving_anchor()
	if on_moving_anchor and not is_instance_valid(flock_target) and call_time<=0:
		var anchor_difference = moving_anchor.global_position-global_position; anchor_difference.y = 0
		if anchor_difference.length()>moving_anchor_radius:
			destination = moving_anchor.global_position; flock_phase = "return"
			if visual.idle_clip!="walk3": visual.idle("walk3")
	elif not is_instance_valid(flock_target) and call_time <= 0 and flock_timer > 2 and OriginalSam.contains(global_position,flock.guard.rules["orange"]) and Vector2(global_position.x-home.x,global_position.z-home.z).length() > .1:
		flock_phase = "return"
		destination = home
		if visual.idle_clip != "walk3": visual.idle("walk3")
	var direction = destination-global_position
	direction.y = 0
	# Original eating radius is 80 units; allow the capsule's contact margin
	# so adjacent flock members cannot leave a sheep walking against them forever.
	var stop_distance = .9 if is_instance_valid(flock_target) else (.1 if flock_phase == "return" else 1.0)
	if on_moving_anchor and flock_phase=="return" and not is_instance_valid(flock_target): stop_distance = moving_anchor_radius
	if flock_target is OriginalPressureButton: stop_distance = .05 # BUTTON_WALK reaches the centre, not eating distance.
	var approaching_bush = is_instance_valid(flock_target) and flock_target.is_in_group("bushes")
	if approaching_bush: stop_distance = 1.2 # Sheep::ATTR_WALK / EAT_BUSH:120 native units.
	if flock_target is OriginalPressureButton and flock_phase == "approach" and direction.length()<=1 and visual.idle_clip != "walk1":
		visual.idle_speed = randi_range(8,24)/16.0; visual.idle("walk1") # Native final BUTTON_WALK.
	if direction.length() > stop_distance:
		direction = direction.normalized()
		rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,TAU*delta))
		velocity.x = direction.x*movement_speed
		velocity.z = direction.z*movement_speed
		if flock_phase == "approach" and not flock_target is OriginalPressureButton:
			var clip = "walk3" if approaching_bush else "walk1"
			if visual.idle_clip != clip: visual.idle(clip)
	else:
		velocity.x = 0
		velocity.z = 0
		if is_instance_valid(flock_target) and flock_phase in ["approach","eat","button_stand"]:
			if flock_target is OriginalPressureButton:
				if flock_phase != "button_stand": flock_timer = 0
				flock_phase = "button_stand"
				if visual.idle_clip != "stand2":
					visual.idle_speed = randi_range(12,20)/16.0
					visual.idle("stand2")
				sheep_audio.stop()
			else:
				flock_phase = "eat"
				if visual.idle_clip != "stand1": visual.idle("stand1") # SHEEP_ST_EAT -> mapped animation2.
				if not sheep_audio.playing: _play_flock_sound(61,true)
				if flock_target.has_method("eat") and flock_target.eat(delta):
					last_food_position = flock_target.scent_position()
		elif flock_phase == "return":
			flock_phase = "idle"
			flock_timer = 0
			visual.idle(idle_animation)
	velocity.y = 0 if is_on_floor() else maxf(-20,velocity.y-29*delta)
	move_and_slide()
	if is_on_floor(): last_floor_y = global_position.y

func on_blast(_origin: Vector3) -> void:
	lose("burn")

func _check_fatal_drop() -> bool:
	for zone in get_tree().get_nodes_in_group("original_fall_zones"):
		if zone.get_parent() != get_parent(): continue
		if global_position.x >= zone.minimum.x and global_position.x <= zone.maximum.x and global_position.z >= zone.minimum.y and global_position.z <= zone.maximum.y and global_position.y < zone.fall_height:
			lose("fall")
			return true
	if is_on_floor(): last_floor_y = global_position.y
	if global_position.y >= last_floor_y-1.3: return false
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.1,global_position-Vector3.UP*30)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		lose("fall")
		return true
	return false

func lose(cause: String) -> void:
	if dead: return
	clear_moving_anchor()
	clear_seesaw_launch()
	seesaw_support = null
	if is_instance_valid(carried_by):
		var carrier = carried_by
		carrier.item_actions.cancel()
		drop()
	dead = true
	death_time = 0
	flock_target = null
	velocity = Vector3.ZERO
	if sleeping_visual: sleeping_visual.hide()
	visual.show()
	OriginalBurntTint.apply(visual.legacy_skin,cause == "burn")
	visual.idle("stand2")
	set_meta("death_cause",cause)
	if cause == "fall": get_node("CollisionShape3D").set_deferred("disabled",true)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_world_3d() == get_world_3d():
		if player.current_state not in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]:
			player.interrupt_actions()
			player.tutorial_movement_locked = true

func _step_death(delta: float) -> void:
	death_time += delta
	var duration = 7.0 if get_meta("death_cause","") == "fall" else 3.0
	if get_meta("death_cause","") == "fall":
		velocity.y = maxf(-20,velocity.y-29*delta)
		move_and_slide()
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	player.restart_fade.set_iris(true)
	player.restart_fade.set_amount(clampf(death_time-(duration-1),0,1))
	if death_time >= duration:
		player.tutorial_movement_locked = false
		player.respawn_at_checkpoint()
		player.restart_fade_remaining = OriginalRestartFade.DURATION
		player.restart_fade.set_amount(1)
		if dead: reset_to_home()

func _play_flock_sound(identity: int, looping: bool) -> void:
	if not flock: return
	var path: String = flock.guard.sounds.get(str(identity),"")
	if path.is_empty(): return
	var stream: AudioStreamWAV = load(path).duplicate()
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	sheep_audio.stream = stream
	sheep_audio.play()

func _process(_delta: float) -> void:
	var actor = get_tree().get_first_node_in_group("player")
	hint.visible = false
	hint.text = "E · Dejar oveja" if carried_by else "E · Cargar oveja"
	if is_instance_valid(carried_by):
		visual.idle_speed = 1.0
		var matrices = carried_by.legacy_skin.last_matrices
		var root = carried_by.skeleton.global_transform*matrices[0]
		var hand = carried_by.skeleton.global_transform*matrices[18]
		var basis = root.basis*GameSpace.EXPORT_TO_GODOT
		var lift = carry_visual_lift
		var clip = carried_by.animation_player.current_animation
		if clip in ["sheep_drop","sheep_lift_end"]:
			var progress = clampf(carried_by.animation_player.current_animation_position/carried_by.animation_player.get_animation(clip).length,0,1)
			lift *= (1-progress) if clip == "sheep_drop" else progress
		global_transform = Transform3D(basis.rotated(basis.y.normalized(),carry_heading),hand.origin+basis*Vector3(0,-.07,0)+Vector3.UP*lift)
		if goal_putdown_target != null and clip=="sheep_drop":
			var progress = clampf(carried_by.animation_player.current_animation_position/carried_by.animation_player.get_animation(clip).length,0,1)
			global_position = global_position.lerp(goal_putdown_target,smoothstep(.55,1.0,progress))

func put_down_at_goal(done: Callable) -> bool:
	if not is_instance_valid(carried_by): return false
	var actor = carried_by
	var placement = OriginalPlacement.probe(actor,self,false)
	if placement.is_empty(): placement = OriginalPlacement.probe(actor,self,true)
	# Victory guarantees both actors reached the authored safe goal. If the
	# facing edge is blocked, put down on Ralph's supporting floor instead.
	var destination: Vector3 = placement.position if not placement.is_empty() else actor.respawn_ground_position(actor.global_position)+Vector3.UP*.005
	goal_putdown_target = destination
	var started = actor.item_actions.begin([
		{"clip":"sheep_drop","enter":func(): visual.idle("stand2"),"exit":func():
			drop(); global_position = destination; goal_putdown_target = null},
		{"clip":"sheep_drop_end"}],Callable(),done)
	if not started: goal_putdown_target = null
	return started

func begin_random_idle(initial: bool):
	# Sheep::EnterIdleState / NextIdleAnim: independent 12..20 /16 speed,
	# 5..10 initial loops, then 3..6 base loops between idle variants.
	if flock: flock.release_idle_variant(self)
	visual.idle(idle_animation)
	visual.idle_speed = randi_range(12,20)/16.0
	idle_loops = randi_range(5,10) if initial else randi_range(3,6)
	visual.idle_time = randf()*float(visual.rig.animations[idle_animation].duration) if initial else 0.0
	flock_timer = visual.idle_time/visual.idle_speed
	visual.sample_animation(idle_animation,visual.idle_time,true)

func rest_on_seesaw(board: OriginalSeesaw):
	seesaw_support = board
	global_position.y = board.sheep_surface_height(self)+.002
	last_floor_y = global_position.y
	velocity.y = 0

func launch_from_seesaw(board: OriginalSeesaw,points: Array,rock_impact: bool):
	if dead or carried_by or not seesaw_arc.is_empty(): return
	clear_moving_anchor()
	seesaw_support = null
	scent_reaction.reset(self)
	if flock: flock.release_idle_variant(self)
	flock_target = null; last_food_position = null; call_time = 0
	flock_phase = "launched"
	sheep_audio.stop()
	# g_sheepStateTable[32]: SHEEP_ST_LAUNCHED uses STAND1.
	visual.idle_speed = 1.0; visual.idle("stand1")
	var middle = OriginalSeesaw.source_point(points[1]) if rock_impact else global_position+Vector3.UP*3
	var end = OriginalSeesaw.source_point(points[2]) if rock_impact else Vector3(global_position.x,board.global_position.y,global_position.z)
	seesaw_arc = {"time":0.0,"start":global_position,"middle":middle,"end":end}
	velocity = Vector3.ZERO
	# Leave the launching plank cleanly; retain terrain/wall collision in flight.
	launch_board = board
	add_collision_exception_with(board)

func step_seesaw_launch(delta: float):
	# Restore plank collision once airborne so the wolf's vertical hop can
	# land back on it rather than passing through on its downward leg.
	if is_instance_valid(launch_board) and global_position.y > launch_board.sheep_surface_height(self)+.25:
		remove_collision_exception_with(launch_board)
		launch_board = null
	seesaw_arc.time += delta
	var target = OriginalSeesaw.arc_point(seesaw_arc.start,seesaw_arc.middle,seesaw_arc.end,minf(seesaw_arc.time/1.024,1))
	var motion = target-global_position
	var contact = move_and_collide(motion)
	if seesaw_arc.time >= 1.024 or contact:
		clear_seesaw_launch()
		velocity = Vector3.ZERO
		last_floor_y = global_position.y
		flock_phase = "idle"; flock_timer = 0
		begin_random_idle(false)

func clear_seesaw_launch():
	seesaw_arc.clear()
	if is_instance_valid(launch_board): remove_collision_exception_with(launch_board)
	launch_board = null
