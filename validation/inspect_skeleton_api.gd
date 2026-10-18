extends SceneTree
func _init():
	for method in ClassDB.class_get_method_list("Skeleton3D"):
		if "scale" in method.name or "override" in method.name:
			print(method.name)
	quit()
