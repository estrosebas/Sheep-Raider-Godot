extends SceneTree
func _init(): call_deferred("capture")
func capture():
	var viewport = SubViewport.new()
	viewport.size = Vector2i(160,48)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var texture: Texture2D = load("res://assets/levels/lvl_01/sam_head/border.png")
	var original = texture.get_image()
	var reference = Vector2i.ZERO
	for y in range(original.get_height()):
		for x in range(original.get_width()):
			if original.get_pixel(x,y).is_equal_approx(Color.WHITE): reference = Vector2i(x,y)
	for i in range(3):
		var rect = TextureRect.new()
		rect.texture = texture
		rect.position = Vector2(i*52,8)
		rect.modulate = OriginalSamIndicator.source_color(i)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(rect)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = viewport.get_texture().get_image()
	result.save_png("res://validation/sam_original_palette.png")
	var failures = 0
	for i in range(3):
		var pixel = result.get_pixelv(reference+Vector2i(i*52,8))
		var expected = OriginalSamIndicator.source_color(i)
		print("Sam palette ",i,": rendered #",pixel.to_html()," original #",expected.to_html())
		if absf(pixel.r-expected.r) > 1.01/255 or absf(pixel.g-expected.g) > 1.01/255 or absf(pixel.b-expected.b) > 1.01/255: failures += 1
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
