extends RefCounted
class_name OriginalBurntTint

# ScnObject::SetTint(0, 0x1000, 1), also Wolf's WOLF_FA_BURNT.
static func apply(skin: RefCounted, enabled: bool) -> void:
	if skin == null: return
	for material in skin.materials:
		material.set_shader_parameter("original_tint_color",Vector3.ZERO)
		material.set_shader_parameter("original_tint_amount",1.0 if enabled else 0.0)
