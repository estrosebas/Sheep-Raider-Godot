extends "res://tools/build_shared_items.gd"

func _init() -> void:
	var sequence = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cinematics/tutorial_intro/sequence.json"))
	for actor in sequence["actors"].values():
		var data = JSON.parse_string(FileAccess.get_file_as_string(actor["directory"]+"/worn_data.json"))
		if bool(data.get("static",false)):
			ResourceSaver.save(Space.mesh_from_export(build_mesh(actor["directory"],data["surfaces"],actor)),actor["directory"]+"/worn.tres")
		else:
			var build_definition: Dictionary = actor.duplicate()
			if actor["name"] == "bipbip": build_definition["loop_animations"] = ["run1"]
			build_costume(actor["directory"],build_definition)
		var scene = FileAccess.open(actor["directory"]+"/worn.tscn",FileAccess.WRITE)
		scene.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="OriginalActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % actor["directory"])
		print("Built original cinematic actor: ",actor["name"])
	quit()
