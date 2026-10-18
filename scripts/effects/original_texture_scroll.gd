extends Node
class_name OriginalTextureScroll
var regions: Array
var pages: Dictionary = {}
var ticks = 0
var elapsed = 0.0
func _ready() -> void:
	var base: String = get_parent().asset_directory
	regions = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/texture_scroll.json"))
	for region in regions:
		var page = int(region["page"])
		if pages.has(page): continue
		# ResourceLoader resolves imported textures inside an exported PCK.
		var page_texture: Texture2D = load(base+"/textures/page_%d.png" % page)
		var source = page_texture.get_image()
		if source.is_compressed(): source.decompress()
		var texture = ImageTexture.create_from_image(source)
		pages[page] = {"source":source,"image":source.duplicate(),"texture":texture}
	for mesh in get_parent().find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		var copied_mesh = false
		for surface in range(mesh.mesh.get_surface_count()):
			var page = int(mesh.mesh.surface_get_name(surface).trim_prefix("mat_page_"))
			if not pages.has(page): continue
			var material = mesh.mesh.surface_get_material(surface)
			if material is ShaderMaterial:
				var original: Texture2D = material.get_shader_parameter("albedo_texture")
				# Page IDs are local to each DAV. Ralph/shared items retain their
				# own atlases even when they also have a surface named page_0.
				if original == null or not original.resource_path.begins_with(base+"/textures/"): continue
				# Legacy-skin materials already belong to this actor, and its
				# palette writer keeps references to them. Static resources need
				# their own copy so leaving/reloading cannot poison cached assets.
				if not material.get_shader_parameter("use_legacy_skin"):
					if not copied_mesh:
						mesh.mesh = mesh.mesh.duplicate()
						copied_mesh = true
					material = material.duplicate()
					mesh.mesh.surface_set_material(surface,material)
				material.set_shader_parameter("albedo_texture",pages[page]["texture"])
				material.set_shader_parameter("albedo_texture_linear",pages[page]["texture"])
	var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/effects.json"))
	for p in data["water_anchors"]:
		var emitter = OriginalSpriteEmitter.new()
		get_parent().add_child(emitter)
		emitter.name = "WaterSpray"
		emitter.position = Vector3(p[0],p[1],p[2])
		emitter.life = .6
		emitter.period = .08
		emitter.rise_speed = .8
		emitter.spread = .6
		emitter.size_start = .4
		emitter.size_end = 1.1
		if data.get("river_spray",false):
			emitter.period = .2; emitter.rise_speed = .3; emitter.spread = .3
			emitter.size_start = .2; emitter.size_end = .6
		emitter.configure(data["sheets"]["water"],16)
		emitter.emitting = true
func _process(delta: float) -> void:
	elapsed += delta
	var steps = int(elapsed*60)
	if steps == 0: return
	elapsed -= steps/60.0
	advance_rows(steps)
func advance_rows(steps: int) -> void:
	ticks += steps
	for region in regions:
		var page = pages[int(region["page"])]
		var r = region["rect"]
		var shift = posmod(ticks*int(region["step"]),int(r[3]))
		# TexScroll_Update copies the last rows to the top, within this rect only.
		for row in range(int(r[3])):
			page["image"].blit_rect(page["source"],Rect2i(int(r[0]),int(r[1])+posmod(row-shift,int(r[3])),int(r[2]),1),Vector2i(int(r[0]),int(r[1])+row))
	for page in pages.values(): page["texture"].update(page["image"])
