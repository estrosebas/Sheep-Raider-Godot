extends Control
class_name OriginalSubtitleCanvas

var text_label: Label
var clock = 0.0
var font: Texture2D
const GLYPH_SIZE = Vector2(15,15)
const LINE_HEIGHT = 17.0

func _ready() -> void:
	font = load("res://assets/ui/pause/font.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func render_scale() -> float:
	var viewport = get_viewport_rect().size
	return minf(viewport.x/512,viewport.y/240)

func lines() -> Array[String]:
	return OriginalTextBox.wrap_text(text_label.text,maxi(1,floori((size.x/render_scale()-64)/GLYPH_SIZE.x)))

func _draw() -> void:
	if text_label == null or font == null: return
	var scale = render_scale()
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale)
	var rows = lines()
	var y = (size.y/scale-rows.size()*LINE_HEIGHT)/2
	var color = OriginalGameFont.PAUSE_COLOR
	var tint = Color(color.r*2,color.g*2,color.b*2,1)
	for row in rows:
		var x = (size.x/scale-row.length()*GLYPH_SIZE.x)/2
		for i in range(row.length()):
			var glyph = OriginalGameFont.animated_glyph(row.unicode_at(i),clock)-32
			draw_texture_rect_region(font,Rect2(Vector2(x+i*GLYPH_SIZE.x,y),GLYPH_SIZE),Rect2((glyph%16)*16,int(glyph/16.0)*16,15,15),tint)
		y += LINE_HEIGHT
	draw_set_transform(Vector2.ZERO)
