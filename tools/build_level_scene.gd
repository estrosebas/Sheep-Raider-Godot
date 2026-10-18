extends "res://tools/build_shared_items.gd"
func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var base = "res://assets/levels/"+(args[0] if not args.is_empty() else "lvl_01")
	var definition = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/manifest.json"))
	for bank in ["scenery","sky"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/"+bank+".json"))
		var mesh: ArrayMesh
		if bank=="scenery" and FileAccess.file_exists(base+"/data/foliage.json"):
			mesh = preload("res://tools/native_foliage_builder.gd").build(base,data,definition,self)
		else: mesh = Space.mesh_from_export(build_mesh(base,data,definition))
		ResourceSaver.save(mesh,base+"/"+bank+".tres")
	for model in definition["models"].values():
		var directory: String = model["directory"]
		var data = JSON.parse_string(FileAccess.get_file_as_string(directory+"/worn_data.json"))
		if model["animated"]: build_costume(directory,definition)
		else: ResourceSaver.save(Space.mesh_from_export(build_mesh(base,data["surfaces"],definition)),directory+"/worn.tres")
		var file = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
		file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % directory)
	var triangles = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/collision.json"))
	var faces = PackedVector3Array()
	for triangle in triangles:
		# Godot faces use clockwise front winding; source collision normals
		# are preserved by reversing the raw native WAR corner order.
		for index in [0,2,1]:
			var vertex = triangle[index]
			faces.append(Vector3(vertex[0],vertex[1],vertex[2]))
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	quit(ResourceSaver.save(shape,base+"/collision.tres"))
