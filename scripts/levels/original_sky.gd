extends MeshInstance3D
@export_file("*.tres") var mesh_path = "res://assets/levels/lvl_00/sky.tres"

func _ready() -> void:
	mesh = load(mesh_path)
	material_override = ShaderMaterial.new()
	material_override.shader = load("res://shaders/original_sky.gdshader")
	material_override.render_priority = -128
	# CPU culling must also ignore the world's camera translation.
	custom_aabb = AABB(Vector3.ONE*-100000,Vector3.ONE*200000)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
