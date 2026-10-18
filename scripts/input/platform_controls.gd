extends RefCounted

static func configure():
	if OS.has_feature("web"): configure_web()

static func configure_web():
	# Ctrl+W/A/S/D belong to browser shortcuts. Use an unmodified key on web.
	InputMap.action_erase_events("sneak")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_C
	InputMap.action_add_event("sneak",key)

static func key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return ""
