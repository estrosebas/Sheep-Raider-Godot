extends "res://tools/build_shared_items.gd"
func _init():
	var base = "res://assets/levels/"+OS.get_cmdline_user_args()[0]
	var definitions = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/cinematic_models.json"))
	for definition in definitions:
		var directory: String = definition.directory
		var rig = JSON.parse_string(FileAccess.get_file_as_string(directory+"/worn_data.json"))
		if rig.get("static",false): ResourceSaver.save(Space.mesh_from_export(build_mesh(directory,rig.surfaces,definition)),directory+"/worn.tres")
		else: build_costume(directory,definition)
		var file = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
		file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%directory)
	quit()
