extends RefCounted
# Extract real map triangles; no invented volume, UVs, scaling or billboards.
const BASE = "res://assets/levels/lvl_04/"
const LABELS = ["D: FRAGMENTO / MATERIAL ACTUAL", "E: OPACO / DOS CARAS", "F: OPACO / DESCARTAR REVERSO", "G: OPACO / DESCARTAR FRENTE"]

static func extract_fragment() -> ArrayMesh:
	var source: ArrayMesh = load(BASE+"scenery.tres")
	var bounds = AABB()
	var initialized = false
	for s in range(source.get_surface_count()):
		if not source.surface_get_name(s).begins_with("native_leaf_heap"): continue
		for p in source.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if not initialized: bounds = AABB(p,Vector3.ZERO); initialized = true
			else: bounds = bounds.expand(p)
	assert(initialized,"Native leaf surface missing")
	var center = bounds.get_center(); center.y = bounds.position.y
	bounds = bounds.grow(3.0)
	var mesh = ArrayMesh.new()
	for s in range(source.get_surface_count()):
		var original = source.surface_get_arrays(s)
		var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		var selected = PackedInt32Array()
		for i in range(0,indices.size(),3):
			var triangle_bounds = AABB(vertices[indices[i]],Vector3.ZERO)
			triangle_bounds = triangle_bounds.expand(vertices[indices[i+1]]).expand(vertices[indices[i+2]])
			if bounds.intersects(triangle_bounds.grow(.001)):
				selected.append_array(indices.slice(i,i+3))
		if selected.is_empty(): continue
		# Keep complete triangles, including those crossing the crop boundary.
		var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
		for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
			if original[slot] == null or original[slot].is_empty(): continue
			var values = original[slot].slice(0,0)
			for index in selected:
				values.append(original[slot][index]-center if slot==Mesh.ARRAY_VERTEX else original[slot][index])
			arrays[slot] = values
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var last = mesh.get_surface_count()-1
		mesh.surface_set_name(last,source.surface_get_name(s))
		mesh.surface_set_material(last,source.surface_get_material(s))
	mesh.set_meta("source_origin",center)
	return mesh

static func variant(source: ArrayMesh,mode: int) -> ArrayMesh:
	var mesh: ArrayMesh = source.duplicate()
	for s in range(mesh.get_surface_count()):
		if not mesh.surface_get_name(s).begins_with("native_leaf_heap"): continue
		var material: ShaderMaterial = source.surface_get_material(s).duplicate()
		if mode > 0:
			var shader = Shader.new()
			var culling = ["cull_disabled","cull_disabled","cull_back","cull_front"][mode]
			shader.code = 'shader_type spatial;\nrender_mode depth_draw_opaque, %s, unshaded, fog_disabled;\n#include "res://shaders/legacy_color.gdshaderinc"\nvoid fragment(){ ALBEDO=legacy_output(sample_page(UV).rgb*COLOR.rgb*vertex_color_scale); }'%culling
			material.shader = shader
		mesh.surface_set_material(s,material)
	return mesh

static func setup(lab):
	var source = extract_fragment()
	var spacing = maxf(source.get_aabb().size.x+6,30)
	var depth = maxf(source.get_aabb().size.z+6,30)
	for mode in range(4):
		var sample = MeshInstance3D.new(); sample.name = "LeafMapFragment_"+str(mode)
		sample.mesh = variant(source,mode)
		sample.position = Vector3((mode%2-.5)*spacing,0,-100-depth*(mode/2))
		sample.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lab.add_child(sample)
		preload("res://scripts/testing/experiments/leaf_heap_experiments.gd").add_top_collision(sample,source)
		lab.add_child(LabFloorLabel.create(LABELS[mode],sample.position+Vector3(0,.04,depth*.5),18))
	# A continuous walkway lets the player reach and circle all four copies.
	var floor = StaticBody3D.new(); floor.name = "LeafMapFragmentFloor"
	floor.position = Vector3(0,-.55,-70-depth)
	var shape = BoxShape3D.new(); shape.size = Vector3(spacing*2+8,1,depth*3+20)
	var collision = CollisionShape3D.new(); collision.shape = shape; floor.add_child(collision)
	var visual = MeshInstance3D.new(); visual.mesh = BoxMesh.new(); visual.mesh.size = shape.size
	var material = StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.25,.36,.22); visual.material_override = material; floor.add_child(visual)
	lab.add_child(floor)
	lab.add_child(LabFloorLabel.create("FRAGMENTOS REALES DEL NIVEL 04\nD / E DELANTE - F / G AL FONDO",Vector3(0,.05,-71),20))
