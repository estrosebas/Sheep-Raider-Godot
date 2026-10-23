extends "res://tools/build_shared_items.gd"
func _init():
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/scene/arrival/models.json"))
	for definition in definitions:
		build_costume(definition.directory,definition)
		var scene = FileAccess.open(definition.directory+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="ArrivalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%definition.directory)
	quit()
