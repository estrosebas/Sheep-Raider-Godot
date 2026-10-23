extends "res://tools/build_shared_items.gd"
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var configuration = JSON.parse_string(FileAccess.get_file_as_string(path))
		var built = {}
		for butterfly in configuration.butterflies:
			var base: String = butterfly.directory
			if built.has(base): continue
			built[base] = true
			build_costume(base,JSON.parse_string(FileAccess.get_file_as_string(base+"/source.json")))
			var scene = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
			scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="ButterflyVisual" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n'%base)
	quit()
