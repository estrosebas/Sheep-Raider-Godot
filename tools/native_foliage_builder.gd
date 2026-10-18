extends RefCounted
# Shared by full level and standalone builders; no SceneTree constructor.
# Historical level material retained during lab experiments. Sharing Ralph's
# backface shader did NOT fix this open terrain sheet; see LEAF_HEAPS.md.
# Do not promote a new lab variant to the map until it has been chosen visually.
static func build(base: String,data: Dictionary,manifest: Dictionary,builder) -> ArrayMesh:
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/foliage.json"))
	var page = str(int(metadata.page))
	var selected = {}
	for index in metadata.triangles: selected[int(index)] = true
	var remaining = data.duplicate(true)
	var heap = {}
	for key in data[page]:
		remaining[page][key] = []; heap[key] = []
	for i in range(data[page].verts.size()):
		var target = heap if selected.has(int(i/3)) else remaining[page]
		for key in heap: target[key].append(data[page][key][i])
	var mesh = GameSpace.mesh_from_export(builder.build_mesh(base,remaining,manifest))
	var foliage = GameSpace.mesh_from_export(builder.build_mesh(base,{page:heap},manifest))
	foliage = apply_foliage_material(foliage)
	for surface in range(foliage.get_surface_count()):
		mesh.add_surface_from_arrays(foliage.surface_get_primitive_type(surface),foliage.surface_get_arrays(surface))
		mesh.surface_set_name(mesh.get_surface_count()-1,"native_leaf_heap_page_%s"%page)
		mesh.surface_set_material(mesh.get_surface_count()-1,foliage.surface_get_material(surface))
	var sample_data = JSON.parse_string(FileAccess.get_file_as_string(base+"/foliage/sample_data.json"))
	var sample = GameSpace.mesh_from_export(builder.build_mesh(base,sample_data,manifest))
	sample = apply_foliage_material(sample)
	ResourceSaver.save(sample,base+"/foliage/leaf_heap.tres")
	var scene = FileAccess.open(base+"/foliage/leaf_heap.tscn",FileAccess.WRITE)
	scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="ArrayMesh" path="%s/foliage/leaf_heap.tres" id="1"]\n[node name="NativeLeafHeap" type="MeshInstance3D"]\nmesh = ExtResource("1")\n'%base)
	print("Native foliage: ",metadata.triangles.size()," map triangles; ",metadata.sample_triangles," lab triangles")
	return mesh

static func apply_foliage_material(mesh: ArrayMesh) -> ArrayMesh:
	var output = ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Static export reverses winding in GameSpace.mesh_from_export, while
		# Ralph's shader-skinned native foliage keeps its original winding.
		# Restore that facing for the shared cull_back shader. Positions, UV,
		# colors and triangle topology stay unchanged.
		for i in range(0,indices.size(),3):
			var temporary = indices[i+1]; indices[i+1] = indices[i+2]; indices[i+2] = temporary
		arrays[Mesh.ARRAY_INDEX] = indices
		output.add_surface_from_arrays(mesh.surface_get_primitive_type(surface),arrays)
		output.surface_set_name(surface,mesh.surface_get_name(surface))
		var material: ShaderMaterial = mesh.surface_get_material(surface)
		material.shader = preload("res://shaders/bush_backface_cutout.gdshader")
		output.surface_set_material(surface,material)
	return output
