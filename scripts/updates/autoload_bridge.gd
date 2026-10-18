extends CanvasLayer
# The engine loads autoload scripts before invoking their _init(). Keep these
# bridges free of gameplay references/preloads, so ContentUpdates can mount a
# verified pack before compiling any actual game services or global classes.
func _enter_tree():
	var services = {
		"LanguageMenu":"res://scripts/localization/language_menu.gd",
		"LevelLoading":"res://scripts/ui/level_loading.gd",
		"MobileControls":"res://scripts/input/mobile_controls.gd",
	}
	var path = services.get(str(name),"")
	if not path.is_empty(): set_script(load(path))
