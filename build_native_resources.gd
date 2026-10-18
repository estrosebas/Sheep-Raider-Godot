@tool
extends SceneTree

# build_native_resources.gd
# Generates native Godot 4 .tres resources with authentic PS1/PC unshaded shaders:
# 1. res://assets/levels/lvl_00/scenery.tres
# 2. res://assets/levels/lvl_00/level_objects.tres
# 3. res://assets/models/daffy.tres
# 4. res://assets/models/sheep.tres
# 5. res://assets/models/ralph_wolf.tres (Skinned ArrayMesh)
# 6. res://assets/models/ralph_animations.tres (AnimationLibrary)

var shader_opaque: Shader
var shader_blend: Shader
var shader_add: Shader
const Space = preload("res://scripts/levels/game_space.gd")

func _init() -> void:
	print("==================================================")
	print("=== BUILDING NATIVE GODOT 4 SCENERY & OBJECTS ====")
	print("==================================================")
	
	shader_opaque = load("res://shaders/retro_opaque.gdshader")
	shader_blend = load("res://shaders/retro_blend.gdshader")
	shader_add = load("res://shaders/retro_add.gdshader")
	
	build_scenery()
	build_scenery("res://assets/levels/lvl_00/data/sky_data.json", "res://assets/levels/lvl_00/sky.tres")
	build_level_objects()
	if FileAccess.file_exists("res://assets/levels/lvl_00/data/rocket_data.json"):
		build_character("res://assets/levels/lvl_00/data/rocket_data.json", "res://assets/levels/lvl_00/rocket.tres", "Rocket")
	if FileAccess.file_exists("res://assets/levels/lvl_00/data/falling_rock_data.json"):
		build_character("res://assets/levels/lvl_00/data/falling_rock_data.json", "res://assets/levels/lvl_00/falling_rock.tres", "FallingRock")
	build_character("res://assets/models/daffy_data.json", "res://assets/models/daffy.tres", "Daffy")
	build_character("res://assets/models/sheep_data.json", "res://assets/models/sheep.tres", "Sheep")
	build_ralph_and_animations()
	
	print("==================================================")
	print("=== ALL RESOURCES BUILT AND SAVED SUCCESSFULLY ===")
	print("==================================================")
	quit(0)

func create_retro_material(page: int) -> Material:
	var mat = ShaderMaterial.new()
	if page in [9, 10, 11, 12]:
		mat.shader = shader_blend
		mat.render_priority = 1
		var tex_path = "res://assets/levels/lvl_00/textures/page_%d.png" % page
		if ResourceLoader.exists(tex_path):
			mat.set_shader_parameter("albedo_texture", load(tex_path))
	elif page == 13:
		mat.shader = shader_add
		mat.render_priority = 1
		var tex_path = "res://assets/levels/lvl_00/textures/page_%d.png" % page
		if ResourceLoader.exists(tex_path):
			mat.set_shader_parameter("albedo_texture", load(tex_path))
	elif page >= 0:
		mat.shader = shader_opaque
		mat.set_shader_parameter("is_textured", true)
		var tex_path = "res://assets/levels/lvl_00/textures/page_%d.png" % page
		if ResourceLoader.exists(tex_path):
			mat.set_shader_parameter("albedo_texture", load(tex_path))
	else:
		mat.shader = shader_opaque
		mat.set_shader_parameter("is_textured", false)
	# COLOR is RGBA8: store original bytes / 255, recover / 128 in shader.
	mat.set_shader_parameter("vertex_color_scale", 255.0 / 128.0 if page >= 0 else 1.0)
	if page >= 0:
		var tex_path = "res://assets/levels/lvl_00/textures/page_%d.png" % page
		if ResourceLoader.exists(tex_path):
			mat.set_shader_parameter("albedo_texture_linear", load(tex_path))
	return mat

func encode_vertex_color(c: Array, page: int) -> Color:
	var divisor = 128.0 if page >= 0 else 255.0
	return Color(round(c[0] * divisor) / 255.0,
		round(c[1] * divisor) / 255.0,
		round(c[2] * divisor) / 255.0, 1.0)

func build_scenery(source: String = "res://assets/levels/lvl_00/data/scenery_world_data.json", destination: String = "res://assets/levels/lvl_00/scenery.tres") -> void:
	var f = FileAccess.open(source, FileAccess.READ)
	if not f:
		printerr("Cannot open scenery_data.json")
		return
	var json = JSON.new()
	json.parse(f.get_as_text())
	var scen_data: Dictionary = json.data
	
	var mesh = ArrayMesh.new()
	var page_keys = scen_data.keys()
	page_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	var surf_idx = 0
	for pk in page_keys:
		var grp = scen_data[pk]
		var page = int(grp["page"])
		var verts = grp["verts"]
		var uvs = grp["uvs"]
		var cols = grp["cols"]
		
		var p_verts = PackedVector3Array()
		var p_uvs = PackedVector2Array()
		var p_cols = PackedColorArray()
		var p_indices = PackedInt32Array()
		
		var n_v = verts.size()
		p_verts.resize(n_v)
		p_uvs.resize(n_v)
		p_cols.resize(n_v)
		p_indices.resize(n_v)
		
		for i in range(n_v):
			var v = verts[i]
			var u = uvs[i]
			var c = cols[i]
			p_verts[i] = Vector3(v[0], v[1], v[2])
			p_uvs[i] = Vector2(u[0], u[1])
			p_cols[i] = encode_vertex_color(c, page)
			p_indices[i] = i
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p_verts
		arrays[Mesh.ARRAY_TEX_UV] = p_uvs
		arrays[Mesh.ARRAY_COLOR] = p_cols
		arrays[Mesh.ARRAY_INDEX] = p_indices
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surf_idx, "mat_page_%d" % page)
		mesh.surface_set_material(surf_idx, create_retro_material(page))
		surf_idx += 1
		print("Added Scenery Surface ", surf_idx - 1, ": mat_page_", page, " (", n_v / 3, " tris)")

	var err = ResourceSaver.save(Space.mesh_from_export(mesh), destination)
	if err == OK:
		print("-> Saved ", destination, " successfully!")
	else:
		printerr("Failed to save scenery.tres: ", err)

func build_level_objects() -> void:
	var path = "res://assets/levels/lvl_00/data/puzzle_static_data.json"
	if not FileAccess.file_exists(path):
		path = "res://assets/levels/lvl_00/data/level_static_data.json"
	if not FileAccess.file_exists(path):
		path = "res://assets/levels/lvl_00/data/level_objects_data.json"
	if not FileAccess.file_exists(path):
		return
	var f = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	json.parse(f.get_as_text())
	var obj_data: Dictionary = json.data
	
	var mesh = ArrayMesh.new()
	var page_keys = obj_data.keys()
	page_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	var surf_idx = 0
	for pk in page_keys:
		var grp = obj_data[pk]
		var page = int(pk)
		var verts = grp["verts"]
		var uvs = grp["uvs"]
		var cols = grp["cols"]
		
		var p_verts = PackedVector3Array()
		var p_uvs = PackedVector2Array()
		var p_cols = PackedColorArray()
		var p_indices = PackedInt32Array()
		
		var n_v = verts.size()
		if n_v == 0:
			continue
		p_verts.resize(n_v)
		p_uvs.resize(n_v)
		p_cols.resize(n_v)
		p_indices.resize(n_v)
		
		for i in range(n_v):
			var v = verts[i]
			var u = uvs[i]
			var c = cols[i]
			p_verts[i] = Vector3(v[0], v[1], v[2])
			p_uvs[i] = Vector2(u[0], u[1])
			p_cols[i] = encode_vertex_color(c, page)
			p_indices[i] = i
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p_verts
		arrays[Mesh.ARRAY_TEX_UV] = p_uvs
		arrays[Mesh.ARRAY_COLOR] = p_cols
		arrays[Mesh.ARRAY_INDEX] = p_indices
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surf_idx, "obj_page_%d" % page)
		mesh.surface_set_material(surf_idx, create_retro_material(page))
		surf_idx += 1
		print("Added Objects Surface ", surf_idx - 1, ": obj_page_", page, " (", n_v / 3, " tris)")

	var err = ResourceSaver.save(Space.mesh_from_export(mesh), "res://assets/levels/lvl_00/level_objects.tres")
	if err == OK:
		print("-> Saved res://assets/levels/lvl_00/level_objects.tres successfully!")

func build_character(json_path: String, out_tres: String, char_name: String) -> void:
	if not FileAccess.file_exists(json_path):
		return
	var f = FileAccess.open(json_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(f.get_as_text())
	var c_data: Dictionary = json.data
	
	var mesh = ArrayMesh.new()
	var page_keys = c_data.keys()
	page_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	var surf_idx = 0
	for pk in page_keys:
		var grp = c_data[pk]
		var page = int(grp["page"])
		var verts = grp["verts"]
		var uvs = grp["uvs"]
		var cols = grp["cols"]
		
		var p_verts = PackedVector3Array()
		var p_uvs = PackedVector2Array()
		var p_cols = PackedColorArray()
		var p_indices = PackedInt32Array()
		
		var n_v = verts.size()
		p_verts.resize(n_v)
		p_uvs.resize(n_v)
		p_cols.resize(n_v)
		p_indices.resize(n_v)
		
		for i in range(n_v):
			var v = verts[i]
			var u = uvs[i]
			var c = cols[i]
			p_verts[i] = Vector3(v[0], v[1], v[2])
			p_uvs[i] = Vector2(u[0], u[1])
			p_cols[i] = encode_vertex_color(c, page)
			p_indices[i] = i
			
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p_verts
		arrays[Mesh.ARRAY_TEX_UV] = p_uvs
		arrays[Mesh.ARRAY_COLOR] = p_cols
		arrays[Mesh.ARRAY_INDEX] = p_indices
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surf_idx, "mat_page_%d" % page)
		mesh.surface_set_material(surf_idx, create_retro_material(page))
		surf_idx += 1
		
	var err = ResourceSaver.save(Space.mesh_from_export(mesh), out_tres)
	if err == OK:
		print("-> Saved ", out_tres, " (", char_name, ") successfully!")

func build_ralph_and_animations() -> void:
	var r_file = FileAccess.open("res://assets/models/ralph_data.json", FileAccess.READ)
	if not r_file:
		printerr("Cannot open ralph_data.json")
		return
	var r_json = JSON.new()
	r_json.parse(r_file.get_as_text())
	var r_data: Dictionary = r_json.data
	
	# Build Ralph Skinned ArrayMesh
	var ralph_mesh = ArrayMesh.new()
	var surfaces_dict = r_data["surfaces"]
	var surf_keys = surfaces_dict.keys()
	surf_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	var s_idx = 0
	for pk in surf_keys:
		var grp = surfaces_dict[pk]
		var page = int(grp["page"])
		var verts = grp["verts"]
		var uvs = grp["uvs"]
		var cols = grp["cols"]
		var bones = grp["bones"]
		var weights = grp["weights"]
		
		var p_verts = PackedVector3Array()
		var p_uvs = PackedVector2Array()
		var p_cols = PackedColorArray()
		var p_bones = PackedInt32Array()
		var p_weights = PackedFloat32Array()
		var p_indices = PackedInt32Array()
		
		var n_v = verts.size()
		p_verts.resize(n_v)
		p_uvs.resize(n_v)
		p_cols.resize(n_v)
		p_bones.resize(n_v * 4)
		p_weights.resize(n_v * 4)
		p_indices.resize(n_v)
		
		for i in range(n_v):
			var v = verts[i]
			var u = uvs[i]
			var c = cols[i]
			var b = bones[i]
			var w = weights[i]
			
			p_verts[i] = Vector3(v[0], v[1], v[2])
			p_uvs[i] = Vector2(u[0], u[1])
			p_cols[i] = encode_vertex_color(c, page)
			p_indices[i] = i
			
			for bi in range(4):
				p_bones[i * 4 + bi] = int(b[bi])
				p_weights[i * 4 + bi] = float(w[bi])
				
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = p_verts
		arrays[Mesh.ARRAY_TEX_UV] = p_uvs
		arrays[Mesh.ARRAY_COLOR] = p_cols
		arrays[Mesh.ARRAY_BONES] = p_bones
		arrays[Mesh.ARRAY_WEIGHTS] = p_weights
		arrays[Mesh.ARRAY_INDEX] = p_indices
		
		ralph_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		ralph_mesh.surface_set_name(s_idx, "mat_page_%d" % page)
		ralph_mesh.surface_set_material(s_idx, create_retro_material(page))
		s_idx += 1
		print("Added Ralph Surface ", s_idx - 1, ": mat_page_", page, " (", n_v / 3, " tris)")
		
	var err_m = ResourceSaver.save(ralph_mesh, "res://assets/models/ralph_wolf.tres")
	if err_m == OK:
		print("-> Saved res://assets/models/ralph_wolf.tres successfully!")

	if FileAccess.file_exists("res://assets/models/ralph_animations.tres"):
		print("-> Preserved authentic res://assets/models/ralph_animations.tres!")
