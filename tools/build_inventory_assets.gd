extends "res://build_native_resources.gd"

func _init() -> void:
	call_deferred("build_inventory_assets")

func build_inventory_assets() -> void:
	shader_opaque = load("res://shaders/retro_opaque.gdshader")
	shader_blend = load("res://shaders/retro_blend.gdshader")
	shader_add = load("res://shaders/retro_add.gdshader")
	build_level_objects()
	build_character("res://assets/levels/lvl_00/data/rocket_data.json",
		"res://assets/levels/lvl_00/rocket.tres", "Rocket")
	quit()
