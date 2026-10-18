extends RefCounted
class_name ItemRules

const MAGNET_RADIUS = 4.0
const MAGNET_MAX_TARGETS = 4
const FAN_RADIUS = 4.0
const FAN_HALF_ANGLE = float(0x199) * TAU / 4096.0
const PERFUME_BLOW_MAX = float(0x471c) / 4096.0
const LETTUCE_RADIUS = 6.0
const LETTUCE_EAT_TIME = 3.0
const LETTUCE_RESPAWN_TIME = 10.0
const SHEEP_CALL_RADIUS = 8.0
const GHOST_BOO_RADIUS = 5.0
const ROCKET_LAUNCH_TIME = float(0xd1e) / 4096.0

static func in_fan_cone(origin: Vector3, forward: Vector3, point: Vector3) -> bool:
	var difference = point - origin
	if difference.y < -1.0 or difference.y > 3.0:
		return false
	difference.y = 0.0
	if difference.length_squared() > FAN_RADIUS * FAN_RADIUS:
		return false
	return difference.length_squared() < 0.0001 or forward.normalized().dot(difference.normalized()) >= cos(FAN_HALF_ANGLE)

static func magnet_strength(distance: float, on_rod: bool = false) -> float:
	if distance > MAGNET_RADIUS:
		return 0.0
	var step = (3.4 if on_rod else 0.0) if distance < 0.6 else 4.0 - distance
	return step * step * 6.0 / (3.4 * 3.4)

static func perfume_blow_step(time: float, blown: bool, delta: float) -> float:
	return clampf(time + delta * (1.0 if blown else -1.0), 0.0, PERFUME_BLOW_MAX)

static func perfume_distance(blow_time: float) -> float:
	return minf(blow_time, PERFUME_BLOW_MAX) * 4.5

static func rocket_fuel_step(fuel: float, boosted: bool, delta: float) -> float:
	return maxf(0.0, fuel - delta * (2.0 if boosted else 1.0))

static func rocket_launch_velocity(time: float) -> float:
	return maxf(0.0, (ROCKET_LAUNCH_TIME - time) * 2000.0 / float(0xac0) * 4096.0 * 0.01)
