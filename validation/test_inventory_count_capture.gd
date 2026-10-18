extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	var wheel = load("res://scenes/ui/InventoryWheel.tscn").instantiate()
	root.add_child(wheel)
	var state = load("res://scripts/inventory/inventory_state.gd").new()
	for i in range(7): state.add({"id":"lettuce%d"%i,"class_id":3})
	state.add({"id":"dynamite","class_id":2})
	wheel.bind_state(state)
	state.select_class(3)
	wheel.set_open(true)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/inventory_selected_count.png")
	var found = false
	for counter in wheel.canvas.counters:
		if counter.kind == 3 and counter.count == 7: found = true
	print("Selected inventory count failures: ",0 if found else 1)
	wheel.queue_free()
	await process_frame
	quit(0 if found else 1)
