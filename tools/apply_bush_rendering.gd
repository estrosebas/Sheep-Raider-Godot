extends SceneTree

func _init():
	for slug in ["bush_world","bush_disguise"]:
		var path = "res://assets/items/"+slug+"/worn.tres"
		# Keep the earliest original backup when this tool is rerun.
		if not FileAccess.file_exists(path+".bak"):
			var backup = FileAccess.open(path+".bak",FileAccess.WRITE)
			backup.store_buffer(FileAccess.get_file_as_bytes(path))
			backup.close()
		var mesh: ArrayMesh = load(path)
		for i in range(mesh.get_surface_count()):
			var material = mesh.surface_get_material(i)
			var texture = material.get_shader_parameter("albedo_texture")
			if texture != null and (texture.resource_path.ends_with("page_11.png") or texture.resource_path.ends_with("page_9.png")):
				var accepted = material.duplicate()
				accepted.shader = preload("res://shaders/bush_backface_cutout.gdshader")
				mesh.surface_set_material(i,accepted)
		var result = ResourceSaver.save(mesh,path)
		if result != OK: quit(result); return
		print("Bush option 2 applied: ",slug,"; original preserved in worn.tres.bak")
	quit()
