extends "res://tools/build_shared_items.gd"
func _init():
	for name in ["wheel","daffy","base"]:
		var base = "res://assets/localization/wheel/"+name
		build_costume(base,JSON.parse_string(FileAccess.get_file_as_string(base+"/definition.json")))
		var file = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
		file.store_string('[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%base)
	var base = "res://assets/localization/wheel/background"
	var geometry = JSON.parse_string(FileAccess.get_file_as_string(base+"/mesh_data.json"))
	var definition = JSON.parse_string(FileAccess.get_file_as_string(base+"/definition.json"))
	ResourceSaver.save(Space.mesh_from_export(build_mesh(base,geometry,definition)),base+"/scenery.tres")
	quit()
