extends SceneTree
const Space = preload("res://scripts/levels/game_space.gd")

func _init() -> void:
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	for definition in definitions.values():
		var base = "res://assets/items/" + definition["slug"]
		var data = JSON.parse_string(FileAccess.get_file_as_string(base + "/mesh_data.json"))
		var mesh = build_mesh(base, data, definition)
		var error = ResourceSaver.save(Space.mesh_from_export(mesh), definition["mesh"])
		if error != OK:
			quit(error)
			return
		if FileAccess.file_exists(base + "/worn_data.json"):
			build_costume(base, definition)
		var scenes = {"magnet":"Magnet", "sheep_costume":"SheepCostume", "ghost_costume":"GhostCostume", "lettuce":"Lettuce", "perfume":"Perfume", "fan":"Fan", "rocket":"Rocket", "dynamite":"Dynamite", "flute":"Flute"}
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/items"))
		var scene_file = FileAccess.open("res://scenes/items/%s.tscn" % scenes[definition["slug"]], FileAccess.WRITE)
		scene_file.store_string('[gd_scene load_steps=3 format=3]\n[ext_resource type="Script" path="res://scripts/items/%s_item.gd" id="1"]\n[ext_resource type="ArrayMesh" path="%s" id="2"]\n[node name="%s" type="Node3D"]\nscript = ExtResource("1")\nclass_id = %d\n[node name="Visual" type="MeshInstance3D" parent="."]\nmesh = ExtResource("2")\nposition = Vector3(0, %f, 0)\n' % [definition["slug"], definition["mesh"], scenes[definition["slug"]], int(definition["class_id"]), -mesh.get_aabb().position.y])
		print("Shared item: ", definition["label"], " · ", mesh.get_surface_count(), " surfaces")
	quit()

func build_mesh(base: String, data: Dictionary, definition: Dictionary) -> ArrayMesh:
		var mesh = ArrayMesh.new()
		for page_key in data:
			var group = data[page_key]
			var page = int(page_key)
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			var vertices = PackedVector3Array()
			var uvs = PackedVector2Array()
			var colors = PackedColorArray()
			var bones = PackedInt32Array()
			var weights = PackedFloat32Array()
			for i in range(group["verts"].size()):
				var v = group["verts"][i]
				var uv = group["uvs"][i]
				var c = group["cols"][i]
				vertices.append(Vector3(v[0], v[1], v[2]))
				uvs.append(Vector2(uv[0], uv[1]))
				var divisor = 128.0 if page >= 0 else 255.0
				colors.append(Color(round(c[0]*divisor)/255.0, round(c[1]*divisor)/255.0, round(c[2]*divisor)/255.0))
				if group.has("bones"):
					bones.append_array(PackedInt32Array([int(group["bones"][i]), 0, 0, 0]))
					weights.append_array(PackedFloat32Array([1, 0, 0, 0]))
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_COLOR] = colors
			if group.has("bones"):
				arrays[Mesh.ARRAY_BONES] = bones
				arrays[Mesh.ARRAY_WEIGHTS] = weights
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_name(mesh.get_surface_count()-1,"mat_page_%d" % page)
			var kind = str(definition["materials"].get(page_key, "opaque"))
			var shader_name = "blend" if kind == "blend" else ("add" if kind == "add" else "opaque")
			var material = ShaderMaterial.new()
			material.shader = load("res://shaders/retro_%s.gdshader" % shader_name)
			material.set_shader_parameter("is_textured", page >= 0)
			material.set_shader_parameter("vertex_color_scale", 255.0/128.0 if page >= 0 else 1.0)
			if page >= 0:
				var texture = load(str(definition.get("texture_directory",base)) + "/textures/page_%d.png" % page)
				material.set_shader_parameter("albedo_texture", texture)
				material.set_shader_parameter("albedo_texture_linear", texture)
			mesh.surface_set_material(mesh.get_surface_count()-1, material)
		return mesh

func build_costume(base: String, definition: Dictionary) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(base + "/worn_data.json"))
	ResourceSaver.save(build_mesh(base, data["surfaces"], definition), base + "/worn.tres")
	var library = AnimationLibrary.new()
	for name in data["animations"]:
		var source = data["animations"][name]
		var animation = Animation.new()
		animation.length = source["duration"]
		var loops = name in ["idle", "walk", "sneak", "fall"] or name in definition.get("loop_animations",[])
		animation.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
		for joint in range(data["joints"].size()):
			var offset = data["joints"][joint]["offset"]
			var rest = Vector3(offset[0], offset[1], offset[2])
			var tracks = [animation.add_track(Animation.TYPE_ROTATION_3D), animation.add_track(Animation.TYPE_POSITION_3D), animation.add_track(Animation.TYPE_SCALE_3D)]
			for track in tracks:
				animation.track_set_path(track, NodePath("Skeleton3D:joint_%02d" % joint))
			for index in range(source["frames"].size()):
				var pose = source["frames"][index]["joints"][joint]
				var r = pose["rot"]
				var p = pose["pos"]
				var s = pose["scale"]
				var axis_sign = data.get("rotation_axis_sign",[1,1,1])
				var order = EULER_ORDER_ZXY if data.get("rotation_order","") == "ZXY" else EULER_ORDER_YXZ
				var rotation = Basis.from_euler(Vector3(r[0]*axis_sign[0],r[1]*axis_sign[1],r[2]*axis_sign[2]),order).get_rotation_quaternion()
				var position = rest + Vector3(p[0], p[1], p[2])
				var scale = Vector3(s[0], s[1], s[2])
				var time = 0.0 if index == 0 else source["frames"][index-1]["time"]
				animation.rotation_track_insert_key(tracks[0], time, rotation)
				animation.position_track_insert_key(tracks[1], time, position)
				animation.scale_track_insert_key(tracks[2], time, scale)
				if index == 0 and loops:
					animation.rotation_track_insert_key(tracks[0], animation.length, rotation)
					animation.position_track_insert_key(tracks[1], animation.length, position)
					animation.scale_track_insert_key(tracks[2], animation.length, scale)
		library.add_animation(name, animation)
	ResourceSaver.save(library, base + "/animations.tres")
	var file = FileAccess.open(base + "/worn.tscn", FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/items/costume_visual.gd" id="1"]\n[node name="CostumeVisual" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % base)
