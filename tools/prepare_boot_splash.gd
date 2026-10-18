extends SceneTree
func _init():
	# The supplied remaster was a JPEG named .png; the boot splash needs PNG.
	var art = Image.load_from_file("res://assets/ui/loading/modern/LEV00.jpg")
	if art == null or art.save_png("res://assets/ui/boot/splash.png") != OK:
		quit(1)
		return
	quit()
