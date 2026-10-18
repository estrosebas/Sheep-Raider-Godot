extends RefCounted

# Scene-independent rules translated from sdw-decomp. Seconds/metres replace
# 4.12 fixed-point ticks and game units; no Input, scene, animation or audio.
const TAP_MIN: float = 0x199 / 4096.0
const TAP_MAX: float = 0xc00 / 4096.0
const RECOVER_IDLE_TIME: float = 0x5000 / 4096.0
const RUN_ACCELERATION: float = 12.0
const RUN_DECELERATION: float = 12.0
const TURN_SPEED: float = 3413.0 * TAU / 4096.0
const IMPACT_HEIGHT: float = 0.7
const IMPACT_COSINE: float = 0.5

static func run_tap_check(timer: float, active: bool, pressed: bool) -> Dictionary:
	# Wolf::RunTapCheck 0x48def7: expiry takes precedence over a new press.
	if timer > TAP_MAX:
		return {"timer": 0.0, "active": false}
	if pressed:
		return {"timer": 0.0, "active": timer >= TAP_MIN}
	return {"timer": timer, "active": active}

static func run_speed_step(speed: float, active: bool, maximum: float, delta: float) -> float:
	return move_toward(speed, maximum if active else 0.0,
		(RUN_ACCELERATION if active else RUN_DECELERATION) * delta)

static func is_run_crash(motion: Vector3, normal: Vector3, contact_height: float,
		maximum_speed: float, exempt: bool = false) -> bool:
	# Wolf::RunMove 0x48bc2d: half speed, <=60 degrees, contact >=70u above feet.
	var horizontal = Vector3(motion.x, 0, motion.z)
	var wall = Vector3(normal.x, 0, normal.z)
	if exempt or horizontal.length() < maximum_speed * 0.5 or wall.length_squared() < 0.0001:
		return false
	return contact_height >= IMPACT_HEIGHT and horizontal.normalized().dot(-wall.normalized()) >= IMPACT_COSINE

static func reaction_pose_transforms(parents: Array[int], rests: Array[Vector3],
		rotations: Array[Quaternion], positions: Array[Vector3], scales: Array[Vector3]) -> Array[Transform3D]:
	# Instance_DrawAnimParts 0x550e98: build the hierarchy WITHOUT scale.
	# Parent scale affects only the child's rest offset; each mesh part receives
	# its own scale afterwards. Godot's usual inherited scale is not equivalent.
	var unscaled: Array[Transform3D] = []
	var output: Array[Transform3D] = []
	for joint in range(parents.size()):
		var parent = parents[joint]
		var matrix: Transform3D
		if parent < 0:
			matrix = Transform3D(Basis.IDENTITY, positions[joint])
		else:
			var offset = rests[joint] * scales[parent] + positions[joint] - rests[joint]
			matrix = unscaled[parent] * Transform3D(Basis(rotations[joint]), offset)
		unscaled.append(matrix)
		if parent >= 0:
			matrix.basis = matrix.basis * Basis.from_scale(scales[joint])
		output.append(matrix)
	return output
