extends RefCounted

# Wolf::SneakStepSound, 0x48d627. No Input, nodes or audio dependencies.
static func sneak_step(count: int) -> Dictionary:
	if count < 0 or count >= 8:
		return {}
	return {"pitch": float(0x800 + count * 0x100) / 4096.0,
		"volume": float(((8 - count) * 255) / 8) / 255.0}

static func step_interval(animation_length: float) -> float:
	return maxf(animation_length * 0.5, 0.001)
