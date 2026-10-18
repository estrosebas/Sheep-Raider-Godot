extends "res://tools/build_shared_items.gd"
func _init():
	for model in [1,10]:
		var directory = "res://assets/levels/lvl_01/models/%d" % model
		build_costume(directory,JSON.parse_string(FileAccess.get_file_as_string(directory+"/definition.json")))
		var scene = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % directory)
	quit()
