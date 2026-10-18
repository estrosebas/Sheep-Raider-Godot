extends "res://tools/build_shared_items.gd"
func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_02/data/interactions.json"))
	for definition in data.definitions.values():
		var base: String = definition.directory
		build_costume(base,definition)
		if base.ends_with("/bush_world") or base.ends_with("/bush_disguise"):
			# Preserve the accepted renderer when rebuilding native assets.
			var mesh: ArrayMesh = load(base+"/worn.tres")
			for i in range(mesh.get_surface_count()):
				var material = mesh.surface_get_material(i)
				var texture = material.get_shader_parameter("albedo_texture")
				if texture != null and (texture.resource_path.ends_with("page_11.png") or texture.resource_path.ends_with("page_9.png")):
					material.shader = preload("res://shaders/bush_backface_cutout.gdshader")
			ResourceSaver.save(mesh,base+"/worn.tres")
		var scene = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%base)
	quit()
