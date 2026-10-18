extends SceneTree
const Space = preload("res://scripts/levels/game_space.gd")

# Checks the serialized mesh bytes and actual GPU output, including alpha/add.
var failures: int = 0

func _init() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func verify() -> void:
	var sources = {
		"assets/levels/lvl_00/data/scenery_world_data.json": "assets/levels/lvl_00/scenery.tres",
		"assets/levels/lvl_00/data/sky_data.json": "assets/levels/lvl_00/sky.tres",
		"assets/levels/lvl_00/data/puzzle_static_data.json": "assets/levels/lvl_00/level_objects.tres",
		"assets/levels/lvl_00/data/rocket_data.json": "assets/levels/lvl_00/rocket.tres",
		"assets/models/daffy_data.json": "assets/models/daffy.tres",
		"assets/models/sheep_data.json": "assets/models/sheep.tres",
		"assets/models/ralph_data.json": "assets/models/ralph_wolf.tres"
	}
	for definition in JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_00/puzzle/definitions.json"))["objects"]:
		var directory: String = definition["directory"].trim_prefix("res://")
		sources[directory+"/worn_data.json"] = directory+"/worn.tres"
	var vertices = 0
	for source in sources:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + source))
		if data.has("surfaces"):
			data = data["surfaces"]
		var mesh: ArrayMesh = load("res://" + sources[source])
		for s in range(mesh.get_surface_count()):
			var page = int(mesh.surface_get_name(s).get_slice("page_", 1))
			var colors: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
			var material: ShaderMaterial = mesh.surface_get_material(s)
			var gain: float = material.get_shader_parameter("vertex_color_scale")
			var original = data[str(page)]["cols"]
			check(colors.size() == original.size(), "Vertex count: " + source)
			for i in range(colors.size()):
				var c = colors[i]
				for channel in range(3):
					check(abs(c[channel] * gain - original[i][channel]) < 0.0001,
						"Clipped/incorrect vertex color: %s page %d vertex %d" % [source, page, i])
			vertices += colors.size()
	for page in range(14):
		var path = "res://assets/levels/lvl_00/textures/page_%d.png" % page
		var original = Image.load_from_file(ProjectSettings.globalize_path(path))
		var imported: Texture2D = load(path)
		check(imported.get_image().get_data() == original.get_data(), "Lossy import: " + path)
		check(not imported.get_image().has_mipmaps(), "Unexpected mipmaps: " + path)
	print("Verified ", vertices, " vertex colors and 14 imported pages.")
	verify_shared_items()

	var viewport = SubViewport.new()
	viewport.size = Vector2i(400, 100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.2, 0.3, 0.4)
	viewport.add_child(world)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	camera.position.z = 2.0
	viewport.add_child(camera)
	camera.current = true
	var expected = []
	for index in range(4):
		var name = ["opaque", "opaque", "blend", "add"][index]
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/retro_%s.gdshader" % name)
		mat.set_shader_parameter("vertex_color_scale", 255.0 / 128.0)
		var tex_image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		tex_image.set_pixel(0, 0, Color8(80, 120, 160, 128))
		var texture = ImageTexture.create_from_image(tex_image)
		mat.set_shader_parameter("albedo_texture", texture)
		mat.set_shader_parameter("albedo_texture_linear", texture)
		if index == 0:
			mat.set_shader_parameter("is_textured", false)
			mat.set_shader_parameter("vertex_color_scale", 1.0)
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.45, -0.45, 0), Vector3(0.45, -0.45, 0), Vector3(0.45, 0.45, 0),
			Vector3(-0.45, -0.45, 0), Vector3(0.45, 0.45, 0), Vector3(-0.45, 0.45, 0)])
		var col = Color8(192, 64, 240)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray([col, col, col, col, col, col])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		var mesh = ArrayMesh.new()
		var flags = 0
		if index == 1:
			# Exercise the actual skinning shader: shift vertices right, then
			# translate their bone left so the expected colored center is restored.
			var custom = PackedFloat32Array()
			for vertex in range(6):
				arrays[Mesh.ARRAY_VERTEX][vertex].x += 1.0
				custom.append_array(PackedFloat32Array([0, 0, 0, 0]))
			arrays[Mesh.ARRAY_CUSTOM0] = custom
			flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
			var palette: Array[Transform3D] = []
			for joint in range(32):
				palette.append(Transform3D(Basis.IDENTITY, Vector3(-1, 0, 0)))
			mat.set_shader_parameter("use_legacy_skin", true)
			mat.set_shader_parameter("legacy_joint_palette", palette)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = mat
		instance.position.x = index - 1.5
		viewport.add_child(instance)
		var c = Vector3(80.0 / 255 * 192 / 128, 120.0 / 255 * 64 / 128, 160.0 / 255 * 240 / 128)
		c = c.clamp(Vector3.ZERO, Vector3.ONE)
		if index == 0:
			c = Vector3(192.0 / 255, 64.0 / 255, 240.0 / 255)
		elif index == 2:
			c = c * (128.0 / 255) + Vector3(0.2, 0.3, 0.4) * (127.0 / 255)
		elif index == 3:
			c = c * (128.0 / 255) + Vector3(0.2, 0.3, 0.4)
		expected.append(c)
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var result = viewport.get_texture().get_image()
	for index in range(4):
		var color = result.get_pixel(50 + 100 * index, 50)
		var got = Vector3(color.r, color.g, color.b)
		check(got.distance_to(expected[index]) < 0.015,
			"GPU sample %d: got %s expected %s" % [index, got, expected[index]])
	print("GPU untextured, HDR modulation, alpha and additive checks: ", failures, " failures.")
	quit(1 if failures else 0)

func verify_shared_items() -> void:
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	var checked = 0
	var pages = 0
	for definition in definitions.values():
		var base = "res://assets/items/" + definition["slug"]
		var sources = {base + "/mesh_data.json": definition["mesh"]}
		if FileAccess.file_exists(base + "/worn_data.json"):
			sources[base + "/worn_data.json"] = base + "/worn.tres"
		for source in sources:
			var data = JSON.parse_string(FileAccess.get_file_as_string(source))
			if data.has("surfaces"):
				data = data["surfaces"]
			var mesh: ArrayMesh = load(sources[source])
			check(mesh.get_surface_count() == data.size(), "Shared surface count: " + source)
			var surface = 0
			for page in data:
				var group = data[page]
				var arrays = mesh.surface_get_arrays(surface)
				var gain = mesh.surface_get_material(surface).get_shader_parameter("vertex_color_scale")
				check(arrays[Mesh.ARRAY_VERTEX].size() == group["verts"].size(), "Shared vertex count: " + source)
				for i in range(group["verts"].size()):
					var position = group["verts"][i]
					var expected_position = Vector3(position[0],position[1],position[2])
					if not group.has("bones"):
						expected_position = Space.from_export(expected_position)
					check(arrays[Mesh.ARRAY_VERTEX][i].distance_to(expected_position) < 0.00001, "Shared position: " + source)
					for channel in range(3):
						check(abs(arrays[Mesh.ARRAY_COLOR][i][channel] * gain - group["cols"][i][channel]) < 0.0001, "Shared color: " + source)
					if group.has("bones"):
						check(arrays[Mesh.ARRAY_BONES][i*4] == int(group["bones"][i]), "Costume vertex joint: " + source)
					checked += 1
				surface += 1
		for filename in DirAccess.get_files_at(base + "/textures"):
			if filename.ends_with(".png"):
				var path = base + "/textures/" + filename
				var texture: Texture2D = load(path)
				check(texture.get_image().get_data() == Image.load_from_file(ProjectSettings.globalize_path(path)).get_data(), "Shared texture bytes: " + path)
				check(not texture.get_image().has_mipmaps(), "Shared texture mipmaps: " + path)
				pages += 1
	print("Verified shared items: ", checked, " vertices / ", pages, " imported pages.")
