extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var level = load("res://scenes/levels/Level00.tscn").instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.capture_mouse(false)
	var inv = player.inventory
	inv.add_item({"id": "preview-1", "class_id": 2, "label": "Dinamita"})
	inv.add_item({"id": "preview-2", "class_id": 3, "label": "Lechuga"})
	inv.add_item({"id": "preview-3", "class_id": 10, "label": "Cohete"})
	inv.add_item({"id": "preview-4", "class_id": 10, "label": "Cohete"})
	inv.open_wheel()
	inv.state.select_class(10)
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/inventory_wheel.png")
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()
