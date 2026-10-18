extends "res://tools/build_shared_items.gd"

func _init():
	for slug in ["bush_custom","bush_custom_disguise"]:
		var base = "res://assets/items/"+slug
		var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/worn_data.json"))
		var mesh = build_mesh(base,data.surfaces,{"materials":{"11":"blend","9":"blend"}})
		var shell = build_mesh(base,data.shell_surfaces,{"materials":{"11":"opaque","9":"opaque"}})
		for i in range(shell.get_surface_count()):
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shell.surface_get_arrays(i))
			var index = mesh.get_surface_count()-1
			mesh.surface_set_material(index,shell.surface_get_material(i))
			mesh.surface_set_name(index,"closed_foliage_"+str(i))
		ResourceSaver.save(mesh,base+"/worn.tres")
	quit()
