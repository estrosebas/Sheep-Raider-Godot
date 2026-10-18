extends Control
class_name OriginalTextBox

# Ui_DrawPanelFill writes ARGB4444 alpha 0x8, using inverted alpha:
# 1 - 8/15 = 7/15 opacity. Its 0x080808 fill quantizes to black in RGB444.
const PANEL_COLOR = Color(0,0,0,7.0/15.0)

var text_label: Label
var font: Texture2D
var frame: Texture2D
var clock = 0.0
var animate_all = true
var animated_paragraphs: PackedInt32Array = []

func set_choices(question: String,choices: Array,selected: int,footer: String):
	animate_all = false
	animated_paragraphs.clear()
	var text = question+"\n\n"
	for i in range(choices.size()):
		var first = text.count("\n")
		var choice = str(choices[i])
		if i == selected:
			for paragraph in range(first,first+choice.count("\n")+1): animated_paragraphs.append(paragraph)
		text += choice+"\n"
	# The atlas's '>' and middle-dot cells contain other original glyphs.
	# Selection is represented by the native animated letters, without a marker.
	text_label.text = text+"\n"+footer.replace(" · ","   ")
	queue_redraw()

func render_lines() -> Array:
	var result: Array = []
	var paragraphs = text_label.text.split("\n")
	for i in range(paragraphs.size()):
		for line in wrap_text(paragraphs[i],27):
			result.append({"text":line,"animated":animate_all or animated_paragraphs.has(i)})
	return result

func _ready() -> void:
	font = load("res://assets/ui/pause/font.png")
	frame = load("res://assets/ui/pause/frame.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func _draw() -> void:
	if text_label == null: return
	# SignPost::Update uses {50,50,412,140}; Ui_DrawSubtitleBox adds its
	# panel and the DAV_IDI_IGLCADP_ four frame strips, inset 8.
	var scale = minf(size.x/512,size.y/240)
	var offset = (size-Vector2(512,240)*scale)/2
	draw_set_transform(offset,0,Vector2.ONE*scale)
	draw_rect(Rect2(46,46,416,144),PANEL_COLOR)
	draw_texture_rect(frame,Rect2(38,38,432,8),false)
	draw_set_transform(offset+Vector2(38,198)*scale,0,Vector2(scale,-scale))
	draw_texture_rect(frame,Rect2(0,0,432,8),false)
	draw_set_transform(offset+Vector2(38,198)*scale,-PI/2,Vector2.ONE*scale)
	draw_texture_rect(frame,Rect2(0,0,160,8),false)
	draw_set_transform(offset+Vector2(470,38)*scale,PI/2,Vector2.ONE*scale)
	draw_texture_rect(frame,Rect2(0,0,160,8),false)
	draw_set_transform(offset,0,Vector2.ONE*scale)
	var lines = render_lines()
	var y = 50+(140-lines.size()*17)/2.0
	for row in lines:
		var line: String = row.text
		var x = 256-line.length()*15/2.0
		for i in range(line.length()):
			var code = line.unicode_at(i)
			if code < 32 or code > 255: code = 63
			var glyph = (OriginalGameFont.animated_glyph(code,clock) if row.animated else code)-32
			draw_texture_rect_region(font,Rect2(x+i*15,y,15,15),Rect2((glyph%16)*16,int(glyph/16.0)*16,15,15),Color(OriginalGameFont.COLOR.r*2,OriginalGameFont.COLOR.g*2,OriginalGameFont.COLOR.b*2,1))
		y += 17
	draw_set_transform(Vector2.ZERO)

static func wrap_text(value: String,columns: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" ",false):
			if not line.is_empty() and line.length()+word.length()+1 > columns:
				lines.append(line)
				line = ""
			line += (" " if not line.is_empty() else "")+word
		lines.append(line)
	return lines
