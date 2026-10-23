extends RefCounted
# Optional map corrections. Layer4 is already used for player-only boundaries
# in Level02; terrain probes, NPCs and SpringArm camera ignore this layer.
static func install(level: ImportedLevel):
	var path = level.asset_directory+"/data/player_boundaries.json"
	if not FileAccess.file_exists(path): return
	var definition = JSON.parse_string(FileAccess.get_file_as_string(path))
	var root = Node3D.new(); root.name = "PlayerBoundaries"; level.add_child(root)
	level.player.collision_mask |= 8
	# Lift shared source vertices, preserving the gap in the original ridge.
	# A manually closed contour also blocks Sam's second-phase entrance.
	if definition.has("terrain_vertex_lifts"):
		var collider: CollisionShape3D = level.get_node("Collision/CollisionShape3D")
		var faces = collider.shape.get_faces()
		var changed = PackedByteArray(); changed.resize(faces.size())
		for rule in definition.terrain_vertex_lifts:
			var low = Vector3(rule.min[0],rule.min[1],rule.min[2])
			var high = Vector3(rule.max[0],rule.max[1],rule.max[2])
			for i in range(faces.size()):
				var point = faces[i]
				if point.x>=low.x and point.x<=high.x and point.y>=low.y and point.y<=high.y and point.z>=low.z and point.z<=high.z:
					faces[i].y += float(rule.raise_by)
					changed[i] = 1
		var lifted = PackedVector3Array()
		for i in range(0,faces.size(),3):
			if changed[i] or changed[i+1] or changed[i+2]: lifted.append_array(faces.slice(i,i+3))
		var body = StaticBody3D.new(); body.name = "RaisedSnowRidge"
		body.collision_layer = 8; body.collision_mask = 0; root.add_child(body)
		var shape = ConcavePolygonShape3D.new(); shape.set_faces(lifted); shape.backface_collision = true
		var collision = CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	for wall in definition.get("walls",[]):
		var body = StaticBody3D.new(); body.name = wall.name
		body.collision_layer = 8; body.collision_mask = 0; root.add_child(body)
		var faces = PackedVector3Array()
		for i in range(wall.points.size()-1):
			var p = wall.points[i]; var q = wall.points[i+1]
			var a = Vector3(p[0],wall.bottom,p[1]); var b = Vector3(q[0],wall.bottom,q[1])
			var c = Vector3(q[0],wall.top,q[1]); var d = Vector3(p[0],wall.top,p[1])
			faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
		var shape = ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(faces)
		var collision = CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
