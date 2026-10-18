extends SceneTree

const Rules = preload("res://scripts/inventory/inventory_wheel_rules.gd")
const State = preload("res://scripts/inventory/inventory_state.gd")
var failures = 0

func _init() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr(message)

func run_tests() -> void:
	check(Rules.slot_position(0xc00,0) == Vector2(256,50), "Original front position in 512x240 space")
	check(Rules.slot_position(0xc00,-32) == Vector2(256,18), "Original slide offset")
	check(Rules.slot_position(0,0) == Vector2(406,-150), "Original horizontal ellipse radius")
	check(Rules.slot_position(0x400,0) == Vector2(256,-350), "Original vertical ellipse radius")
	check(Rules.slot_brightness(0xc00) == 1.0, "Original neutral 0x808080 modulation")
	check(Rules.slot_brightness(0xc00+0x155) == 0.375, "Original dim 0x303030 modulation")
	check(Rules.slot_brightness(0xc00-170) < 1.0 and Rules.slot_brightness(0xc00-170) > 0.375, "Intermediate tint fades during rotation")
	var ui = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/inventory/original_ui.json"))
	check(ui["cloud"]["resource"] == 25 and ui["cloud"]["frames"].size() == 3, "Original IGLCRAI1 animation recovered")
	check(ui["cloud"]["size"] == [47.0,31.0] and ui["icons"].size() == 27, "Original sprite dimensions and inventory icons")
	var paths = []
	for frame in ui["cloud"]["frames"]:
		paths.append(frame["path"])
	for icon in ui["icons"].values():
		paths.append(icon["path"])
	for path in paths:
		var texture: Texture2D = load(path)
		var raw = Image.load_from_file(ProjectSettings.globalize_path(path))
		check(texture.get_image().get_data() == raw.get_data(), "Original sprite pixels unchanged by Godot: " + path)
		check(not texture.get_image().has_mipmaps(), "No UI mipmaps: " + path)
	var wheel = load("res://scenes/ui/InventoryWheel.tscn").instantiate()
	root.add_child(wheel)
	wheel.set_process(false)
	wheel.bind_state(State.new())
	wheel.set_open(true)
	wheel._process(0.2)
	check(wheel.slide_y == 0 and wheel.clouds.size() == 3, "Empty wheel settles on screen with original frames")
	wheel.animate_turn(1, Rules.TURN_DURATION)
	wheel._process(Rules.TURN_DURATION / 2.0)
	check(wheel.angle_offset > 0, "Original angular speed keeps turn active halfway")
	wheel._process(Rules.TURN_DURATION / 2.0 + 0.001)
	check(is_zero_approx(wheel.angle_offset), "Original turn finishes in 341/1024 seconds")
	wheel.set_open(false)
	wheel._process(0.2)
	check(wheel.slide_y == -32, "Closing wheel slides out")
	wheel.queue_free()
	await process_frame
	print("Original inventory UI: ", failures, " failures / ", paths.size(), " sprites")
	quit(1 if failures else 0)
