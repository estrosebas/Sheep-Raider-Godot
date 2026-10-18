extends "res://build_native_resources.gd"

func _init() -> void:
	shader_opaque = load("res://shaders/retro_opaque.gdshader")
	shader_blend = load("res://shaders/retro_blend.gdshader")
	shader_add = load("res://shaders/retro_add.gdshader")
	build_scenery()
	build_scenery("res://assets/levels/lvl_00/data/sky_data.json","res://assets/levels/lvl_00/sky.tres")
	quit()
