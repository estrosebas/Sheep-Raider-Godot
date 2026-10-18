extends "res://tools/build_shared_items.gd"
func _init() -> void:
	var definition = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))["2"]
	ResourceSaver.save(Space.mesh_from_export(build_mesh("res://assets/items/dynamite",JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/dynamite/mesh_data.json")),definition)),definition["mesh"])
	build_costume("res://assets/items/dynamite",definition)
	var file = FileAccess.open("res://assets/items/dynamite/worn.tscn",FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="DynamiteActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "res://assets/items/dynamite"\n')
	var base = "res://assets/items/dynamite/explosion"
	build_costume(base,JSON.parse_string(FileAccess.get_file_as_string(base+"/definition.json")))
	file = FileAccess.open(base+"/worn.tscn",FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/cinematics/original_actor.gd" id="1"]\n[node name="ExplosionActor" type="Node3D"]\nscript = ExtResource("1")\nasset_directory = "%s"\n' % base)
	quit()
