extends CanvasLayer

const Rules = preload("res://scripts/inventory/inventory_wheel_rules.gd")
var state: RefCounted
var opened = false
var angle_offset = 0.0
var slide_y = Rules.SLIDE_CLOSED
var message = ""
var message_time = 0.0
var canvas: WheelCanvas
var ui: Dictionary
var clouds: Array[Texture2D] = []
var icons: Dictionary = {}
@export_range(0.05,1.0,0.01) var cloud_frame_seconds = 0.2
var cloud_elapsed = 0.0
var help_visible = false

class WheelCanvas extends Control:
	var wheel: CanvasLayer
	var counters: Array[Dictionary] = []
	func _draw() -> void:
		if wheel == null or wheel.state == null:
			return
		var font = ThemeDB.fallback_font
		counters.clear()
		if wheel.slide_y > Rules.SLIDE_CLOSED:
			var selected: int = wheel.state.selected_class
			var previous: int = wheel.state.prev_class(selected)
			var next: int = wheel.state.next_class(selected)
			var single = previous == next and previous == selected
			if previous == next and not single:
				if wheel.state.wheel_side != 0:
					previous = wheel.state.NONE
				else:
					next = wheel.state.NONE
			var angle = 0xc00 + wheel.angle_offset * 4096.0 / TAU
			var frame = int(wheel.cloud_elapsed/wheel.cloud_frame_seconds)
			_draw_slot(selected, angle, frame)
			if not single:
				_draw_slot(previous, angle - Rules.SLOT_STEP, 0)
				_draw_slot(next, angle + Rules.SLOT_STEP, 0)
			if not is_zero_approx(wheel.angle_offset):
				var extra: int = wheel.state.prev_class(previous) if angle > 0xc00 else wheel.state.next_class(next)
				if extra == selected:
					extra = wheel.state.NONE
				_draw_slot(extra, angle + (-2 if angle > 0xc00 else 2)*Rules.SLOT_STEP, 0)
			# All counts sort above every cloud/icon, including the selected slot.
			_draw_counts()
			if wheel.opened and wheel.help_visible:
				_center_text(font, "Tab + A/D: seleccionar · Suelta Tab: equipar · Esc: cancelar", Vector2(size.x/2, size.y*0.43), 21)
		elif not wheel.opened and wheel.help_visible:
			var item: Dictionary = wheel.state.get_selected_object()
			if not item.is_empty():
				_center_text(font, "Equipado: %s · Tab: inventario · R: usar" % item.get("label", "Objeto"), Vector2(size.x/2, size.y-40), 21)
		if wheel.message_time > 0 and wheel.help_visible:
			_center_text(font, wheel.message, Vector2(size.x/2, size.y-85), 22)

	func _draw_slot(kind: int, angle: float, frame: int) -> void:
		var scale = size / Vector2(512, 240)
		var logical = Rules.slot_position(angle, wheel.slide_y)
		var brightness = Rules.slot_brightness(angle)
		var tint = Color(brightness, brightness, brightness)
		var cloud_size = Vector2(wheel.ui["cloud"]["size"][0], wheel.ui["cloud"]["size"][1])
		var top_left = logical - Vector2(int(cloud_size.x) >> 1, int(cloud_size.y) >> 1)
		draw_texture_rect(wheel.clouds[frame % wheel.clouds.size()], Rect2(top_left*scale, cloud_size*scale), false, tint)
		var key = str(kind)
		if wheel.icons.has(key):
			var icon: Texture2D = wheel.icons[key]
			var dimensions = icon.get_size()
			var half = Vector2(int(dimensions.x) >> 1, int(dimensions.y) >> 1)
			draw_texture_rect(icon, Rect2((logical-half)*scale, half*2*scale), false, tint)
		var count: int = wheel.state.count_class(kind)
		if count > 1:
			# Text_SetCursor is a TOP coordinate, not Godot's font baseline.
			counters.append({"kind":kind,"position":(logical+Vector2(2,2))*scale,"count":count})

	func _draw_counts() -> void:
		var font = ThemeDB.fallback_font
		var font_size = maxi(1,int(8*size.y/240))
		for counter in counters:
			var position: Vector2 = counter.position+Vector2(0,font.get_ascent(font_size))
			var label = "x%d" % counter.count
			draw_string_outline(font,position,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color.BLACK)
			draw_string(font,position,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(.625,.625,1))

	func _center_text(font: Font, text: String, center: Vector2, font_size: int) -> void:
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center-Vector2(width/2,0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1,0.93,0.74))

func _ready() -> void:
	layer = 20
	ui = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/inventory/original_ui.json"))
	for frame in ui["cloud"]["frames"]:
		clouds.append(_original_sprite(frame["path"]))
	for kind in ui["icons"]:
		icons[kind] = _original_sprite(ui["icons"][kind]["path"])
	canvas = WheelCanvas.new()
	canvas.wheel = self
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _original_sprite(path: String) -> AtlasTexture:
	var texture: Texture2D = load(path)
	var sprite = AtlasTexture.new()
	sprite.atlas = texture
	# Tex_CornerUV samples 0.5 .. size-1.5: exclude the final padding texel.
	sprite.region = Rect2(Vector2.ZERO, texture.get_size()-Vector2.ONE)
	sprite.filter_clip = true
	return sprite

func bind_state(value: RefCounted) -> void:
	state = value
	state.changed.connect(_redraw)
	state.selection_changed.connect(func(_kind): _redraw())
	_redraw()

func _redraw() -> void:
	if canvas:
		canvas.queue_redraw()

func set_open(value: bool) -> void:
	opened = value
	if value:
		angle_offset = 0.0
	_redraw()

func animate_turn(direction: int, _duration: float) -> void:
	# Inventory_SelectNext sets yaw to 0xd55; Prev sets it to 0xaab.
	angle_offset = direction * float(Rules.SLOT_STEP) * TAU / 4096.0
	_redraw()

func show_message(text: String) -> void:
	message = text
	message_time = 3.0
	_redraw()

func set_help_visible(shown: bool) -> void:
	help_visible = shown
	_redraw()

func _process(delta: float) -> void:
	cloud_elapsed += delta
	var was_visible = slide_y > Rules.SLIDE_CLOSED or message_time > 0
	angle_offset = move_toward(angle_offset, 0.0, float(Rules.TURN_RATE)*TAU/4096*delta)
	slide_y = move_toward(slide_y, 0.0 if opened else Rules.SLIDE_CLOSED, Rules.SLIDE_SPEED*delta)
	message_time = maxf(0.0, message_time-delta)
	if message_time == 0.0:
		message = ""
	if opened or was_visible:
		_redraw()
