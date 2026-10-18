extends StaticBody3D
class_name OriginalHiddenRock
# HiddenRocks35 owns its native translated model box and MSG_QUERY_COVER.
var definition: Dictionary
var visual_scene: String
var visual: OriginalCinematicActor
var bounds: AABB
func _ready():
	add_to_group("rock_cover")
	set_meta("original_class","HiddenRocks")
	set_meta("original_resource",int(definition.get("res",-1)))
	collision_layer = 3
	var box = definition.boxes[0]
	var lo = GameSpace.original_point(Vector3(box.min[0],box.max[1],box.max[2]))
	var hi = GameSpace.original_point(Vector3(box.max[0],box.min[1],box.min[2]))
	bounds = AABB(lo,hi-lo)
	var collision = CollisionShape3D.new(); var shape = BoxShape3D.new()
	shape.size = bounds.size; collision.shape = shape; collision.position = bounds.get_center(); add_child(collision)
	visual = load(visual_scene).instantiate(); add_child(visual)
	set_meta("original_solid_top",hi.y)
	call_deferred("snap_to_ground")
func snap_to_ground():
	var ray = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*2,global_position-Vector3.UP*4,1)
	var excluded: Array[RID] = [get_rid()]
	for actor in get_tree().get_nodes_in_group("grounded_npcs")+get_tree().get_nodes_in_group("player"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	ray.exclude = excluded
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): global_position.y = hit.position.y+.001-bounds.position.y
func edge_gap(actor) -> float:
	# Box_GapXZ <=10. Adapt Wolf's original18-unit half-width to its Godot capsule.
	var p = actor.global_position-global_position
	var radius = actor.get_node("CollisionShape3D").shape.radius
	var end = bounds.end
	var dx = maxf(maxf(bounds.position.x-p.x,p.x-end.x)-radius,0)
	var dz = maxf(maxf(bounds.position.z-p.z,p.z-end.z)-radius,0)
	return Vector2(dx,dz).length()
func accepts(actor,gap: float) -> bool:
	var height = actor.global_position.y-global_position.y
	return is_visible_in_tree() and height>=bounds.position.y-.2 and height<bounds.end.y-.15 and edge_gap(actor)<=gap+.005
func side_normal(point: Vector3) -> Vector3:
	var d = point-global_position
	var native_z = -d.z
	var side = (1 if d.x>native_z else 0)+(2 if d.x>-native_z else 0)
	return [Vector3.LEFT,Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT][side]

func cover_anchor(actor,normal: Vector3) -> Vector3:
	# COVER_APPROACH centres the tangent coordinate on the selected face.
	# Keep the capsule outside the native solid box; pose contact is visual.
	var local = bounds.get_center()
	var radius = float(actor.get_node("CollisionShape3D").shape.radius)
	var padding = radius+float(actor.safe_margin)+.01
	if absf(normal.x)>.5: local.x = bounds.end.x+padding if normal.x>0 else bounds.position.x-padding
	else: local.z = bounds.end.z+padding if normal.z>0 else bounds.position.z-padding
	var point = global_position+local
	point.y = actor.global_position.y
	return point

func visual_face_point(normal: Vector3,height: float) -> Variant:
	# The artwork slopes and extends beyond the simple native solid box.
	# Intersect its actual triangles at Ralph's back height, rather than
	# using a universal offset that leaves gaps on differently shaped rocks.
	var center = global_position+bounds.get_center(); center.y = height
	var origin = center+normal*4
	var nearest: Variant = null
	var projection = -INF
	for surface in visual.rig.surfaces.values():
		for i in range(0,surface.verts.size(),3):
			var points: Array[Vector3] = []
			for j in range(3):
				var v = surface.verts[i+j]
				points.append(visual.global_transform*GameSpace.from_export(Vector3(v[0],v[1],v[2])))
			var hit = Geometry3D.ray_intersects_triangle(origin,-normal,points[0],points[1],points[2])
			if hit!=null and (hit-center).dot(normal)>projection:
				projection = (hit-center).dot(normal); nearest = hit
	return nearest

func hides_from(actor,observer: Vector3,face: Vector3 = Vector3.ZERO) -> bool:
	# Native half-space test, preserving the reflected Z coordinate.
	var normal = face if face!=Vector3.ZERO else side_normal(actor.global_position)
	return (observer-global_position).dot(normal)<0
