extends CharacterBody3D

var definition: Dictionary
var visual_scene = ""
var visual: Node3D
var home: Vector3
var pushing_actor: RalphController
var push_direction = Vector3.ZERO
var push_speed = 0.0
var radius = .85
var roll = Basis.IDENTITY
var sound: AudioStreamPlayer3D
var sound_path = ""
var arc: Dictionary = {}
var fall_time = 0.0
var landed_speed = 0.0
var seesaw_support: Node3D
var box_delivered = false
var movie_active = false
var impact_sound: AudioStreamPlayer3D
var impact_sound_path = ""

func _ready() -> void:
	add_to_group("world_interactables")
	add_to_group("pushable_rocks")
	visual = load(visual_scene).instantiate()
	add_child(visual)
	var shape = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	radius = (float(definition.box.max[0])-float(definition.box.min[0]))*.005
	shape.shape.radius = radius
	add_child(shape)
	floor_snap_length = .4
	sound = AudioStreamPlayer3D.new()
	add_child(sound)
	impact_sound = AudioStreamPlayer3D.new(); add_child(impact_sound)
	call_deferred("remember_home")
func remember_home(): home = global_position

func can_interact(actor: RalphController) -> bool:
	if not arc.is_empty() or is_instance_valid(seesaw_support): return false # ROCK_ST_ON_SEESAW is not pushable.
	if not actor.can_use_item() or actor.carried_sheep or not actor.is_on_floor(): return false
	if not (definition.props["0x4"] or definition.props["0x8"]): return false
	var difference = global_position-actor.global_position
	return Vector2(difference.x,difference.z).length() <= radius+.7 and absf(difference.y) < 1.5

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	var difference = global_position-actor.global_position
	if not definition.props["0x4"]: push_direction = Vector3(0,0,signf(difference.z))
	elif not definition.props["0x8"]: push_direction = Vector3(signf(difference.x),0,0)
	else: push_direction = Vector3(signf(difference.x),0,0) if absf(difference.x)>absf(difference.z) else Vector3(0,0,signf(difference.z))
	if push_direction.is_zero_approx(): return false
	return actor.item_actions.begin([{"clip":"push_start","enter":func(): actor.item_actions.face(global_position),"exit":func():
		pushing_actor = actor
		actor.push_target = self
		push_speed = 0
		add_collision_exception_with(actor)
		actor.add_collision_exception_with(self)
		actor.skeleton.rotation.y = atan2(push_direction.x,push_direction.z)
		actor.play_anim("push_loop")}])

func allows_position(point: Vector3) -> bool:
	if definition.push_zones.is_empty(): return true
	var box = AABB(point-Vector3.ONE*radius,Vector3.ONE*radius*2)
	for zone in definition.push_zones:
		var lo = GameSpace.original_point(Vector3(zone.min[0],zone.max[1],zone.max[2]))
		var hi = GameSpace.original_point(Vector3(zone.max[0],zone.min[1],zone.min[2]))
		if box.intersects(AABB(lo,hi-lo)): return true
	return false

func step_pusher(actor: RalphController,delta: float) -> void:
	if not Input.is_action_pressed("action") or not actor.is_on_floor(): stop_push(); return
	if actor.animation_player.current_animation != "push_loop": actor.play_anim("push_loop")
	# Normal surface profile 3: maxSpeed 150, acceleration 800, deceleration 1000.
	push_speed = move_toward(push_speed,1.5,8*delta)
	var before = global_position
	velocity = push_direction*push_speed if allows_position(global_position+push_direction*push_speed*delta) else Vector3.ZERO
	fall_time += delta
	var falling_speed = clampf(fall_time*40,2,30)
	var was_grounded = is_on_floor()
	velocity.y = -falling_speed
	move_and_slide()
	if is_on_floor():
		if not was_grounded: landed_speed = falling_speed
		fall_time = 0
	var displacement = global_position-before
	var horizontal = Vector3(displacement.x,0,displacement.z)
	if horizontal.length() > .00001:
		roll = Basis(horizontal.cross(Vector3.UP).normalized(),-horizontal.length()/radius)*roll
		visual.basis = roll
		if not sound.playing and not sound_path.is_empty():
			var stream: AudioStreamWAV = load(sound_path).duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
			sound.stream = stream; sound.play()
	else: sound.stop()
	actor.velocity = horizontal/maxf(delta,.0001)
	actor.velocity.y = 0 if actor.is_on_floor() else maxf(-20,actor.velocity.y-29*delta)
	actor.move_and_slide()
	try_native_cinematic()

func stop_push(animate = true) -> void:
	if not is_instance_valid(pushing_actor): return
	var actor = pushing_actor
	pushing_actor = null
	actor.push_target = null
	remove_collision_exception_with(actor)
	actor.remove_collision_exception_with(self)
	sound.stop()
	if animate and actor.can_use_inventory(): actor.item_actions.begin([{"clip":"push_end"}])

func _physics_process(delta: float):
	landed_speed = 0
	if movie_active: return
	if not arc.is_empty():
		arc.time = minf(float(arc.time)+delta/1.024,1)
		var target = OriginalSeesaw.arc_point(arc.start,arc.middle,arc.end,arc.time)
		if target.y < global_position.y: crush_objects_below(global_position,target)
		velocity = (target-global_position)/delta
		var descending_speed = maxf(0,-velocity.y)
		move_and_slide()
		# Rock::LAUNCHED switches to FALL on contact; preserve its incoming
		# speed for seesaw::AddBody before Godot zeros velocity against the plank.
		# Keeping the authored arc active through touchdown hid the impact from
		# the seesaw, so the returning rock never launched the opposite rider.
		if descending_speed>0 and is_on_floor():
			landed_speed = descending_speed
			arc.clear(); fall_time = 0
		elif arc.time>=1: arc.clear(); fall_time = 0
		return
	if is_instance_valid(pushing_actor): return
	if is_instance_valid(seesaw_support) and (not seesaw_support.covers(global_position) or absf(bottom()-seesaw_support.surface_height(global_position))>.6): seesaw_support = null
	velocity.x = 0; velocity.z = 0
	fall_time += delta
	var falling_speed = clampf(fall_time*40,2,30) # Rock::ApplyGravity native 4000 / 200..3000.
	var was_grounded = is_on_floor()
	var before = Vector2(global_position.x,global_position.z)
	velocity.y = -falling_speed
	if not was_grounded and not is_instance_valid(seesaw_support):
		crush_objects_below(global_position,global_position+velocity*delta)
	move_and_slide()
	if is_on_floor():
		if is_instance_valid(seesaw_support): global_position.x = before.x; global_position.z = before.y
		if not was_grounded:
			landed_speed = falling_speed
			if fall_time>.5 and not impact_sound_path.is_empty(): impact_sound.stream = load(impact_sound_path); impact_sound.play()
		fall_time = 0
	try_native_cinematic()

func crush_objects_below(previous: Vector3,target: Vector3):
	# Native Rock::CrushObjectsBelow: inset X/Z by 30 units, a 100-unit
	# band centered on the underside. Sweep the downward frame so a fast
	# launched stone cannot tunnel through Ralph between physics ticks.
	var box = definition.box
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
	lo.x += .3; lo.z += .3; hi.x -= .3; hi.z -= .3
	var bottom_before = previous.y+lo.y
	var bottom_after = target.y+lo.y
	var center = (previous+target)*.5+(lo+hi)*.5
	center.y = (minf(bottom_before,bottom_after)+maxf(bottom_before,bottom_after))*.5
	var shape = BoxShape3D.new()
	shape.size = Vector3(maxf(.01,hi.x-lo.x),absf(bottom_before-bottom_after)+1,maxf(.01,hi.z-lo.z))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.transform = Transform3D(Basis.IDENTITY,center)
	query.collision_mask = 1; query.exclude = [get_rid()]
	for contact in get_world_3d().direct_space_state.intersect_shape(query,64):
		if contact.collider is RalphController: contact.collider.on_rock_crush(self)

func try_native_cinematic() -> bool:
	if movie_active or not definition.get("cine_trigger",[]).size(): return false
	if not TutorialProgress.contains_xz(definition.cine_trigger[0],global_position): return false
	var manager = get_parent().get_node_or_null("LevelCinematics")
	if not manager: return false
	var identity = int(definition.props["0x24"] if box_delivered else definition.props["0x28"])
	return manager.start_rock_movie(identity,self)

func bottom() -> float: return global_position.y-radius

func rest_on_seesaw(board: Node3D):
	stop_push(false)
	seesaw_support = board
	global_position.y = board.surface_height(global_position)+radius
	velocity.y = 0

func launch(points: Array):
	stop_push(false); seesaw_support = null
	arc = {"time":0.0,"start":global_position,"middle":OriginalSeesaw.source_point(points[1]),"end":OriginalSeesaw.source_point(points[2])}
	velocity = Vector3.ZERO; fall_time = 0

func reset_to_home():
	if movie_active: return # GF_CINE_SURVIVES_RESTART, native level03 rock shot.
	stop_push(false)
	arc.clear(); seesaw_support = null; fall_time = 0; landed_speed = 0
	if int(definition.props["0x2c"]) != 0:
		global_position = home; roll = Basis.IDENTITY; visual.basis = roll
	velocity = Vector3.ZERO
