extends CanvasLayer
var detector
var surface: Control
var gauge_texture: Texture2D
var icon: Texture2D
func _ready():
	layer = 30; gauge_texture = load(detector.rules.sprites.gauge); icon = load(detector.rules.sprites.icon)
	surface = Control.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(surface); surface.draw.connect(paint)
func _process(_delta):
	visible = detector.phase=="scanning" and is_instance_valid(detector.holder)
	if visible: surface.queue_redraw()
func paint():
	var factor = minf(surface.size.x/320,surface.size.y/240)
	var offset = (surface.size-Vector2(320,240)*factor)*.5
	surface.draw_set_transform(offset,0,Vector2.ONE*factor)
	surface.draw_texture_rect(gauge_texture,Rect2(39-gauge_texture.get_width()*.5,49,gauge_texture.get_width(),140),false)
	if detector.reading<=2:
		var amount = 1-clampf(detector.reading/2,0,1)
		surface.draw_rect(Rect2(36,184-129*amount,8,129*amount),Color(amount,1-amount,0))
	surface.draw_texture(icon,Vector2(40,210)-icon.get_size()*.5)
