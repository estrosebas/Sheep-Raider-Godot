extends "res://scripts/items/original_pushable_rock.gd"
class_name OriginalSnowball
var base_radius = 2.0
var roll_seconds = 0.0
var ball_scale = .25
func _ready():
	super._ready(); base_radius = radius
	apply_size(.25)
	add_to_group("snowballs"); add_to_group("checkpoint_controllers")
	call_deferred("snap_initial")
func snap_initial():
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position-Vector3.UP*8,1)
	query.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y+radius
	home = global_position
func apply_size(amount: float):
	ball_scale = amount; radius = base_radius*amount
	for child in get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D: child.shape.radius = radius
	visual.scale = Vector3.ONE*ball_scale

func keep_pusher_clear(actor: RalphController):
	# Growth increases the sphere while the rock adapter keeps the old hand
	# distance. Without this correction, ending a push restores collision with
	# Ralph inside the sphere and Godot ejects the ball beyond its ZONE edge.
	var away = actor.global_position-global_position; away.y = 0
	if away.is_zero_approx(): return
	var capsule = actor.get_node("CollisionShape3D").shape as CapsuleShape3D
	var clearance = radius+capsule.radius+.035
	if away.length()<clearance: actor.move_and_collide(away.normalized()*(clearance-away.length()))

func stop_push(animate = true):
	if is_instance_valid(pushing_actor): keep_pusher_clear(pushing_actor)
	super.stop_push(animate)
func allows_position(point: Vector3) -> bool:
	if definition.push_zones.is_empty(): return true
	for box in definition.push_zones:
		if point.x>=float(box.min[0])*.01 and point.x<=float(box.max[0])*.01 and point.z>=-float(box.max[2])*.01 and point.z<=-float(box.min[2])*.01: return true
	return false
func step_pusher(actor: RalphController,delta: float):
	var previous = global_position
	super.step_pusher(actor,delta)
	var moved = Vector2(global_position.x-previous.x,global_position.z-previous.z).length()
	if moved>.00001 and is_on_floor() and allows_position(global_position):
		var goal = lerpf(.25,float(0x333)/1024,minf(1,roll_seconds/20))
		var difference = base_radius*goal-radius
		# The original grows only if the expanded sphere has room at ground level.
		var query = PhysicsShapeQueryParameters3D.new(); var sphere = SphereShape3D.new()
		sphere.radius = maxf(.01,base_radius*goal-.025); query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY,global_position+Vector3.UP*difference)
		query.collision_mask = 1; query.exclude = [get_rid(),actor.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			global_position.y += difference; apply_size(goal); roll_seconds = minf(20,roll_seconds+delta)
	visual.scale = Vector3.ONE*ball_scale
	if is_instance_valid(pushing_actor): keep_pusher_clear(actor)
func _physics_process(delta: float):
	super._physics_process(delta); visual.scale = Vector3.ONE*ball_scale
func capture_world_state() -> Dictionary: return {"position":SaveFiles.vector(global_position),"scale":ball_scale,"roll_seconds":roll_seconds}
func restore_world_state(saved: Dictionary):
	stop_push(false); velocity = Vector3.ZERO; fall_time = 0
	if SaveFiles.valid_vector(saved.get("position")): global_position = SaveFiles.to_vector(saved.position)
	roll_seconds = clampf(float(saved.get("roll_seconds",0)),0,20)
	apply_size(clampf(float(saved.get("scale",.25)),.25,float(0x333)/1024))

func reset_to_home():
	# Snowball::Reset is empty: retain size and position after death.
	stop_push(false); velocity = Vector3.ZERO; fall_time = 0

func can_interact(actor: RalphController) -> bool:
	var difference = global_position-actor.global_position
	return actor.can_use_item() and actor.is_on_floor() and not actor.carried_sheep and difference.y>0 and Vector2(difference.x,difference.z).length()<=radius+.7

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	# Snowball has no MSG_QUERY_PUSH_AXIS override and returns0. Native
	# Wolf::SnapHeadingToObject rounds that reply to the nearest quarter turn.
	# A diagonal drifts out of this map's narrow L-shaped ZONE corridor.
	var away = global_position-actor.global_position; away.y = 0
	if away.is_zero_approx(): return false
	push_direction = Vector3(signf(away.x),0,0) if absf(away.x)>absf(away.z) else Vector3(0,0,signf(away.z))
	return actor.item_actions.begin([{"clip":"push_start","enter":func(): actor.item_actions.face(global_position),"exit":func():
		pushing_actor = actor; actor.push_target = self; push_speed = 0
		add_collision_exception_with(actor); actor.add_collision_exception_with(self)
		actor.skeleton.rotation.y = atan2(push_direction.x,push_direction.z)
		actor.play_anim("push_loop")}])
