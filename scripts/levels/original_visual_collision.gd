extends RefCounted

# Reconcile simplified native collision with the visible shell in an authored
# region. Camera-only geometry is independent of gameplay collision layers.
# Additive surfaces are light/effects, never solid scenery.
static func surface_is_solid(mesh: Mesh,surface: int) -> bool:
	var material = mesh.surface_get_material(surface)
	if material is ShaderMaterial and material.shader:
		return material.shader.resource_path != "res://shaders/retro_add.gdshader"
	return true

static func solid_faces(mesh: Mesh) -> PackedVector3Array:
	var faces = PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		if not surface_is_solid(mesh,surface): continue
		var arrays = mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty(): faces.append_array(points)
		else:
			for index in indices: faces.append(points[index])
	return faces

static func setup(level: ImportedLevel, region: AABB, create_camera: bool = true) -> void:
	var node = level.get_node("Collision/CollisionShape3D")
	var native: PackedVector3Array = node.shape.get_faces()
	var visual: PackedVector3Array = solid_faces(level.get_node("Scenery").mesh)
	var faces = PackedVector3Array()
	for i in range(0,native.size(),3):
		if region.has_point((native[i]+native[i+1]+native[i+2])/3): continue
		faces.append_array(native.slice(i,i+3))
	for i in range(0,visual.size(),3):
		if region.has_point((visual[i]+visual[i+1]+visual[i+2])/3): faces.append_array(visual.slice(i,i+3))
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	shape.set_meta("native_triangles",native.size()/3)
	node.shape = shape
	if not create_camera: return
	var camera_faces = visual.duplicate()
	for actor in level.get_children():
		if actor.get_meta("original_class","") != "MiscStatic": continue
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			for point in solid_faces(mesh.mesh): camera_faces.append(mesh.global_transform*point)
	var camera_body = StaticBody3D.new()
	camera_body.name = "CameraVisualCollision"
	camera_body.collision_layer = 2
	camera_body.collision_mask = 0
	var camera_shape = CollisionShape3D.new()
	camera_shape.shape = ConcavePolygonShape3D.new()
	camera_shape.shape.backface_collision = true
	camera_shape.shape.set_faces(camera_faces)
	camera_body.add_child(camera_shape)
	level.add_child(camera_body)
	level.player.camera_pivot.collision_mask = 3

static func soften_floor_seams(level: ImportedLevel,region: AABB,entries: Array):
	# Connect each low floor edge to its existing upper edge with a slope.
	# Move coincident vertices together: overlaying a ramp leaves the upper
	# floor's front edge inside Ralph's capsule and can still block walking.
	var collider = level.get_node("Collision/CollisionShape3D")
	var faces: PackedVector3Array = collider.shape.get_faces()
	for i in range(0,faces.size(),3):
		if not region.has_point((faces[i]+faces[i+1]+faces[i+2])/3): continue
		for j in range(i,i+3):
			var point = faces[j]
			for seam in entries:
				if absf(point.z-float(seam.z))<.12 and point.y>=float(seam.min_y) and point.y<=float(seam.max_y):
					point.z -= float(seam.approach)
					break
			faces[j] = point
	var shape = collider.shape.duplicate()
	shape.set_faces(faces); collider.shape = shape
