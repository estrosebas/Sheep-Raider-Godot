extends "res://tools/build_shared_items.gd"
func _init():
	var base = "res://assets/levels/scene"
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/manifest.json"))
	for number in [11,12]:
		var directory = base+"/models/%d"%number
		build_costume(directory,manifest)
		var scene = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%directory)
	quit()
