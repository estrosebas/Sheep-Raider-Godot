extends CanvasLayer
class_name OriginalPauseMenu

var level: Node3D
var checkpoint: Node
var canvas: PauseCanvas
var opened = false
var page = "root"
var selected = 0
var rows: Array[String] = []
var actions: Array[String] = []
var message = ""
var slot = 1
var confirmation = ""
var clock = 0.0
var prior_mouse = true
var prompt_was_visible = true
var noise: ImageTexture
var font: Texture2D
var source: Dictionary
var ui_sound: AudioStreamPlayer
var last_sound = ""

class PauseCanvas extends Control:
	var menu: OriginalPauseMenu
	func _draw() -> void:
		if not menu.opened: return
		draw_texture_rect(menu.noise,Rect2(Vector2.ZERO,size),true,Color.WHITE)
		var scale = minf(size.x/512,size.y/240)
		var offset = (size-Vector2(512,240)*scale)/2
		var title = "PAUSA"
		if menu.page == "save": title = "Guardar partida" if menu.level.scene_file_path==SaveFiles.STUDIO_SCENE else "GUARDAR CHECKPOINT"
		elif menu.page == "load": title = "CARGAR"
		elif menu.page == "choice": title = SaveFiles.slot_description(SaveFiles.read_slot(menu.slot))
		elif menu.page == "options": title = "OPCIONES"
		elif menu.page == "confirm": title = "¿ESTÁS SEGURO?"
		elif menu.page == "front": title = "SHEEP RAIDER"
		text(GameLocalization.ui(title),Vector2(256,16),scale,offset,OriginalGameFont.PAUSE_COLOR)
		var y = 120-menu.rows.size()*17/2.0
		for i in range(menu.rows.size()):
			var color = OriginalGameFont.PAUSE_COLOR
			if i == menu.selected:
				color = Color.WHITE
			text(menu.rows[i],Vector2(256,y+i*17),scale,offset,color,i == menu.selected)
		text(menu.message,Vector2(256,197),scale,offset,Color.WHITE)
		text(GameLocalization.ui("ARRIBA/ABAJO: ELEGIR   ENTER: ACEPTAR"),Vector2(256,216),scale,offset,OriginalGameFont.PAUSE_COLOR)
		text(GameLocalization.ui("ESC: VOLVER"),Vector2(256,231),scale,offset,OriginalGameFont.PAUSE_COLOR)
	func text(value: String,point: Vector2,scale: float,offset: Vector2,color: Color,animated: bool = false) -> void:
		# Font_CloneResized(FONT_GAME, SMALL,10,12): advance9,height13.
		var start = point-Vector2(value.length()*9/2.0,0)
		for i in range(value.length()):
			var code = value.unicode_at(i)
			if code < 32 or code > 255: code = 63
			if animated: code = menu.selected_glyph(code)
			var glyph = code-32
			var region = Rect2((glyph%16)*16,(int(glyph/16.0))*16,15,15)
			draw_texture_rect_region(menu.font,Rect2(offset+(start+Vector2(i*9,0))*scale,Vector2(9,13)*scale),region,Color(color.r*2,color.g*2,color.b*2,color.a))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	level = get_parent()
	checkpoint = level.get_node_or_null("CheckpointSave")
	font = load("res://assets/ui/pause/font.png")
	source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/pause/source.json"))
	ui_sound = AudioStreamPlayer.new()
	add_child(ui_sound)
	var image = Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256): image.set_pixel(x,y,Color(.22,.20,.45,randf_range(.025,.085)))
	noise = ImageTexture.create_from_image(image)
	var background = ColorRect.new()
	background.name = "PauseBackgroundFilter"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/pause_background.gdshader")
	background.material = material
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = PauseCanvas.new()
	canvas.menu = self
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	call_deferred("_startup")

func _startup() -> void:
	checkpoint = level.get_node_or_null("CheckpointSave")
	if checkpoint == null: return
	if SaveFiles.startup_offered: return
	SaveFiles.startup_offered = true
	for i in range(0,4):
		if not SaveFiles.read_slot(i).is_empty():
			open_menu()
			show_page("load")
			return

func open_menu() -> void:
	if opened: return
	checkpoint = level.get_node_or_null("CheckpointSave")
	opened = true
	prior_mouse = level.get_node("Player").mouse_captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	show()
	show_page("root")
	var prompt = level.get_node("Player").get_node_or_null("ActionPrompt")
	if prompt:
		prompt_was_visible = prompt.visible
		prompt.hide()

func close_menu() -> void:
	opened = false
	hide()
	get_tree().paused = false
	for pedestal in get_tree().get_nodes_in_group("studio_pedestals"): pedestal.release_camera()
	level.get_node("Player").capture_mouse(prior_mouse)
	var prompt = level.get_node("Player").get_node_or_null("ActionPrompt")
	if prompt: prompt.visible = prompt_was_visible

func show_page(next: String) -> void:
	page = next
	selected = 0
	message = ""
	match page:
		"root":
			rows.assign(["Opciones","Continuar","Guardar","Cargar","Reiniciar nivel","Salir del nivel","Salir del juego"])
			actions.assign(["options","resume","save","load","restart","exit_level","quit"])
			if level.scene_file_path == SaveFiles.STUDIO_SCENE:
				rows.assign(["Opciones","Continuar","Guardar","Cargar","Laboratorio","Salir del juego"])
				actions.assign(["options","resume","save","load","laboratory","quit"])
			selected = 1
		"save","load":
			rows.clear()
			actions.clear()
			var automatic = SaveFiles.read_slot(SaveFiles.AUTO_SLOT)
			rows.append(GameLocalization.ui("Guardado automático")+": "+(GameLocalization.ui("Vacía") if automatic.is_empty() else SaveFiles.slot_description(automatic)))
			actions.append("slot_0" if page=="load" else "auto_info")
			for i in range(1,4):
				var record = SaveFiles.read_slot(i)
				rows.append(GameLocalization.ui("Ranura %d: %s") % [i,GameLocalization.ui("Vacía") if record.is_empty() else SaveFiles.slot_description(record)])
				actions.append("slot_%d" % i)
			rows.append("Volver")
			actions.append("root")
			if page == "save": message = GameLocalization.ui("Guardar partida") if level.scene_file_path==SaveFiles.STUDIO_SCENE else GameLocalization.ui("Guardado manual del último checkpoint")
		"choice":
			rows.assign(["Continuar desde checkpoint","Reiniciar nivel","Volver"])
			actions.assign(["continue_slot","restart","load"])
			if level.scene_file_path == SaveFiles.STUDIO_SCENE:
				rows.assign(["Cargar partida en el plató","Continuar desde checkpoint","Volver"])
				actions.assign(["load_studio","continue_slot","load"])
		"confirm":
			rows.assign(["No","Sí"])
			actions.assign(["root","confirmed"])
		"front":
			rows.assign(["Cargar partida","Comenzar nivel 00","Salir del juego"])
			actions.assign(["load","restart","quit"])
		"options":
			rows.assign(["Música: activar/desactivar","Pantalla completa","Texturas: original/visor",GameLocalization.ui("Pantallas de carga: %s")%GameLocalization.ui("Sí" if GameLocalization.loading_enabled else "No"),GameLocalization.ui("Estilo de carga: %s")%GameLocalization.ui("Clásico" if GameLocalization.loading_style=="classic" else "Moderno"),"Controles (H)","Volver"])
			actions.assign(["music","fullscreen","textures","loading_enabled","loading_style","controls","root"])
			var statistics = get_tree().get_first_node_in_group("optional_statistics")
			if statistics:
				rows.insert(rows.size()-1,str(statistics.words()[4]))
				actions.insert(actions.size()-1,"privacy")
	for i in range(rows.size()): rows[i] = GameLocalization.ui(rows[i])
	canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	var statistics = get_tree().get_first_node_in_group("optional_statistics")
	if statistics and is_instance_valid(statistics.dialog): return
	# Let the shared touch surface translate fingers before consuming menu input.
	if event is InputEventScreenTouch or event is InputEventScreenDrag: return
	var bonuses = level.get_node_or_null("Bonuses")
	if bonuses and bonuses.opened: return
	var shot = get_tree().get_first_node_in_group("original_launch_camera")
	if shot and event.is_action_pressed("cancel"):
		if shot.elapsed>=1: shot.close()
		get_viewport().set_input_as_handled(); return
	var loading = get_node_or_null("/root/LevelLoading")
	if loading and not loading.target.is_empty(): return
	if event.is_action_pressed("cancel") and not event.is_echo():
		play_ui_sound("cancel" if opened else "confirm")
		if not opened: open_menu()
		elif page == "root": close_menu()
		elif page == "front": pass
		else: show_page("root")
		get_viewport().set_input_as_handled()
		return
	if not opened: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_UP,KEY_W]:
			selected = posmod(selected-1,rows.size())
			play_ui_sound("move")
		elif event.physical_keycode in [KEY_DOWN,KEY_S]:
			selected = posmod(selected+1,rows.size())
			play_ui_sound("move")
		elif event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_E]:
			play_ui_sound("confirm")
			activate(actions[selected])
		canvas.queue_redraw()
	get_viewport().set_input_as_handled()

func activate(action: String) -> void:
	# Level setup adds this node after PauseMenu._ready (notably level01).
	if action.begins_with("slot_") or action=="confirmed": checkpoint = level.get_node_or_null("CheckpointSave")
	if action.begins_with("slot_"):
		slot = int(action.trim_prefix("slot_"))
		if page == "load":
			if SaveFiles.read_slot(slot).is_empty(): message = GameLocalization.ui("Ranura vacía o archivo no válido")
			else: show_page("choice")
		elif checkpoint == null or checkpoint.snapshot.is_empty(): message = GameLocalization.ui("Primero debes alcanzar un checkpoint")
		elif not SaveFiles.read_slot(slot).is_empty():
			confirmation = "save_slot"
			show_page("confirm")
		else: _save_slot()
	elif action == "auto_info": message = GameLocalization.ui("Guardado automático al completar un nivel")
	elif action == "confirmed":
		if confirmation == "save_slot": _save_slot()
		elif confirmation == "quit": get_tree().quit()
		elif confirmation == "exit_level":
			SaveFiles.remember_level_exit(level)
			close_menu(); get_tree().change_scene_to_file(SaveFiles.STUDIO_SCENE)
		else: _reload({"restart":true})
	elif action in ["restart","exit_level","quit"]:
		confirmation = action
		show_page("confirm")
	elif action == "continue_slot": _reload(SaveFiles.read_slot(slot))
	elif action == "load_studio":
		var record = SaveFiles.read_slot(slot)
		if not record.is_empty():
			OriginalProgress.restore(record.get("progress",{})); SaveFiles.remember_checkpoint(record)
			SaveFiles.studio_initialized = true; SaveFiles.pending = {}
			close_menu(); get_tree().change_scene_to_file(SaveFiles.STUDIO_SCENE)
	elif action == "laboratory":
		close_menu(); get_tree().change_scene_to_file("res://scenes/testing/ItemLab.tscn")
	elif action == "privacy":
		var statistics = get_tree().get_first_node_in_group("optional_statistics")
		if statistics: statistics.open_preferences()
	elif action == "resume": close_menu()
	elif action == "music":
		level.get_node("BGMPlayer").stream_paused = not level.get_node("BGMPlayer").stream_paused
	elif action == "textures": level.set_texture_profile(1-level.texture_profile)
	elif action in ["loading_enabled","loading_style"]:
		GameLocalization.save_loading(not GameLocalization.loading_enabled if action=="loading_enabled" else GameLocalization.loading_enabled,("modern" if GameLocalization.loading_style=="classic" else "classic") if action=="loading_style" else GameLocalization.loading_style)
		var prior = selected; show_page("options"); selected = prior
	elif action == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif action == "controls":
		level.help_visible = true
		level.get_node("HUD").show()
		level.get_node("Player").inventory.wheel.set_help_visible(true)
		close_menu()
	else: show_page(action)
	canvas.queue_redraw()

func _save_slot() -> void:
	if slot==SaveFiles.AUTO_SLOT:
		show_page("save"); message = GameLocalization.ui("Guardado automático al completar un nivel"); return
	if level.scene_file_path == SaveFiles.STUDIO_SCENE: checkpoint.capture_checkpoint()
	var error = SaveFiles.write_slot(slot,checkpoint.snapshot)
	show_page("save")
	message = GameLocalization.ui("Partida guardada" if level.scene_file_path==SaveFiles.STUDIO_SCENE else "Checkpoint guardado") if error == OK else GameLocalization.ui("No se pudo guardar (%d)") % error

func _reload(record: Dictionary) -> void:
	if record.is_empty(): return
	SaveFiles.pending = record.duplicate(true)
	close_menu()
	var target = SaveFiles.scene_for_level(str(record.get("level",""))) if SaveFiles.valid(record) else ""
	if not target.is_empty() and target != level.scene_file_path:
		get_tree().change_scene_to_file(target)
	else: get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if opened:
		clock += delta
		canvas.queue_redraw()

func selected_glyph(code: int) -> int:
	return OriginalGameFont.animated_glyph(code,clock)

func play_ui_sound(kind: String) -> void:
	last_sound = kind
	ui_sound.stream = load(source["sounds"][kind]["path"])
	ui_sound.play()

func reload_localization():
	var previous = selected
	show_page(page)
	selected = clampi(previous,0,maxi(0,rows.size()-1))
