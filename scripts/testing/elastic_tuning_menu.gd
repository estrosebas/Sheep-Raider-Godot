extends CanvasLayer

const Settings = preload("res://scripts/testing/elastic_tuning_settings.gd")
const FIELDS = [
	["max_length","Longitud con un anclaje (m)",2.0,30.0,.1,1.0],
	["two_anchor_max_length","Longitud de tensado entre árboles (m)",2.0,30.0,.1,1.0],
	["spring_strength","Resistencia al estirar (multiplicador)",.1,2.0,.05,1.0],
	["return_speed","Velocidad de retorno yo-yo (m/s)",1.0,30.0,.01,1.0],
	["minimum_launch_charge","Carga mínima para lanzar (%)",0.0,100.0,1.0,100.0],
	["full_charge_threshold","Margen considerado carga completa (%)",50.0,100.0,1.0,100.0],
	["automatic_launch_hold","Espera en carga máxima (s)",0.0,3.0,.05,1.0],
	["projection_distance","Distancia de lanzamiento al máximo (m)",5.0,100.0,1.0,1.0],
	["projection_height","Altura de lanzamiento al máximo (m)",1.0,20.0,.1,1.0],
	["projection_speed","Velocidad de lanzamiento (m/s)",1.0,40.0,.5,1.0]
]
var actor: RalphController
var opened = false
var controller: Node3D
var candidates: Array = []
var spins: Dictionary = {}
var shell: Control
var telemetry: Label
var monitor: Label
var selector: OptionButton
var status: Label
var all_items: CheckBox
var show_monitor: CheckBox
var previous_paused = false
var previous_mouse = true
var manual_elapsed = 0.0
var manual_running = false

func _ready():
	actor = get_parent(); layer = 180; process_mode = Node.PROCESS_MODE_ALWAYS
	build_ui(); shell.hide(); monitor.hide()

func build_ui():
	shell = Control.new(); add_child(shell)
	var theme = Theme.new(); theme.default_font_size = 24; shell.theme = theme
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new(); shade.color = Color(0,0,0,.65)
	shell.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new(); shell.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var panel = PanelContainer.new(); margin.add_child(panel)
	var paint = StyleBoxFlat.new(); paint.bg_color = Color(.055,.075,.10,.98)
	paint.set_content_margin_all(18); paint.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",paint)
	var scroll = ScrollContainer.new(); panel.add_child(scroll)
	var stack = VBoxContainer.new(); stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",10); scroll.add_child(stack)
	var title = Label.new(); title.text = "AJUSTE DEL ELÁSTICO · SUPRIMIR PARA VOLVER"
	title.add_theme_font_size_override("font_size",30); stack.add_child(title)
	var note = Label.new(); note.text = "La partida y la mecha se pausan aquí. Aplica los valores y cierra para medir el recorrido."
	stack.add_child(note)
	selector = OptionButton.new(); stack.add_child(selector)
	selector.item_selected.connect(select_controller)
	var grid = GridContainer.new(); grid.columns = 2; stack.add_child(grid)
	grid.add_theme_constant_override("h_separation",24); grid.add_theme_constant_override("v_separation",6)
	for field in FIELDS:
		var label = Label.new(); label.text = field[1]; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(label)
		var spin = SpinBox.new(); spin.min_value = field[2]; spin.max_value = field[3]; spin.step = field[4]
		spin.custom_minimum_size.x = 180; grid.add_child(spin); spins[field[0]] = spin
	all_items = CheckBox.new(); all_items.text = "Aplicar a todos los elásticos de este nivel"; all_items.button_pressed = true; stack.add_child(all_items)
	var buttons = HBoxContainer.new(); stack.add_child(buttons)
	button(buttons,"Aplicar",apply_values)
	button(buttons,"Guardar ajuste",save_values)
	button(buttons,"Valores originales",func(): populate(Settings.native_values(controller)); status.text = "Valores de C++/WAR preparados. Pulsa Aplicar para probarlos.")
	button(buttons,"Ajuste del nivel",func(): populate(Settings.level_values(controller)); status.text = "Ajuste del nivel preparado. Pulsa Aplicar para probarlo.")
	button(buttons,"Volver al juego",close_menu)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stack.add_child(status)
	var line = HSeparator.new(); stack.add_child(line)
	telemetry = Label.new(); telemetry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stack.add_child(telemetry)
	var tools = HBoxContainer.new(); stack.add_child(tools)
	button(tools,"Iniciar cronómetro",func(): manual_elapsed = 0; manual_running = true; status.text = "Cronómetro armado; cuenta solo mientras juegas.")
	button(tools,"Detener cronómetro",func(): manual_running = false)
	button(tools,"Borrar mediciones",func(): manual_elapsed = 0; manual_running = false; controller.measurement.clear(); controller.last_measurement.clear())
	show_monitor = CheckBox.new(); show_monitor.text = "Mostrar tensión, recorrido y mecha mientras juego"; show_monitor.button_pressed = true
	stack.add_child(show_monitor)
	monitor = Label.new(); add_child(monitor)
	monitor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	monitor.offset_left = -420; monitor.offset_right = -20; monitor.offset_top = 20
	monitor.custom_minimum_size.x = 400; monitor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monitor.add_theme_font_size_override("font_size",18)
	monitor.add_theme_color_override("font_color",Color.WHITE)
	monitor.add_theme_color_override("font_outline_color",Color.BLACK)
	monitor.add_theme_constant_override("outline_size",5)
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE

func button(parent: Node,label: String,callback: Callable):
	var control = Button.new(); control.text = label; parent.add_child(control); control.pressed.connect(callback)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_DELETE or event.keycode==KEY_DELETE):
		if opened: close_menu()
		else: open_menu()
		get_viewport().set_input_as_handled()
	elif opened and event.is_action_pressed("cancel") and not event.is_echo():
		close_menu(); get_viewport().set_input_as_handled()

func open_menu() -> bool:
	if opened: return true
	if get_tree().paused: return false # Do not share ownership with PauseMenu or language selection.
	candidates.clear(); selector.clear()
	var best = 0
	for elastic in get_tree().get_nodes_in_group("elastic_controllers"):
		if elastic.get_world_3d()!=actor.get_world_3d(): continue
		candidates.append(elastic); selector.add_item(str(elastic.item.item_id))
		if elastic.mode!="item": best = candidates.size()-1
	if candidates.is_empty(): return false
	select_controller(best); selector.select(best)
	previous_paused = get_tree().paused; previous_mouse = actor.mouse_captured
	opened = true; shell.show(); monitor.hide(); get_tree().paused = true
	actor.capture_mouse(false)
	for action in ["move_left","move_right","move_forward","move_backward","jump","run","sneak","action","use_item"]: Input.action_release(action)
	status.text = "Los valores guardados se recuperan al volver a entrar. Las partidas y checkpoints no se modifican."
	refresh_telemetry()
	return true

func close_menu():
	if not opened: return
	opened = false; shell.hide(); get_tree().paused = previous_paused
	actor.capture_mouse(previous_mouse)
	monitor.visible = show_monitor.button_pressed

func select_controller(index: int):
	if index<0 or index>=candidates.size(): return
	controller = candidates[index]; populate(controller.tuning_values())

func populate(values: Dictionary):
	for field in FIELDS: spins[field[0]].value = float(values.get(field[0],0))*float(field[5])

func values() -> Dictionary:
	var result = {}
	for field in FIELDS: result[field[0]] = spins[field[0]].value/float(field[5])
	return result

func apply_values():
	var applied = values()
	for elastic in candidates:
		if elastic==controller or all_items.button_pressed: elastic.apply_tuning(applied)
	status.text = "Aplicado. Un anclaje: %.1f m · Tensado: %.1f m · Retorno: %.2f m/s · Carga mínima: %.0f%%"%[controller.max_length,controller.two_anchor_max_length,controller.return_speed,controller.minimum_launch_charge*100]
	refresh_telemetry()

func save_values():
	apply_values()
	var error = Settings.save_values(controller,values())
	status.text = "Ajuste guardado para "+Settings.identity(controller)+" en user://elastic_tuning.cfg" if error==OK else "No se pudo guardar: "+error_string(error)

func _physics_process(delta: float):
	if manual_running and not get_tree().paused: manual_elapsed += delta

func _process(_delta: float):
	if is_instance_valid(controller) and (opened or monitor.visible): refresh_telemetry()

func refresh_telemetry():
	if not is_instance_valid(controller): return
	var trip: Dictionary = controller.measurement if not controller.measurement.is_empty() else controller.last_measurement
	var text = "Tensión: %.0f%% · Estado: %s\nCronómetro: %.2f s\n"%[controller.tension*100,controller.mode,manual_elapsed]
	if not trip.is_empty():
		text += "Recorrido: %.2f s · Bajada/espera: %.2f s\nAcción: %.2f s · Subida/aterrizaje: %.2f s\n"%[trip.elapsed,trip.descent,trip.interaction,trip["return"]]
		if trip.get("interrupted",false): text += "Medición interrumpida.\n"
	else: text += "Recorrido automático: sal del borde con un anclaje para medir.\n"
	var found = false
	for item in get_tree().get_nodes_in_group("game_items"):
		if not item is DynamiteItem or item.get_world_3d()!=actor.get_world_3d() or item.state!="lit": continue
		found = true; text += "Mecha: %.2f / %.2f s restantes\n"%[item.fuse,item.fuse_seconds]
		if not controller.retract.is_empty():
			var remaining = maxf(0,controller.retract.duration*1.25-controller.retract.time)
			text += "Subida pendiente: %.2f s · Margen de mecha: %.2f s\n"%[remaining,item.fuse-remaining]
	if not found: text += "Mecha nativa nivel 03: 5.00 s (WAR 5000 ms)."
	telemetry.text = text; monitor.text = "ELÁSTICO · SUPRIMIR\n"+text

func _exit_tree():
	if opened and is_instance_valid(actor): close_menu()
