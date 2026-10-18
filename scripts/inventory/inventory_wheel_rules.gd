extends RefCounted
class_name InventoryWheelRules

# progress_inventory.cpp: InvWheel_GetSlotPosColor / ItemFly_Render.
const SLOT_STEP = 0x155
const TURN_RATE = 0x400
const TURN_DURATION = float(SLOT_STEP) / TURN_RATE
const SLIDE_CLOSED = -32.0
const SLIDE_SPEED = 180.0

static func slot_position(angle_units: float, slide: float) -> Vector2:
	var angle = angle_units * TAU / 4096.0
	return Vector2(256 + floori(int(cos(angle)*4096)*150.0/4096),
		-150 - floori(int(sin(angle)*4096)*200.0/4096) + slide)

static func slot_brightness(angle_units: float) -> float:
	var distance = absf(wrapf(angle_units - 0xc00, -2048.0, 2048.0))
	var byte = 0x30
	if distance < SLOT_STEP:
		var fraction = int(distance * 4096.0 / SLOT_STEP)
		byte = 0x80 + ((0x30-0x80)*fraction >> 12)
	return float(byte) / 128.0
