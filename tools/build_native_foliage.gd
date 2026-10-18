extends "res://tools/build_shared_items.gd"
# Standalone rebuild; the full level builder uses the same RefCounted helper.
func _init():
	var base = "res://assets/levels/"+OS.get_cmdline_user_args()[0]
	var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/scenery.json"))
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/manifest.json"))
	var mesh = preload("res://tools/native_foliage_builder.gd").build(base,data,manifest,self)
	quit(ResourceSaver.save(mesh,base+"/scenery.tres"))
