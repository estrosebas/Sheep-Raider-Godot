extends "res://tools/build_shared_items.gd"
func _init():
	var base = "res://assets/items/dynamite"
	build_costume(base,JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))["2"])
	var file = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
	file.store_string('[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="DynamiteActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%base)
	quit()
