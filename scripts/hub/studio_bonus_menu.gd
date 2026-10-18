extends CanvasLayer
# BonusManager's eight entries, prices, four-card list, purchase and viewers.
var source: Dictionary
var opened = false
var page = "list"
var selected = 0
var first_visible = 0
var image_index = 0
var answer = 0
var clock = 0.0
var prior_mouse = true
var bought = false
var save_error = OK
var canvas: BonusCanvas
var atlas: Texture2D
var backdrop: Texture2D
var locked: Texture2D
var unlocked: Texture2D
var arrow: Texture2D
var picture: Texture2D
var text_scroll = 0

class BonusCanvas extends Control:
	var menu
	func _draw():
		if not menu.opened: return
		draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		var factor = minf(size.x/512,size.y/240)
		var offset = (size-Vector2(512,240)*factor)/2
		if menu.page=="images":
			if menu.picture:
				var fit = minf(size.x/menu.picture.get_width(),(size.y-25*factor)/menu.picture.get_height())
				var extent = menu.picture.get_size()*fit
				draw_texture_rect(menu.picture,Rect2(Vector2((size.x-extent.x)/2,(size.y-25*factor-extent.y)/2),extent),false)
			text("A / D   %d / %d   ESC: %s"%[menu.image_index+1,menu.source.entries[menu.selected].images.size(),menu.native_text(11)],Vector2(256,221),factor,offset)
			return
		draw_texture_rect(menu.backdrop,Rect2(offset,Vector2(512,240)*factor),false)
		if menu.page in ["confirm","bought","insufficient"]:
			var index = 8 if menu.page=="confirm" else (9 if menu.page=="bought" else 7)
			paragraph(menu.native_text(index),Rect2(48,76,416,70),factor,offset)
			if menu.page=="confirm":
				text(menu.native_text(10),Vector2(166,161),factor,offset,menu.answer==0)
				text(GameLocalization.ui("Cancelar"),Vector2(346,161),factor,offset,menu.answer==1)
			else: text(menu.native_text(12),Vector2(256,166),factor,offset,true)
			text("E / ENTER: "+GameLocalization.ui("Aceptar"),Vector2(256,215),factor,offset)
			return
		text(menu.native_text(4)%OriginalProgress.bonus_points,Vector2(256,16),factor,offset)
		for row in range(4):
			var identity = menu.first_visible+row
			var rectangle = Rect2(104+row*80,36,63,47)
			var owned = OriginalProgress.bonus_unlocked(identity)
			draw_texture_rect(menu.unlocked if owned else menu.locked,Rect2(offset+rectangle.position*factor,rectangle.size*factor),false,Color.WHITE if identity==menu.selected else Color(.6,.6,.6,1))
			draw_rect(Rect2(offset+rectangle.position*factor,rectangle.size*factor),Color(.94,.25,.25) if identity==menu.selected else Color(.69,.69,.69),false,2*factor)
		for direction in [-1,1]:
			draw_set_transform(offset+Vector2(49 if direction<0 else 461,57)*factor,direction*PI/2,Vector2.ONE*factor)
			draw_texture_rect(menu.arrow,Rect2(-8,-8,16,16),false)
			draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(offset+Vector2(32,92)*factor,Vector2(447,91)*factor),Color(.69,.69,.69),false,factor)
		if menu.page=="text":
			paragraph(menu.native_text(int(menu.source.entries[menu.selected].text_index)),Rect2(42,101,428,74),factor,offset)
		else:
			var entry = menu.source.entries[menu.selected]
			var title = "%s %d: %s"%[menu.native_text(1),menu.selected+1,menu.native_text(13 if entry.kind=="images" else 16)]
			if not OriginalProgress.bonus_unlocked(menu.selected): title += " (%d %s)"%[int(entry.price),menu.native_text(2)]
			paragraph(title+"\n\n"+menu.native_text(17+menu.selected),Rect2(42,101,428,74),factor,offset)
		if menu.page!="text": text("E / ENTER: "+menu.native_text(6 if OriginalProgress.bonus_unlocked(menu.selected) else 5),Vector2(256,195),factor,offset)
		else: text(GameLocalization.ui("ARRIBA/ABAJO: ELEGIR"),Vector2(256,195),factor,offset)
		text("ESC: "+menu.native_text(11),Vector2(256,218),factor,offset)
	func paragraph(value: String,rectangle: Rect2,factor: float,offset: Vector2):
		var lines: Array[String] = []
		var limit = int(rectangle.size.x/9)
		for source_line in value.split("\n"):
			var line = ""
			for word in source_line.split(" "):
				if line.length()+word.length()+1>limit and not line.is_empty(): lines.append(line); line = ""
				line += (" " if not line.is_empty() else "")+word
			lines.append(line)
		var start = clampi(menu.text_scroll,0,maxi(0,lines.size()-4)) if menu.page=="text" else 0
		for i in range(start,mini(lines.size(),start+4)): text(lines[i],Vector2(rectangle.get_center().x,rectangle.position.y+(i-start)*17),factor,offset)
	func text(value: String,point: Vector2,factor: float,offset: Vector2,animated: bool = false):
		value = value.to_upper()
		var x = point.x-value.length()*9/2.0
		for i in range(value.length()):
			var code = value.unicode_at(i)
			if animated: code = OriginalGameFont.animated_glyph(code,menu.clock)
			var glyph = clampi(code,32,255)-32
			var region = Rect2((glyph%16)*16,int(glyph/16)*16,15,15)
			var rect = Rect2(offset+Vector2(x+i*9,point.y)*factor,Vector2(9,13)*factor)
			draw_texture_rect_region(menu.atlas,Rect2(rect.position+Vector2.ONE*factor,rect.size),region,Color.BLACK)
			draw_texture_rect_region(menu.atlas,rect,region,Color(2,1.7,.44,1))

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS; layer = 130
	source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hub/bonuses/manifest.json"))
	atlas = load("res://assets/ui/pause/font.png")
	backdrop = load(source.sprites.background.path); locked = load(source.sprites.locked.path); unlocked = load(source.sprites.unlocked.path)
	arrow = load(source.sprites.arrow.path)
	canvas = BonusCanvas.new(); canvas.menu = self; canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hide()

func native_text(index: int) -> String:
	var value = GameLocalization.text("scene",191,index)
	var expression = RegEx.new(); expression.compile("\\$[^$]*\\$")
	return expression.sub(value,"",true).strip_edges().trim_prefix(",").strip_edges()

func open_menu(_definition: Dictionary):
	if opened: return
	var player = get_parent().player
	player.interrupt_actions(); player.set_state(player.WolfState.IDLE)
	prior_mouse = player.mouse_captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	opened = true; page = "list"; selected = 0; first_visible = 0; bought = false; save_error = OK
	get_tree().paused = true; show(); canvas.queue_redraw()

func close_menu():
	if not opened: return
	if bought:
		get_parent().get_node("CheckpointSave").capture_checkpoint()
		save_error = SaveFiles.write_slot(SaveFiles.AUTO_SLOT,get_parent().get_node("CheckpointSave").snapshot)
		# Keep purchases in memory if disk writing fails; the standard save menu reports it.
	opened = false; picture = null; hide(); get_tree().paused = false
	for pedestal in get_tree().get_nodes_in_group("studio_pedestals"): pedestal.release_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if prior_mouse else Input.MOUSE_MODE_VISIBLE)
	get_parent().refresh_progress()
	if save_error!=OK:
		var pause = get_parent().get_node("PauseMenu"); pause.open_menu(); pause.show_page("save")
		pause.message = GameLocalization.ui("No se pudo guardar (%d)")%save_error

func activate():
	get_parent().get_node("PauseMenu").play_ui_sound("confirm")
	match page:
		"list":
			if not OriginalProgress.bonus_unlocked(selected): page = "confirm"; answer = 0
			elif source.entries[selected].kind=="text": page = "text"; text_scroll = 0
			else: page = "images"; image_index = 0; load_picture()
		"confirm":
			if answer==1: page = "list"
			elif OriginalProgress.buy_bonus(selected,int(source.entries[selected].price)): page = "bought"; bought = true
			else: page = "insufficient"
		"bought","insufficient": page = "list"
	canvas.queue_redraw()

func load_picture(): picture = load(source.entries[selected].images[image_index])
func _input(event: InputEvent):
	if event is InputEventScreenTouch or event is InputEventScreenDrag: return
	if not opened: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			get_parent().get_node("PauseMenu").play_ui_sound("cancel")
			if page=="list": close_menu()
			else: page = "list"; picture = null
		elif event.physical_keycode in [KEY_E,KEY_ENTER,KEY_SPACE]: activate()
		elif page=="text" and event.physical_keycode in [KEY_UP,KEY_DOWN,KEY_W,KEY_S]: text_scroll = clampi(text_scroll+(-1 if event.physical_keycode in [KEY_UP,KEY_W] else 1),0,20)
		elif event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_A,KEY_D]:
			var direction = -1 if event.physical_keycode in [KEY_LEFT,KEY_A] else 1
			if page=="list":
				selected = clampi(selected+direction,0,7); first_visible = clampi(first_visible,selected-3,selected)
			elif page=="confirm": answer = 1-answer
			elif page=="images": image_index = clampi(image_index+direction,0,source.entries[selected].images.size()-1); load_picture()
			get_parent().get_node("PauseMenu").play_ui_sound("move")
		canvas.queue_redraw()
	get_viewport().set_input_as_handled()
func _process(delta: float):
	if opened: clock += delta; canvas.queue_redraw()
