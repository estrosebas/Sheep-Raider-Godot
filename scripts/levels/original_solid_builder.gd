extends RefCounted
class_name OriginalSolidBuilder

const Space = preload("res://scripts/levels/game_space.gd")

static func build(parent: Node3D, path: String, runtime_classes: Array = [], records: Array = []) -> Node3D:
	var root = Node3D.new()
	root.name = "OriginalObjectCollisions"
	parent.add_child(root)
	var entities = records if not records.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
	for entity in entities:
		if entity["class_name"] in runtime_classes:
			continue # Runtime puzzle owns these colliders, never leave static duplicates.
		var body = StaticBody3D.new()
		body.name = "%s_%d" % [entity["class_name"], int(entity["res"])]
		var p = entity["position"]
		body.position = Space.from_export(Vector3(p[0],p[1],p[2]))
		body.set_meta("original_resource", int(entity["res"]))
		body.set_meta("original_class", entity["class_name"])
		# ScnObject boxes are translated in world space, not rotated with art.
		root.add_child(body)
		for box in entity["boxes"]:
			var a = box["min"]
			var b = box["max"]
			var lo = Space.original_point(Vector3(a[0],b[1],b[2]))
			var hi = Space.original_point(Vector3(b[0],a[1],a[2]))
			var size = hi-lo
			body.set_meta("original_solid_top", maxf(float(body.get_meta("original_solid_top",-INF)), hi.y))
			if size.x <= 0 or size.y <= 0 or size.z <= 0:
				continue
			var collision = CollisionShape3D.new()
			collision.position = (lo+hi)/2
			var flags = int(box["flags"])
			if flags & 0x16:
				# Convex approximation of original cone / ellipsoid / cylinder.
				var points = PackedVector3Array()
				var radii = size/2
				for ring in range(9):
					var t = float(ring)/8
					var radius = sqrt(maxf(0.0,1.0-pow(2*t-1,2))) if flags & 4 else (1.0-t if flags & 2 else 1.0)
					for segment in range(16):
						var angle = TAU*segment/16
						points.append(Vector3(cos(angle)*radii.x*radius, (t*2-1)*radii.y, sin(angle)*radii.z*radius))
				var shape = ConvexPolygonShape3D.new()
				shape.points = points
				collision.shape = shape
			else:
				var shape = BoxShape3D.new()
				shape.size = size
				collision.shape = shape
			collision.set_meta("original_box_flags", flags)
			body.add_child(collision)
	return root
