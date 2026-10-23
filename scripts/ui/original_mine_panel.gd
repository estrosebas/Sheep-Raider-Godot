extends CanvasLayer
# Original DAV panel, with directional glyphs replacing console face buttons.
var mine
var surface: Control
var panel_texture: Texture2D
var beat_texture: Texture2D
var font: Font
func _ready():
	layer = 35
	panel_texture = load(mine.mine_assets.sprites.panel)
	beat_texture = load(mine.mine_assets.sprites.beat)
	font = load(OriginalGameFont.PATH)
	surface = Control.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(surface)
	surface.draw.connect(paint)
func _process(_delta):
	visible = is_instance_valid(mine) and mine.session
	if visible: surface.queue_redraw()
func paint():
	var size = surface.size
	var scale_factor = minf(size.x/960.0,size.y/540.0)
	var center = Vector2(size.x*.5,size.y*.32)
	var box = Rect2(center-Vector2(170,100)*scale_factor,Vector2(340,200)*scale_factor)
	for flip in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		surface.draw_set_transform(center,0,flip)
		surface.draw_texture_rect(panel_texture,Rect2(-box.size*.5,box.size*.5),false)
	surface.draw_set_transform(Vector2.ZERO)
	var title = GameLocalization.ui("Observa el ritmo" if mine.state==mine.State.PLAYBACK else "Repite el ritmo")
	var text_size = 18*scale_factor
	surface.draw_string(font,center+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x*.5,-65*scale_factor),title,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,Color(2,1.7,.44))
	var offsets = [Vector2(0,-28),Vector2(65,10),Vector2(-65,10),Vector2(0,48)]
	var vectors = [Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN]
	for i in range(4):
		var point = center+offsets[i]*scale_factor
		var direction = vectors[i]
		var tangent = direction.orthogonal()
		var color = Color(1,.9,.15) if mine.shown_direction==i else Color(.15,.65,.8)
		var poly = PackedVector2Array()
		for vertex in [direction*19,direction*2+tangent*15,direction*2+tangent*6,-direction*17+tangent*6,-direction*17-tangent*6,direction*2-tangent*6,direction*2-tangent*15]: poly.append(point+vertex*scale_factor)
		surface.draw_colored_polygon(poly,color)
		if mine.shown_direction==i:
			var outline = poly.duplicate()
			outline.append(poly[0])
			surface.draw_polyline(outline,Color.WHITE,3.0*scale_factor,true)
	for i in range(4):
		var point = center+Vector2(-54+i*36,77)*scale_factor
		surface.draw_texture_rect(beat_texture,Rect2(point,Vector2(20,9)*scale_factor),false,Color(2,2,0) if i<mine.lights_shown else Color(.5,.3,.3))
