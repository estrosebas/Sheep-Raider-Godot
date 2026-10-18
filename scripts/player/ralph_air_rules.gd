extends RefCounted
class_name RalphAirRules

# Wolf::InitMoveConfig and RUN_AIR; metres/seconds replace original fixed point.
const RUN_AIR_LIMIT = float(0xc00)/4096.0
const PIT_DROP = 30.0
const LANDING_DROP = 2.0
const RESTART_DELAY = float(0x2000)/4096.0

static func can_air_run(active: bool, speed: float, drop: float, walk_speed: float) -> bool:
	return active and speed >= walk_speed and drop > PIT_DROP

static func should_pit_fall(speed: float, drop: float, walk_speed: float) -> bool:
	return speed < walk_speed and drop >= PIT_DROP
