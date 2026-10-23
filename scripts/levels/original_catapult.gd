extends Node3D

enum State { IDLE, OPERATED, THROW, ARM_RETURN }
var definition: Dictionary
var sounds: Dictionary = {}
var state = State.IDLE
var player: RalphController
var visual: OriginalCinematicActor
var bucket: AnimatableBody3D
var bucket_shape: CollisionShape3D
var bucket_box = AABB()
var bucket_contents: Array = []
var bucket_armed = true
var power = 0.0
var arm_angle = 3680.0
var swing = 0.0
var visual_time = 0.0
var axis_override: Variant = null
var projectile: CharacterBody3D
var flight_start = Vector3.ZERO
var flight_middle = Vector3.ZERO
var flight_end = Vector3.ZERO
var flight_tick = 0.0
var launch_count = 0
var camera: Camera3D
var previous_camera: Camera3D
var camera_hold = 0.0
var camera_active = false
var saved_locked = false
var controlling = false
var power_sound: AudioStreamPlayer3D
var fire_sound: AudioStreamPlayer3D
var gauge: CanvasLayer

func _ready():
	add_to_group("world_interactables")
	add_to_group("catapults")
	set_meta("original_class","Catapult")
	set_meta("original_resource",int(definition.res))
	player = get_tree().get_first_node_in_group("player")
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	visual.set_process(false)
	# Use the visible chassis instead of a single bounding box: the latter
	# fills the empty space beside the regulator and prevents reaching it.
	bucket = AnimatableBody3D.new(); bucket.name = "Bucket"; bucket.sync_to_physics = false
	add_child(bucket)
	bucket.add_to_group("moving_supports")
	bucket_shape = CollisionShape3D.new(); bucket_shape.shape = BoxShape3D.new(); bucket.add_child(bucket_shape)
	power_sound = AudioStreamPlayer3D.new(); add_child(power_sound)
	fire_sound = AudioStreamPlayer3D.new(); add_child(fire_sound)
	if sounds.has("118"):
		var sample: AudioStreamWAV = load(sounds["118"]).duplicate()
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD; sample.loop_end = roundi(sample.mix_rate*sample.get_length())
		power_sound.stream = sample
	if sounds.has("263"): fire_sound.stream = load(sounds["263"])
	camera = Camera3D.new(); camera.name = "ShotCamera"; add_child(camera)
	gauge = preload("res://scripts/ui/original_catapult_gauge.gd").new(); gauge.catapult = self; add_child(gauge)
	process_physics_priority = -50
	if player: player.respawned.connect(reset_controller)
	call_deferred("update_bucket")
	apply_pose(arm_angle)
	build_chassis_collision()

func build_chassis_collision():
	var faces = PackedVector3Array()
	for surface in visual.rig.surfaces.values():
		for triangle in range(0,surface.verts.size(),3):
			if int(surface.bones[triangle])>6 or int(surface.bones[triangle+1])>6 or int(surface.bones[triangle+2])>6: continue
			# Export-to-Godot reflection reverses triangle winding.
			for index in [triangle,triangle+2,triangle+1]:
				var bone = int(surface.bones[index]); var p = surface.verts[index]
				var matrix = visual.legacy_skin.last_matrices[bone]*visual.legacy_skin.inverse_rests[bone]
				faces.append(visual.transform*(matrix*Vector3(p[0],p[1],p[2])))
	var body = StaticBody3D.new(); body.name = "ChassisCollision"
	var collider = CollisionShape3D.new(); var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces); shape.backface_collision = true; collider.shape = shape
	body.add_child(collider); add_child(body)

func action_label(_actor) -> String:
	return GameLocalization.ui("Regular catapulta")

func can_interact(actor: RalphController) -> bool:
	if state!=State.IDLE or not actor.is_on_floor() or not actor.can_use_item() or actor.carried_sheep or actor.carried_object: return false
	for box in definition.activation:
		var offset = global_position-GameSpace.from_export(Vector3(definition.pos[0],definition.pos[1],definition.pos[2]))
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))+offset
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))+offset
		var p = actor.global_position
		# Accept capsule contact with the authored zone; its origin cannot enter
		# the chassis now that the visible platform has collision.
		var reach = .4
		if p.x>=lo.x-reach and p.x<=hi.x+reach and p.z>=lo.z-reach and p.z<=hi.z+reach and absf(p.y-global_position.y)<1.5: return true
	return false

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	actor.interrupt_actions()
	var wheel = visual.skeleton.global_transform*visual.legacy_skin.last_matrices[6]
	var toward = wheel.origin-actor.global_position
	if Vector2(toward.x,toward.z).length()>.01: actor.skeleton.rotation.y = atan2(toward.x,toward.z)
	freeze_player()
	state = State.OPERATED
	actor.play_anim("idle")
	return true

func freeze_player():
	if controlling: return
	saved_locked = player.tutorial_movement_locked
	player.interrupt_actions()
	player.tutorial_movement_locked = true
	player.velocity.x = 0; player.velocity.z = 0
	controlling = true

func release_player():
	if not controlling: return
	player.tutorial_movement_locked = saved_locked
	controlling = false
	if not is_instance_valid(player.catapult_motion_owner) and player.current_state not in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH]:
		player.set_state(player.WolfState.IDLE); player.original_idle.reset(player)

func stop_operating():
	if state!=State.OPERATED: return
	state = State.IDLE
	power_sound.stop()
	release_player()

func _unhandled_input(event):
	if state==State.OPERATED and not event.is_echo() and (event.is_action_pressed("action") or event.is_action_pressed("cancel") or event.is_action_pressed("use_item")):
		stop_operating(); get_viewport().set_input_as_handled()

func adjust_power(axis: float,delta: float):
	# Native six units/update; time-normalized at60Hz for desktop/mobile FPS.
	power = clampf(power+axis*360.0*delta,0,1024)
	arm_angle = 3680+floorf(power*320/1024)
	if absf(axis)>.01:
		if power_sound.stream and not power_sound.playing: power_sound.play()
	else: power_sound.stop()
	var clip = "catapult_turn" if absf(axis)>.01 else "idle"
	if player.animation_player.current_animation!=clip: player.play_anim(clip)

func apply_pose(angle: float):
	visual.sample_animation("stand1",visual_time,true)
	var eighth = floorf(angle/8)
	for pair in [[7,-(290-eighth)],[8,-(501-floorf(eighth*8/10))],[9,-(452-floorf(eighth*64/100))],[6,int(angle*16)&4095]]:
		# Native Z rotation is negated in the exported rig (axis signs 1,1,-1).
		visual.skeleton.set_bone_pose_rotation(pair[0],Quaternion(Vector3.FORWARD,float(pair[1])*TAU/4096))
		visual.skeleton.set_bone_pose_position(pair[0],visual.skeleton.get_bone_rest(pair[0]).origin)
		visual.skeleton.set_bone_pose_scale(pair[0],Vector3.ONE)
	visual.legacy_skin.update_pose()

func update_bucket():
	var p: Dictionary = definition.props
	var eighth = floorf(arm_angle/8)
	var a1 = (1024-eighth)*TAU/4096
	var a2 = (1024-floorf(eighth*18/10))*TAU/4096
	var a3 = (1024-floorf(eighth*244/100))*TAU/4096
	var lengths: Array = definition.arm_lengths
	var height = float(p["0x10"])*.01+lengths[0]*sin(a1)+lengths[1]*sin(a2)+lengths[2]*sin(a3)
	var off = int(p["0x20"]); if off>2147483647: off-=4294967296
	var horizontal = off*.01+lengths[0]*cos(a1)+lengths[1]*cos(a2)+lengths[2]*cos(a3)
	var source_box: Dictionary = definition.model_boxes.filter(func(b): return int(b.flags)&1)[-1]
	var extent = Vector3(source_box.max[0]-source_box.min[0],source_box.max[1]-source_box.min[1],source_box.max[2]-source_box.min[2])*.01
	var yaw = int(definition.rot[1])&4095
	var sideways = absi(yaw-3072)<100 or absi(yaw-1024)<100
	var reverse = yaw>924 and yaw<2148
	extent.y *= .5
	var centre = global_position+Vector3.UP*height
	if sideways:
		extent.x *= .5
		centre.z += -horizontal if not reverse else horizontal
		centre.z += -extent.z*.5 if not reverse else extent.z*.5
	else:
		extent.z *= .5
		centre.x += horizontal if not reverse else -horizontal
		centre.x += extent.x*.5 if not reverse else -extent.x*.5
	var size = Vector3(extent.x*2 if sideways else extent.x,extent.y*2,extent.z if sideways else extent.z*2)
	bucket_box = AABB(centre-size*.5,size)
	# Original GroundQuery exposes bucketBox.minY as a walkable moving floor.
	var top = bucket_box.end.y
	bucket.global_position = Vector3(centre.x,top-.06,centre.z)
	bucket_shape.shape.size = Vector3(size.x,.12,size.z)

func scan_bucket(seat: bool = true) -> Array:
	bucket_contents.clear()
	for actor in get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("sheep_targets")+get_tree().get_nodes_in_group("carryable_rocks"):
		if not actor is CharacterBody3D or actor.get_world_3d()!=get_world_3d(): continue
		if actor==player and actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.SAM_DEATH,actor.WolfState.BLAST_DEATH]: continue
		if actor is OriginalSheep and (actor.carried_by or actor.dead or not actor.seesaw_arc.is_empty()): continue
		if actor.is_in_group("carryable_rocks") and (actor.carried_by or actor.shattered): continue
		var p = actor.global_position
		var lo = bucket_box.position; var hi = bucket_box.end
		if p.x<lo.x-.25 or p.x>hi.x+.25 or p.z<lo.z-.25 or p.z>hi.z+.25 or p.y<lo.y-.3 or p.y>hi.y+.3: continue
		bucket_contents.append(actor)
		if seat:
			actor.global_position.y = hi.y+.005
			actor.velocity.y = 0
	return bucket_contents

func set_switch(_sender: Node,on: bool):
	# A held switch fires once, not every physics frame after rearming.
	var was_on = bool(get_meta("switch_held",false))
	set_meta("switch_held",on)
	if on and not was_on and state==State.IDLE: launch()

func launch() -> bool:
	if state!=State.IDLE: return false
	scan_bucket(false)
	if bucket_contents.size()>1: return false
	launch_count += 1; swing = 0; state = State.THROW
	bucket_armed = false; bucket_shape.set_deferred("disabled",true)
	if fire_sound.stream: fire_sound.play()
	if bucket_contents.is_empty(): return true
	projectile = bucket_contents[0]
	freeze_player()
	projectile.catapult_motion_owner = self
	if projectile is OriginalSheep:
		projectile.forget_attraction(); projectile.clear_moving_anchor(); projectile.visual.idle("stand1")
	elif projectile==player:
		player.set_state(player.WolfState.FALL)
		player.play_anim("sheep_carry_fall" if player.carried_sheep or player.carried_object else "fall")
	projectile.add_collision_exception_with(bucket)
	var points: Array = definition.trajectory
	var native_origin = GameSpace.from_export(Vector3(definition.pos[0],definition.pos[1],definition.pos[2]))
	var fixture_offset = global_position-native_origin
	var end = OriginalSeesaw.source_point(points[2])+fixture_offset
	var start_source = OriginalSeesaw.source_point(points[0])+fixture_offset
	var direction = end-start_source; direction.y = 0; direction = direction.normalized()
	var displacement = direction*float(definition.max_throw_offset)*(power-512)/512
	flight_start = projectile.global_position
	flight_middle = OriginalSeesaw.source_point(points[1])+fixture_offset+displacement
	flight_end = end+displacement
	flight_end = find_free_landing_spot(projectile,flight_end)
	flight_tick = 0
	previous_camera = get_viewport().get_camera_3d()
	if definition.get("camera") is Dictionary:
		var setup: Dictionary = definition.camera
		camera.global_position = GameSpace.original_point(Vector3(setup.eye[0],setup.eye[1],setup.eye[2]))+fixture_offset
		camera.fov = rad_to_deg(2*atan(384.0/float(setup.focal)))
		track_camera()
		camera.make_current(); camera_active = true; camera_hold = 0
	return true

func find_free_landing_spot(object: CharacterBody3D,point: Vector3) -> Vector3:
	# Native FindFreeLandingSpot tries lateral50-unit steps, up to1000.
	var collider = object.find_child("CollisionShape3D",true,false) as CollisionShape3D
	if not collider: return point
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape; query.margin = .1; query.collision_mask = 1
	query.exclude = [object.get_rid(),bucket.get_rid()]
	var sideways = absi((int(definition.rot[1])&4095)-1024)<100 or absi((int(definition.rot[1])&4095)-3072)<100
	for i in range(21):
		query.transform = Transform3D(Basis.IDENTITY,point+collider.position)
		var blocked = false
		for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
			var body = hit.collider
			# World terrain isn't in the native object grid; MiscStatic is
			# explicitly skipped by this query. Keep actual moving obstacles.
			if body is StaticBody3D and (not body.has_meta("original_class") or body.get_meta("original_class")=="MiscStatic"): continue
			blocked = true; break
		if not blocked: return point
		point += Vector3.RIGHT*.5 if sideways else Vector3.FORWARD*.5
	return point

func track_camera():
	if not is_instance_valid(projectile): return
	var target = projectile.global_position+Vector3.UP*.35
	if camera.global_position.distance_squared_to(target)>.01: camera.look_at(target)

func step_flight(delta: float):
	if not is_instance_valid(projectile): return
	flight_tick = minf(256,flight_tick+delta*125*(4-3*flight_tick/128 if flight_tick<128 else 1))
	var point = OriginalSeesaw.arc_point(flight_start,flight_middle,flight_end,flight_tick/256)
	var motion = point-projectile.global_position
	var hit: KinematicCollision3D
	# Native first half is kinematic so the arm's own body cannot stop launch.
	if flight_tick<128:
		projectile.global_position = point
	else:
		for i in range(3):
			hit = projectile.move_and_collide(motion/3)
			if hit: break
	track_camera()
	if hit or flight_tick>=256:
		var object = projectile; projectile = null
		object.catapult_motion_owner = null; object.remove_collision_exception_with(bucket); object.velocity = Vector3.ZERO
		if object.has_method("landed"): object.landed(hit!=null)
		elif object is OriginalSheep:
			object.last_floor_y = object.global_position.y; object.begin_random_idle(false)
		elif object==player:
			player.last_ground_y = player.global_position.y; player.jump_origin_y = null
			player.jump_void_grace = .25; player.set_state(player.WolfState.FALL)
		camera_hold = 2.0

func _physics_process(delta):
	if controlling and player.current_state in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH]:
		reset_controller()
		return
	visual_time += delta
	if state==State.OPERATED:
		adjust_power(float(axis_override) if axis_override!=null else Input.get_axis("move_left","move_right"),delta)
	if state in [State.IDLE,State.OPERATED]:
		update_bucket(); scan_bucket(); apply_pose(arm_angle)
	elif state==State.THROW:
		swing = minf(256,swing+delta*125)
		apply_pose(cos((int(swing)*68&4095)*TAU/4096)*arm_angle/(swing*128/4096+1))
		step_flight(delta)
		if not is_instance_valid(projectile) and swing>=256: state = State.ARM_RETURN; swing = 0
	elif state==State.ARM_RETURN:
		swing = minf(256,swing+delta*250)
		apply_pose(arm_angle*swing/256)
		if swing>=256:
			state = State.IDLE; bucket_armed = true; update_bucket(); bucket_shape.set_deferred("disabled",false)
	if camera_active and not is_instance_valid(projectile):
		camera_hold = maxf(0,camera_hold-delta)
		if camera_hold<=0: close_camera(); release_player()
	if state==State.IDLE and not camera_active and controlling: release_player()

func close_camera():
	if not camera_active: return
	camera_active = false
	if camera.is_current():
		if is_instance_valid(previous_camera): previous_camera.make_current()
		else: player.camera.make_current()

func reset_controller():
	if is_instance_valid(projectile):
		projectile.catapult_motion_owner = null; projectile.remove_collision_exception_with(bucket)
	projectile = null
	state = State.IDLE; swing = 0; bucket_armed = true
	power_sound.stop(); close_camera(); release_player()
	bucket_shape.set_deferred("disabled",false)

func _exit_tree():
	if is_instance_valid(player): close_camera(); release_player()
