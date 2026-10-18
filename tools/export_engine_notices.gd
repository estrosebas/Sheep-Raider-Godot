extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Provide an output path after --")
		quit(1)
		return
	var output = FileAccess.open(args[0],FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string("GODOT ENGINE\nhttps://godotengine.org/license/\n\n"+Engine.get_license_text())
	output.store_string("\n\nTHIRD-PARTY COMPONENTS / COPYRIGHT\n"+JSON.stringify(Engine.get_copyright_info(),"  "))
	output.store_string("\n\nTHIRD-PARTY LICENSE TEXTS\n"+JSON.stringify(Engine.get_license_info(),"  "))
	output.close()
	quit()
