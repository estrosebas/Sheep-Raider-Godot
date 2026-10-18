extends "res://tools/build_shared_items.gd"
func _init() -> void:
	var base = "res://assets/levels/lvl_01"
	var definitions: Dictionary = {}
	definitions[base+"/sam_head"] = JSON.parse_string(FileAccess.get_file_as_string(base+"/sam_head/definition.json"))
	definitions[base+"/sheep_sleep"] = JSON.parse_string(FileAccess.get_file_as_string(base+"/sheep_sleep/definition.json"))
	definitions[base+"/models/2"] = JSON.parse_string(FileAccess.get_file_as_string(base+"/models/2/definition.json"))
	definitions[base+"/models/16"] = JSON.parse_string(FileAccess.get_file_as_string(base+"/data/manifest.json"))
	for model in [5,17,37]:
		definitions[base+"/models/%d" % model] = JSON.parse_string(FileAccess.get_file_as_string(base+"/models/%d/definition.json" % model))
	for identity in [0,2,3,4]:
		var movie = JSON.parse_string(FileAccess.get_file_as_string(base+"/cinematics/sequence_%d.json" % identity))
		for actor in movie["actors"].values(): definitions[actor["directory"]] = actor
	for directory in definitions:
		var data = JSON.parse_string(FileAccess.get_file_as_string(directory+"/worn_data.json"))
		if bool(data.get("static",false)):
			ResourceSaver.save(Space.mesh_from_export(build_mesh(directory,data["surfaces"],definitions[directory])),directory+"/worn.tres")
		else: build_costume(directory,definitions[directory])
		var scene = FileAccess.open(directory+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % directory)
	quit()
