extends RefCounted
class_name OriginalPlacement
# Wolf::CanPutDownHeldObj: near (0,-2,0), front (0,-70,-92)
# plus Sheep::sheepCarryOffset (0,7,0), eight static body tests.
static func probe(actor: RalphController, object: Node3D, at_feet: bool) -> Dictionary:
	var point = actor.global_position+Vector3.UP*(.2 if at_feet else .63)
	if not at_feet: point += actor.item_facing()*.92
	var excluded: Array[RID] = [actor.get_rid()]
	if object is CollisionObject3D: excluded.append(object.get_rid())
	# CQ_STATIC ignores other moving characters; they are not terrain/support.
	for moving in actor.get_tree().get_nodes_in_group("grounded_npcs")+actor.get_tree().get_nodes_in_group("sheep_targets"):
		if moving is CharacterBody3D and not moving.is_in_group("moving_supports") and not excluded.has(moving.get_rid()): excluded.append(moving.get_rid())
	var ray = PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*(.4 if at_feet else 1.43))
	ray.collision_mask = 1
	ray.exclude = excluded
	var space = actor.get_world_3d().direct_space_state
	var ground = space.intersect_ray(ray)
	if ground.is_empty() or ground.normal.y < .5: return {}
	var destination: Vector3 = ground.position+Vector3.UP*.005
	if object is OriginalSheep:
		# An upright sheep box must clear the uphill edge of its footprint.
		# A centre ray alone makes even gentle terrain look like a wall.
		for x in [-.35,.35]:
			for z in [-.35,.35]:
				var corner = point+Vector3(x,0,z)
				var support_query = PhysicsRayQueryParameters3D.create(corner,corner-Vector3.UP*1.43)
				support_query.collision_mask = 1
				support_query.exclude = excluded
				var support = space.intersect_ray(support_query)
				if support.is_empty() or support.normal.y < .5: return {}
				destination.y = maxf(destination.y,support.position.y+.005)
	var shape = object.get_node("CollisionShape3D").shape if object is OriginalSheep else SphereShape3D.new()
	if shape is SphereShape3D: shape.radius = .08
	# A small prop's sphere must clear the inclined supporting plane too.
	var center = Vector3.UP*(.4 if object is OriginalSheep else .08/maxf(ground.normal.y,.5)+.015)
	var query = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	query.shape = shape
	query.exclude = excluded
	query.margin = .001
	# Check the whole route, then the volume sitting on the final floor.
	for i in range(8):
		var route_point = point.lerp(actor.global_position,float(i)/8)
		# Source CQ_STATIC tests obstruction, while ground support is separate.
		route_point.y = maxf(route_point.y,destination.y)
		query.transform = Transform3D(Basis.IDENTITY,route_point+center)
		if not space.intersect_shape(query,1).is_empty(): return {}
	query.transform = Transform3D(Basis.IDENTITY,destination+center)
	if not space.intersect_shape(query,1).is_empty(): return {}
	return {"position":destination,"support":ground.collider}

static func follow_support(object: Node3D,placement: Dictionary):
	var old = object.get_node_or_null("MovingSupport")
	if old:
		old.name = "RetiringSupport"; old.queue_free()
	var support = placement.get("support")
	if support is OriginalSeesaw or support is AnimatableBody3D or (is_instance_valid(support) and support.is_in_group("moving_supports")):
		var follower = preload("res://scripts/items/original_moving_support.gd").new()
		follower.support = placement.support
		object.add_child(follower)
