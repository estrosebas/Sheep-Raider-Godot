extends "res://tools/build_shared_items.gd"
func _init():
	var slug = OS.get_cmdline_user_args()[0]
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/"+slug+"/data/mines.json"))
	var definition = data.explosion; var directory = definition.directory
	build_costume(directory,definition)
	var file = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="MineExplosion" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%directory)
	quit()
