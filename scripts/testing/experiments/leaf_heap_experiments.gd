extends RefCounted
# Leaf heaps are terrain sheets, not Ralph's skinned crossed-card bush.
# Keep these experiments in the lab until a visual choice is approved.
const CUTOUT = preload("res://shaders/experiments/leaf_heap_cutout.gdshader")
const OPAQUE = preload("res://shaders/retro_opaque.gdshader")
const SIDES = preload("res://shaders/experiments/leaf_heap_sides.gdshader")

static func original_reference(source: ArrayMesh) -> ArrayMesh:
	var mesh: ArrayMesh = source.duplicate()
	for surface in range(mesh.get_surface_count()):
		var material: ShaderMaterial = source.surface_get_material(surface).duplicate()
		material.shader = OPAQUE
		mesh.surface_set_material(surface,material)
	return mesh

static func key(point: Vector3) -> String:
	return "%.5f,%.5f,%.5f"%[point.x,point.y,point.z]

static func close_edges(source: ArrayMesh,cutout: bool) -> ArrayMesh:
	# Retain every authored top vertex, UV and color. Close only unmatched
	# boundary edges down to the floor: no billboard or inflated top surface.
	var mesh = original_reference(source)
	for surface in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var edges = {}
		for i in range(0,indices.size(),3):
			for pair in [[0,1],[1,2],[2,0]]:
				var a = indices[i+pair[0]]; var b = indices[i+pair[1]]
				var ka = key(vertices[a]); var kb = key(vertices[b])
				var edge_key = ka+"|"+kb if ka<kb else kb+"|"+ka
				if not edges.has(edge_key):
					var tangent = vertices[b]-vertices[a]
					var outward = Vector3(tangent.z,0,-tangent.x).normalized()
					var center = (vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
					if outward.dot((vertices[a]+vertices[b])/2-center)<0: outward = -outward
					edges[edge_key] = {"count":0,"a":a,"b":b,"outward":outward}
				edges[edge_key].count += 1
		var outward_at = {}
		for edge in edges.values():
			if edge.count!=1: continue
			for index in [edge.a,edge.b]:
				var point_key = key(vertices[index])
				outward_at[point_key] = outward_at.get(point_key,Vector3.ZERO)+edge.outward
		var positions = PackedVector3Array(); var texcoords = PackedVector2Array(); var shades = PackedColorArray()
		for edge in edges.values():
			if edge.count!=1: continue
			var a = int(edge.a); var b = int(edge.b)
			var top_a = vertices[a]; var top_b = vertices[b]
			var bottom_a = Vector3(top_a.x,.005,top_a.z); var bottom_b = Vector3(top_b.x,.005,top_b.z)
			if cutout:
				# A heap spreads onto the ground instead of ending in a vertical
				# block. Shared vertex offsets close the corners without seams.
				bottom_a += outward_at[key(top_a)].normalized()*.45
				bottom_b += outward_at[key(top_b)].normalized()*.45
			if maxf(top_a.y,top_b.y)<=.015: continue
			var corners = [top_a,top_b,bottom_b,bottom_a]
			# Give new walls independent tiled UVs, not stretched top-edge pixels.
			var length = Vector2(top_b.x-top_a.x,top_b.z-top_a.z).length()/.8
			var texture_corners = [Vector2(0,top_a.y/.8),Vector2(length,top_b.y/.8),Vector2(length,.005/.8),Vector2(0,.005/.8)]
			for corner in [0,1,2,0,2,3]:
				positions.append(corners[corner]); texcoords.append(texture_corners[corner])
				var color = colors[a if corner in [0,3] else b]
				# New side geometry gets a discrete darker tone for readable depth.
				shades.append(Color(color.r*.8,color.g*.8,color.b*.8,color.a))
		if not positions.is_empty():
			var side_arrays = []; side_arrays.resize(Mesh.ARRAY_MAX)
			side_arrays[Mesh.ARRAY_VERTEX] = positions; side_arrays[Mesh.ARRAY_TEX_UV] = texcoords; side_arrays[Mesh.ARRAY_COLOR] = shades
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,side_arrays)
			mesh.surface_set_name(mesh.get_surface_count()-1,"experimental_closed_leaf_edges")
			var side_material: ShaderMaterial = mesh.surface_get_material(surface).duplicate()
			side_material.shader = SIDES; side_material.set_shader_parameter("remove_green",cutout)
			mesh.surface_set_material(mesh.get_surface_count()-1,side_material)
	if cutout:
		for surface in range(source.get_surface_count()): mesh.surface_get_material(surface).shader = CUTOUT
	return mesh

static func add_top_collision(node: MeshInstance3D,source: ArrayMesh):
	var body = StaticBody3D.new(); body.name = "NativeTerrainTop"
	var shape = CollisionShape3D.new(); shape.shape = source.create_trimesh_shape()
	body.add_child(shape); node.add_child(body)

static func setup(lab):
	# Separate extension keeps 20m-wide samples away from existing stations.
	var floor = StaticBody3D.new(); floor.name = "LeafHeapExperimentFloor"; floor.position = Vector3(0,-.5,-55)
	var collision = CollisionShape3D.new(); collision.shape = BoxShape3D.new(); collision.shape.size = Vector3(80,1,30)
	floor.add_child(collision)
	var floor_visual = MeshInstance3D.new(); floor_visual.mesh = BoxMesh.new(); floor_visual.mesh.size = Vector3(80,1,30)
	var floor_material = StandardMaterial3D.new(); floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color(.25,.36,.22); floor_visual.material_override = floor_material; floor.add_child(floor_visual); lab.add_child(floor)
	var source: ArrayMesh = load("res://assets/levels/lvl_04/foliage/leaf_heap.tres")
	var meshes = [original_reference(source),close_edges(source,false),close_edges(source,true)]
	var labels = ["A: ORIGINAL\nDOS CARAS / SIN GROSOR","B: VOLUMEN\nBORDES CERRADOS","C: VOLUMEN SUAVE\nBORDES INCLINADOS / RECORTE"]
	for i in range(3):
		var sample = MeshInstance3D.new(); sample.name = "LeafHeapExperiment_"+str(i)
		sample.mesh = meshes[i]; sample.position = Vector3(-25+i*25,0,-56)
		sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lab.add_child(sample); add_top_collision(sample,source)
		lab.add_child(LabFloorLabel.create(labels[i],Vector3(sample.position.x,.035,-43),21))
	lab.add_child(LabFloorLabel.create("PRUEBAS DE HOJARASCA\nA / B / C AL FONDO",Vector3(1,.035,-38),25))
