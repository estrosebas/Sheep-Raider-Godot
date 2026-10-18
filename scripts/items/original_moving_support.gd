extends Node
var support: Node3D
var local_point: Vector3
var fall_speed = 0.0
func _ready():
	name = "MovingSupport"
	process_physics_priority = 150 # After the platform's physics movement.
	if is_instance_valid(support):
		var item = get_parent()
		item.global_position.y = surface_height(support,item.global_position,item.global_position.y)+.005
		local_point = support.to_local(item.global_position)

func surface_height(body: Node3D,point: Vector3,fallback: float) -> float:
	if body is OriginalSeesaw: return body.surface_height(point)
	if body is OriginalWoodenLift: return body.global_position.y-float(body.definition.boxes[0].min[1])*.01
	if body is OriginalWeightedPlatform: return body.surface_height()
	if body.is_in_group("moving_supports") and body.has_method("surface_height"): return body.surface_height(point)
	return fallback
func _physics_process(delta: float):
	var item = get_parent()
	# Lit dynamite is deliberately unavailable for pickup, but still cargo.
	if not item.follows_ground_support(): queue_free(); return
	if is_instance_valid(support): item.global_position = support.to_global(local_point)
	fall_speed = minf(20,fall_speed+15*delta)
	# Animated support transforms can reach the physics ray one frame later.
	# Allow its contact tolerance so a descending tilted edge does not briefly
	# turn a supported plant into a free-falling one.
	var drop = maxf(fall_speed*delta+.1,.6 if is_instance_valid(support) else 0)
	var query = PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*.3,item.global_position-Vector3.UP*drop)
	var excluded: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("grounded_npcs")+get_tree().get_nodes_in_group("player"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	query.exclude = excluded; query.collision_mask = 1
	var hit = item.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y >= .5:
		var floor_y: float = hit.position.y
		# Physics ray transforms can still be from the preceding tick. Use the
		# current authored surface for a lift/board instead of snapping cargo
		# one platform step behind (especially visible while it rises).
		if hit.collider==support: floor_y = surface_height(support,item.global_position,item.global_position.y-.005)
		else: floor_y = surface_height(hit.collider,item.global_position,floor_y)
		item.global_position.y = floor_y+.005; fall_speed = 0
		if hit.collider is OriginalSeesaw or hit.collider is OriginalWoodenLift or hit.collider is AnimatableBody3D or hit.collider.is_in_group("moving_supports"):
			support = hit.collider; local_point = support.to_local(item.global_position)
		else: support = null
	else:
		support = null
		item.global_position.y -= fall_speed*delta
