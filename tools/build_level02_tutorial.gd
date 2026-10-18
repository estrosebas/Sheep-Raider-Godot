extends "res://tools/build_shared_items.gd"
func _init():
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/lvl_02/data/tutorial_models.json"))
	for definition in definitions:
		var base: String = definition.directory
		var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/worn_data.json"))
		if data.get("static",false): ResourceSaver.save(Space.mesh_from_export(build_mesh(base,data.surfaces,definition)),base+"/worn.tres")
		else: build_costume(base,definition)
		var scene = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%base)
	quit()
