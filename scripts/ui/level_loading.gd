extends CanvasLayer
# Only LabLevelDoor calls this singleton. F6, restart and saves remain direct.
var target = ""
var artwork: Texture2D
var classic_ready: Texture2D
var modern = false
var ready_to_enter = false
var elapsed = 0.0
var fraction = 0.0
var minimum_duration = 2.0
var was_paused = false
var old_mouse = Input.MOUSE_MODE_VISIBLE
var canvas: LoadingCanvas
var failure = ""
var font: Texture2D
var bar_frame: Texture2D
var preparing = false
var preparation_complete = false
var prepared_scene: Node
var timing: Dictionary = {}
const BAR_COLOR = Color(.94,.94,.91,1)

class LoadingCanvas extends Control:
	var owner_ui
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
		var picture: Texture2D = owner_ui.classic_ready if owner_ui.ready_to_enter and not owner_ui.modern and owner_ui.classic_ready else owner_ui.artwork
		if picture:
			var factor = minf(size.x/picture.get_width(),size.y/picture.get_height())
			var extent = picture.get_size()*factor
			draw_texture_rect(picture,Rect2((size-extent)/2,extent),false)
		var factor = minf(size.x/512,size.y/240)
		var offset = (size-Vector2(512,240)*factor)/2
		var touch_ready = owner_ui.touch_enabled() and owner_ui.ready_to_enter
		if touch_ready and not owner_ui.modern:
			# Cover the baked keyboard prompt in classic artwork; leave PC intact.
			draw_rect(Rect2(offset+Vector2(0,191)*factor,Vector2(512,19)*factor),Color(.025,.035,.07,1))
		var filled = 195*owner_ui.fraction
		draw_texture_rect(owner_ui.bar_frame,Rect2(offset+Vector2(148,208)*factor,Vector2(211,21)*factor),false)
		if filled>0:
			# Opaque fill above the sampled frame; don't let desk/paper show through.
			draw_rect(Rect2(offset+Vector2(154,215)*factor,Vector2(filled,7)*factor),owner_ui.BAR_COLOR)
		if owner_ui.modern:
			text(GameLocalization.ui("Cargando..."),Vector2(256,14),factor,offset)
			if owner_ui.ready_to_enter and not touch_ready: text(GameLocalization.ui("Pulsa E para continuar"),Vector2(256,195),factor,offset)
		if touch_ready: text(GameLocalization.ui("Toca la pantalla para continuar"),Vector2(256,195),factor,offset)
		if not owner_ui.failure.is_empty(): text(owner_ui.failure,Vector2(256,175),factor,offset)
	func text(value: String,point: Vector2,factor: float,offset: Vector2):
		var atlas: Texture2D = owner_ui.font
		var x = point.x-value.length()*9/2.0
		# Modern text is separate from the artwork and follows current locale.
		for i in range(value.length()):
			var code = value.unicode_at(i); var glyph = clampi(code,32,255)-32
			var region = Rect2((glyph%16)*16,int(glyph/16.0)*16,15,15)
			var rectangle = Rect2(offset+Vector2(x+i*9,point.y)*factor,Vector2(9,13)*factor)
			for shift in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1)]:
				draw_texture_rect_region(atlas,Rect2(rectangle.position+shift*factor,rectangle.size),region,Color(.03,.08,.27,1))
			draw_texture_rect_region(atlas,rectangle,region,Color(2,1.7,.44,1))

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS; layer = 300
	font = load("res://assets/ui/pause/font.png")
	bar_frame = load("res://assets/ui/loading/bar_frame.png")
	canvas = LoadingCanvas.new(); canvas.owner_ui = self; add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP; hide()

func image_paths(scene_path: String,style: String) -> Dictionary:
	var number = scene_path.get_file().get_basename().trim_prefix("Level")
	var stem = "LEV"+number
	var original = "res://remaster/pantallas_carga/"+stem+".png"
	var remaster = "res://assets/ui/loading/modern/"+stem+".jpg"
	if not ResourceLoader.exists(remaster): remaster = "res://assets/ui/loading/modern/"+stem+".png"
	var classic = "res://assets/ui/loading/classic/"+GameLocalization.locale+"/"+stem
	return {"art":(remaster if ResourceLoader.exists(remaster) else original) if style=="modern" else classic+"_loading.png","combined":classic+"_ready.png"}

func enter_from_door(scene_path: String) -> bool:
	if not target.is_empty(): return false
	GameLocalization.ensure()
	if not GameLocalization.loading_enabled:
		enter_direct(scene_path); return true
	var paths = image_paths(scene_path,GameLocalization.loading_style)
	artwork = load(paths.art) if ResourceLoader.exists(paths.art) else null
	classic_ready = load(paths.combined) if ResourceLoader.exists(paths.combined) else null
	modern = GameLocalization.loading_style=="modern"
	if artwork == null: enter_direct(scene_path); return true
	var result = ResourceLoader.load_threaded_request(scene_path,"PackedScene")
	if result != OK: enter_direct(scene_path); return true
	target = scene_path; elapsed = 0; fraction = 0; ready_to_enter = false; failure = ""
	preparing = false; preparation_complete = false; prepared_scene = null
	timing = {"started_us":Time.get_ticks_usec()}
	was_paused = get_tree().paused; old_mouse = Input.mouse_mode
	get_tree().paused = true; Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE); show()
	return true

func _process(delta):
	if target.is_empty() or not visible: return
	elapsed += delta
	# Deliberately simulated progress, capped until real loading is complete.
	fraction = minf(.95,elapsed/minimum_duration)
	if preparation_complete and elapsed>=minimum_duration:
		fraction = 1; ready_to_enter = true
	elif not preparing and not preparation_complete:
		var status = ResourceLoader.load_threaded_get_status(target)
		if status == ResourceLoader.THREAD_LOAD_LOADED: prepare_scene()
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: failure = GameLocalization.ui("No se pudo cargar el nivel")
	canvas.queue_redraw()

func prepare_scene():
	preparing = true
	timing["resource_ms"] = (Time.get_ticks_usec()-timing.started_us)/1000.0
	var began = Time.get_ticks_usec()
	var packed = ResourceLoader.load_threaded_get(target) as PackedScene
	if not packed or get_tree().change_scene_to_packed(packed)!=OK:
		failure = GameLocalization.ui("No se pudo cargar el nivel"); return
	# Change the real scene while covered/paused. Its _ready and deferred
	# imported-asset setup now finish before we offer the continue button.
	await get_tree().scene_changed
	prepared_scene = get_tree().current_scene
	await get_tree().process_frame; await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	timing["preparation_ms"] = (Time.get_ticks_usec()-began)/1000.0
	preparation_complete = true; preparing = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_entry_iris():
	var level = get_tree().current_scene
	var entry = level.get_node_or_null("EntryController")
	if not entry:
		entry = preload("res://scripts/levels/original_level_entry.gd").new()
		entry.name = "EntryController"; level.add_child(entry)
	entry.begin()

func enter_direct(scene_path: String):
	target = scene_path; ready_to_enter = false
	get_tree().change_scene_to_file(scene_path)
	await get_tree().scene_changed
	start_entry_iris(); target = ""

func _input(event):
	if event is InputEventScreenTouch:
		if not target.is_empty():
			if event.pressed: request_touch_continue()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag: return
	if target.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if ready_to_enter and (event.physical_keycode in [KEY_E,KEY_ENTER,KEY_SPACE] or (not modern and event.physical_keycode==KEY_X)): call_deferred("finish")
		elif not failure.is_empty() and event.physical_keycode==KEY_ESCAPE: cancel()
	get_viewport().set_input_as_handled()

func request_touch_continue() -> bool:
	if target.is_empty() or not ready_to_enter or not failure.is_empty(): return false
	call_deferred("finish")
	return true

func touch_enabled() -> bool:
	var controls = get_node_or_null("/root/MobileControls")
	return controls!=null and controls.enabled

func finish():
	if target.is_empty() or not ready_to_enter: return
	var began = Time.get_ticks_usec()
	start_entry_iris()
	target = ""; hide(); get_tree().paused = false
	restore_mouse()
	timing["confirm_ms"] = (Time.get_ticks_usec()-began)/1000.0

func cancel():
	if not target.is_empty() and ResourceLoader.load_threaded_get_status(target)==ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(target)
	target = ""; hide(); get_tree().paused = was_paused; restore_mouse()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.cinematic_controls_locked = false; player.restart_fade.set_amount(0)

func restore_mouse():
	var scene = get_tree().current_scene
	var player = scene.get_node_or_null("Player") if scene else null
	if player is RalphController: player.capture_mouse(old_mouse == Input.MOUSE_MODE_CAPTURED)
	else: Input.set_mouse_mode(old_mouse)
