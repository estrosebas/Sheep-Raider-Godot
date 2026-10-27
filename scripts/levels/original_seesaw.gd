extends AnimatableBody3D
class_name OriginalSeesaw

var definition: Dictionary
var visual: OriginalCinematicActor
var half_length = 0.0
var half_width = 0.0
var top_offset = 0.0
var tilt = 0.0 # Original 4096-angle units.
var tilt_velocity = 0.0
var max_negative = 0.0
var max_positive = 0.0
var axis_z = false
var contact_ids: Dictionary = {}
var timers = [0.0,0.0]
var accumulator = 0.0
var sound: AudioStreamPlayer3D
var launch_count = 0
var movie_active = false
var pending_landings: Dictionary = {}
var pending_impulse = 0.0
var tipping_moment = 0.0

func _ready() -> void:
	add_to_group("original_seesaws")
	set_physics_process(false)
	sync_to_physics = false
	var box = definition["boxes"][0]
	half_length = float(box["max"][0]-box["min"][0])*0.005
	half_width = float(box["max"][2]-box["min"][2])*0.005
	top_offset = -float(box["min"][1])*.01
	axis_z = absi(int(round(float(definition["rot_deg"][1])*4096/360))%2048-1024) < 512
	max_negative = float(definition["props"]["0x24"])*4096/360
	max_positive = float(definition["props"]["0x28"])*4096/360
	if max_positive == 0: max_positive = max_negative
	var shape = BoxShape3D.new()
	shape.size = Vector3(half_length*2,.16,half_width*2)
	var collision = CollisionShape3D.new()
	collision.position.y = top_offset-.08
	collision.shape = shape
	add_child(collision)
	visual = load(definition["directory"]+"/worn.tscn").instantiate()
	add_child(visual)
	visual.sample_animation("stand1",0)
	sound = AudioStreamPlayer3D.new()
	add_child(sound)
	set_meta("original_class","seesaw")
	set_meta("original_resource",int(definition["res"]))
	set_meta("original_solid_top",top_offset)

static func source_point(p: Array) -> Vector3:
	return GameSpace.original_point(Vector3(p[0],p[1],p[2]))

static func arc_point(start: Vector3,middle: Vector3,end: Vector3,t: float) -> Vector3:
	# LaunchArc::Step: p0 + v*t + 2*a*t² (middle is reached at t=.5).
	return start+(-3*start-end+4*middle)*t+2*(start+end-2*middle)*t*t

func surface_height(point: Vector3) -> float:
	# Solve the actual collider's top plane, including its rotated local offset.
	var normal = global_basis.y.normalized()
	var top = to_global(Vector3(0,top_offset,0))
	return (normal.dot(top)-normal.x*point.x-normal.z*point.z)/normal.y

func sheep_surface_height(actor: OriginalSheep) -> float:
	# Native MSG_SEESAW_TOUCH uses the uphill corner of the upright model box.
	var height = -INF
	for x in [-.35,.35]:
		for z in [-.35,.35]:
			height = maxf(height,surface_height(actor.global_position+Vector3(x,0,z)))
	return height

func covers(point: Vector3,margin: float = 0.0) -> bool:
	# Test the rotated top footprint, not a horizontal rectangle left behind
	# when a SLIDE plank swings almost vertical.
	var on_plane = Vector3(point.x,surface_height(point),point.z)
	var p = to_local(on_plane)
	return absf(p.x) < half_length+margin/maxf(.01,absf(global_basis.x.x if not axis_z else global_basis.x.z)) and absf(p.z) < half_width+margin

func slide_velocity() -> Vector3:
	# seesaw::Update emits MSG_SEESAW_DRIFT above56/4096 of a turn.
	if not (int(definition.props["0x20"])&1) or absf(tilt)<=56: return Vector3.ZERO
	var speed = sin(tilt*TAU/4096)
	return Vector3(0,0,-speed) if axis_z else Vector3(speed,0,0)

func register_landing(actor: Node3D,speed: float):
	# Native CustomCollide calls AddBody BEFORE the update scan. Preserve that
	# contact across Godot's body/manager priorities instead of losing its speed.
	if speed > .5: pending_landings[actor.get_instance_id()] = {"speed":speed,"frame":Engine.get_physics_frames()}

func step(delta: float,player: RalphController,objects: Array,manager: Node) -> void:
	if movie_active: return
	for side in range(2):
		var box = definition["ejection_boxes"][side]
		if box != null and TutorialProgress.contains(box,player.global_position):
			timers[side] = 4.0
		elif timers[side] > 0:
			timers[side] = maxf(0,timers[side]-delta)
	var bodies: Array = []
	var seen: Dictionary = {}
	var torque = 0.0
	var impact_side = 0
	var rock_impact = false
	var impulse = 0.0
	for identity in pending_landings.keys():
		if Engine.get_physics_frames()-int(pending_landings[identity].frame)>2: pending_landings.erase(identity)
	for candidate in [player]+objects:
		var is_rock = candidate is OriginalRock or candidate.is_in_group("pushable_rocks")
		var is_box = candidate is OriginalDeliveryBox
		if is_box and (not candidate.visible or candidate.state!="sealed"): continue
		if candidate is OriginalSheep and (candidate.carried_by or candidate.dead or not candidate.seesaw_arc.is_empty()): continue
		# An item placement freezes input, not the rider's weight/contact.
		if candidate == player and (manager.player_launching() or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]):continue
		if is_rock and not candidate.arc.is_empty():continue
		var feet = candidate.bottom() if is_rock or is_box else candidate.global_position.y
		var p = candidate.global_position
		# Native collection tests feet against the plane (-20..50 units), not
		# last frame's floor flag, which disappears when the plank swings down.
		var height = sheep_surface_height(candidate) if candidate is OriginalSheep else surface_height(p)
		# Native OverlapXZ tests the MODEL BOX, not just the actor origin.
		# A capsule can remain physically supported at the plank's edge with
		# its centre outside the footprint. Count that rider too.
		var identity = candidate.get_instance_id()
		var contact = pending_landings.get(identity,{})
		var registered = not contact.is_empty()
		var margin = .35 if candidate is OriginalSheep or candidate==player else 0.0
		if not covers(p,margin) or (not registered and (feet-height < -.2 or feet-height > .5)): continue
		# An upward moving support can give grounded Ralph positive velocity;
		# that is not a jump away from the seesaw.
		if candidate.velocity.y > .5 and not registered and not (candidate.is_on_floor() and (candidate!=player or candidate.current_state!=player.WolfState.JUMP)):continue
		seen[identity] = true
		var offset = p.z-global_position.z if axis_z else p.x-global_position.x
		if axis_z: offset = -offset
		var side = -1 if offset < -.3 else (1 if offset > .3 else 0)
		var impact = not contact_ids.has(identity)
		var weight = 40.0 if candidate is OriginalSheep else (120.0 if is_rock else 60.0)
		var landing_speed = 512.0
		if candidate == player and impact and side != 0 and timers[0 if side < 0 else 1] > 0:
			impact_side = side
			landing_speed = 48000.0
			timers = [0.0,0.0]
		elif is_rock and (registered or candidate.landed_speed > 0 or (impact and candidate.velocity.y < -.5)):
			impact_side = side
			rock_impact = true
			# TOUCH can precede CharacterBody's floor collision in the same tick.
			# Capture incoming speed before support correction zeros it out.
			landing_speed = maxf(512,maxf(float(contact.get("speed",0)),maxf(candidate.landed_speed,-candidate.velocity.y))*102.4)
			candidate.landed_speed = 0 # Consume once, whichever physics priority runs first.
		elif candidate is OriginalSheep and registered:
			landing_speed = maxf(512,float(contact.speed)*102.4)
		torque += offset*100*weight*512/65536.0
		impulse += offset*100*weight*(landing_speed-512)/65536.0
		pending_landings.erase(identity)
		bodies.append({"actor":candidate,"side":side})
	contact_ids = seen
	pending_impulse += impulse
	accumulator += delta
	while accumulator >= .04:
		accumulator -= .04
		var moment = torque+pending_impulse
		if definition.get("free_tilt",false):
			# Free balancing plank: unopposed load keeps turning it, rather than
			# treating its moment as a small fixed rest angle. Retain momentum
			# after riders leave the shrinking footprint, until the authored stop.
			if not bodies.is_empty(): tipping_moment = moment
			moment = tilt+tipping_moment
		var target = clampf(moment,-max_negative,max_positive)
		pending_impulse = 0
		var error = target-tilt
		tilt_velocity = error*3 if absf(error) > 205 else (error+tilt_velocity*3)/4
		var previous = tilt
		tilt = clampf(tilt+clampf((error+tilt_velocity)/32,-62,62),-max_negative,max_positive)
		rotation = Vector3(0,PI/2 if axis_z else 0,-tilt*TAU/4096)
		if (absf(previous)>113) != (absf(tilt)>113) and not sound.playing:
			sound.stream = load(manager.data["sounds"]["264"])
			sound.play()
	for entry in bodies:
		var actor = entry["actor"]
		if actor is OriginalSheep: actor.rest_on_seesaw(self)
		if impact_side != 0 and entry["side"] == -impact_side:
			var points = definition["trajectories"][0 if entry["side"] < 0 else 1]
			if points != null:
				# A wolf impact only bounces a sheep vertically; a falling rock
				# sends it along the authored level trajectory (seesaw::Update).
				if actor is OriginalSheep:
					actor.launch_from_seesaw(self,points,rock_impact)
				else:
					manager.launch(actor,points)
				launch_count += 1
				var cameras: Array = definition.get("launch_cameras",[])
				var index = 0 if entry["side"]<0 else 1
				if index<cameras.size() and cameras[index]!=null and manager.has_method("start_launch_camera"):
					manager.start_launch_camera(cameras[index],bool(int(definition.props["0x20"])&2),actor)
		elif actor is OriginalRock:
			actor.global_position.y = surface_height(actor.global_position)-actor.local_center.y+actor.half_size.y
			actor.velocity.y = 0
		elif actor.is_in_group("pushable_rocks"):
			actor.rest_on_seesaw(self)
		elif actor is OriginalDeliveryBox:
			actor.global_position.y = surface_height(actor.global_position)
		elif actor == player and (player.cinematic_controls_locked or player.launch_controls_locked or player.tutorial_movement_locked or definition.get("free_tilt",false)):
			# Original MSG_SEESAW_TOUCH keeps stationary/placing Ralph on support.
			actor.global_position.y = surface_height(actor.global_position)
