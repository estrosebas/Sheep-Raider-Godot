extends CharacterBody3D
class_name OriginalRaft
# Raft53 owns its translated solid box, fan inertia, water current and cargo.
# Godot carries physics-active characters during move_and_slide. Other cargo
# receives native CarryObjects displacement, or follows its MovingSupport.
var definition: Dictionary = {}
var visual: OriginalCinematicActor
var deck: AABB
var start_position: Vector3
var initialized = false
var fan_speed = 0.0
var flow_speed = 0.0
var flow_heading = 0.0
var fan_direction = Vector3.ZERO
var fan_received = false
var travel_velocity = Vector3.ZERO
var rider_count = 0
var clip = "stand1"
var clip_time = 0.0
var wake: OriginalSpriteEmitter

func _ready():
	add_to_group("rafts"); add_to_group("fan_targets"); add_to_group("moving_supports")
	# FanItem sends MSG_FAN_BLOW during physics, before the raft consumes it.
	process_physics_priority = 50
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 3; collision_mask = 1
	visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
	for box in definition.boxes:
		var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
		var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
		var shape = BoxShape3D.new(); shape.size = hi-lo
		var collider = CollisionShape3D.new(); collider.shape = shape; collider.position = (lo+hi)/2
		add_child(collider)
		if deck.size==Vector3.ZERO: deck = AABB(lo,hi-lo)
	wake = OriginalSpriteEmitter.new(); wake.world_space = true
	wake.life = 2; wake.period = .25; wake.rise_speed = 0; wake.size_start = .7; wake.size_end = 1.4
	add_child(wake); wake.configure(definition.get("wake_frames",[]),8)
	for particle in wake.particles:
		particle.sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		particle.sprite.rotation.x = -PI/2
	visual.sample_animation(clip,0)
	call_deferred("initialize")

func initialize():
	# Foundation assigns the entity transform after add_child/_ready.
	# Native collision boxes are world-aligned: rotate only the artwork.
	visual.rotation = rotation; rotation = Vector3.ZERO
	start_position = global_position; initialized = true
	for actor in get_tree().get_nodes_in_group("player"):
		if actor.get_parent()==get_parent() and not actor.respawned.is_connected(reset_to_home):
			actor.respawned.connect(reset_to_home)

func surface_height(_point: Vector3 = Vector3.ZERO) -> float:
	return global_position.y+deck.end.y

func covers(point: Vector3,margin: float = 0) -> bool:
	var relative = point-global_position
	return relative.x+margin>=deck.position.x and relative.x-margin<=deck.end.x and relative.z+margin>=deck.position.z and relative.z-margin<=deck.end.z

func is_rider(actor: Node3D) -> bool:
	if actor.get_parent()!=get_parent(): return false
	if actor is OriginalSheep and (actor.dead or is_instance_valid(actor.carried_by) or not actor.seesaw_arc.is_empty()): return false
	if actor is GameItem and not actor.follows_ground_support(): return false
	if actor is RalphController and actor.current_state in [actor.WolfState.PIT_FALL,actor.WolfState.SAM_DEATH,actor.WolfState.BLAST_DEATH]: return false
	if actor is CharacterBody3D and actor.velocity.y>.5: return false
	var margin = .35 if actor is CharacterBody3D else .08
	return covers(actor.global_position,margin) and absf(actor.global_position.y-surface_height())<=float(definition.get("rider_tolerance",.1))+.015

func receives_fan_from(holder: Node3D,_direction: Vector3) -> bool:
	# Fan::Blow accepts overlapping holder/target XZ boxes, even outside its
	# directional cone. Raft::Update additionally requires Wolf on the deck.
	return initialized and holder is RalphController and is_rider(holder)

func on_fan_blow(direction: Vector3,_delta: float):
	# Native heading points opposite Wolf's visible forward (-Z in the source).
	# Blowing outwards propels the raft backwards, as in Raft::Update.
	fan_direction = -Vector3(direction.x,0,direction.z).normalized()
	fan_received = true

static func current_from_flags(flags: int) -> Dictionary:
	# Zone_GetFlowHeading, including priority of POS_Z/POS_X and SLOW.
	var heading = 0
	var speed = 0.0
	if flags & 0x78000000:
		speed = 1.0 if flags & 0x00800000 else (4.0 if flags & 0x04000000 else 2.0)
		if flags & 0x40000000: heading = 0xa00 if flags & 0x10000000 else (0x600 if flags & 0x08000000 else 0x800)
		elif flags & 0x20000000: heading = 0xe00 if flags & 0x10000000 else (0x200 if flags & 0x08000000 else 0)
		elif flags & 0x10000000: heading = 0xc00
		else: heading = 0x400
	return {"heading":float(heading)*TAU/4096,"speed":speed}

func _physics_process(delta: float):
	if not initialized: return
	var riders: Array[Node3D] = []
	var wolf_on = false
	for actor in get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("sheep_targets")+get_tree().get_nodes_in_group("game_items"):
		if actor is Node3D and is_rider(actor):
			riders.append(actor)
			if actor is RalphController: wolf_on = true
	if riders.size()!=rider_count:
		rider_count = riders.size(); clip = "action1"; clip_time = 0
	elif clip=="action1" and clip_time>=float(visual.rig.animations.action1.duration):
		clip = "stand1"; clip_time = 0
	var target_speed = float(definition.get("fan_speed",3.5)) if fan_received and wolf_on else 0.0
	var rate = float(definition.get("fan_acceleration",2)) if target_speed>fan_speed else float(definition.get("fan_deceleration",2))
	fan_speed = move_toward(fan_speed,target_speed,rate*delta)
	fan_received = false
	var current = {"heading":0.0,"speed":0.0}
	for provider in get_tree().get_nodes_in_group("water_regions"):
		if provider.get_parent()!=get_parent(): continue
		var zone: Dictionary = provider.water_at(global_position)
		if not zone.is_empty(): current = current_from_flags(int(zone.get("flags",0)))
		break
	if flow_speed==0: flow_heading = current.heading
	else: flow_heading = rotate_toward(flow_heading,current.heading,float(definition.get("flow_turn_speed",TAU*2.5))*delta)
	flow_speed = move_toward(flow_speed,current.speed,float(definition.get("flow_acceleration",.5) if current.speed>flow_speed else definition.get("flow_deceleration",1))*delta)
	# Source velocity = -flowSpeed*(sin,cos); GameSpace reflects Z.
	travel_velocity = fan_direction*fan_speed+Vector3(-sin(flow_heading),0,cos(flow_heading))*flow_speed
	var before = global_position
	for actor in riders:
		if actor is PhysicsBody3D: add_collision_exception_with(actor)
	var collision = move_and_collide(travel_velocity*delta)
	if collision:
		var slide = collision.get_remainder().slide(collision.get_normal()); slide.y = 0
		if slide.length_squared()>.000001: move_and_collide(slide)
	global_position.y = before.y # Native RESOLVE_KEEP_Y, no sinking into banks.
	var displacement = global_position-before
	for actor in riders:
		if actor is PhysicsBody3D: remove_collision_exception_with(actor)
		# Cargo with MovingSupport follows local coordinates later at priority150.
		if actor.has_node("MovingSupport") and actor.get_node("MovingSupport").support==self: continue
		if not actor is CharacterBody3D or not actor.is_physics_processing(): actor.global_position += displacement
		if actor is OriginalSheep: actor.set_moving_anchor(self,float(definition.get("anchor_radius",.5)))
	wake.emitting = fan_speed>.01 and displacement.length_squared()>.000001
	var heading = atan2(fan_direction.x,-fan_direction.z)+randf_range(-PI/2,PI/2)
	var corner = posmod(int(floor(fposmod(heading,TAU)/(PI/2))),4)
	var signs = [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)][corner]
	wake.position = Vector3(deck.end.x if signs.x>0 else deck.position.x,deck.end.y-.09,deck.position.z if signs.y>0 else deck.end.z)
	clip_time += delta; visual.sample_animation(clip,clip_time,clip=="stand1")

func reset_to_home():
	if bool(definition.get("reset_position",false)): global_position = start_position
	reset_motion()

func reset_motion():
	fan_speed = 0; flow_speed = 0; fan_received = false; fan_direction = Vector3.ZERO; travel_velocity = Vector3.ZERO
	rider_count = 0; clip = "stand1"; clip_time = 0
	wake.clear(); visual.sample_animation(clip,0)
