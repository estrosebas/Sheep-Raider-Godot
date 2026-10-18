extends Node

var overlay: CanvasLayer
var wheel: OriginalLanguageWheel
var transition: OriginalRestartFade
var transitioning = false
var actor: RalphController
var was_paused = false
var opened_locale = ""
var input_states: Array[Dictionary] = []
var mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var statistics = load("res://scripts/ui/optional_statistics.gd").new()
	add_child(statistics)

func _input(event):
	var statistics = get_tree().get_first_node_in_group("optional_statistics")
	if statistics and is_instance_valid(statistics.dialog): return
	var loading = get_node_or_null("/root/LevelLoading")
	if loading and not loading.target.is_empty(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if transitioning:
		get_viewport().set_input_as_handled()
		return
	if overlay:
		get_viewport().set_input_as_handled()
		if transitioning: return
		if event.physical_keycode in [KEY_ESCAPE,KEY_F5]: call_deferred("close")
		elif event.physical_keycode in [KEY_LEFT,KEY_A]: wheel.turn(-1)
		elif event.physical_keycode in [KEY_RIGHT,KEY_D]: wheel.turn(1)
		elif event.physical_keycode in [KEY_ENTER,KEY_E,KEY_SPACE]: wheel.confirm()
		return
	if event.physical_keycode != KEY_F5: return
	var player = get_tree().get_first_node_in_group("player") as RalphController
	if not player: return
	open_for(player)
	get_viewport().set_input_as_handled()

func open_for(player: RalphController) -> bool:
	if overlay or transitioning: return false
	actor = player
	opened_locale = GameLocalization.locale
	was_paused = get_tree().paused
	mouse_mode = Input.mouse_mode
	input_states.clear()
	suspend_input(get_tree().current_scene)
	get_tree().paused = true
	overlay = CanvasLayer.new()
	overlay.layer = 250
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	transitioning = true
	_enter()
	return true

func _enter():
	await fade_to(1)
	var container = SubViewportContainer.new()
	container.stretch = true
	overlay.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	wheel = load("res://scenes/startup/LanguageWheel.tscn").instantiate()
	wheel.modal = true
	viewport.add_child(wheel)
	wheel.closed.connect(close)


	await fade_to(0)
	transitioning = false

func close():
	if not overlay or transitioning: return
	transitioning = true
	await fade_to(1)
	# Keep the exact scene instance, inventory, physical state and camera.
	if GameLocalization.locale != opened_locale: refresh(get_tree().current_scene)
	overlay.queue_free()
	overlay = null
	wheel = null
	await fade_to(0)
	for state in input_states:
		if is_instance_valid(state.node):
			state.node.set_process_input(state.input)
			state.node.set_process_unhandled_input(state.unhandled)
	input_states.clear()
	transitioning = false
	get_tree().paused = was_paused
	if is_instance_valid(actor): actor.capture_mouse(mouse_mode == Input.MOUSE_MODE_CAPTURED)
	else: Input.mouse_mode = mouse_mode
	actor = null

func refresh(node: Node):
	if not is_instance_valid(node): return
	if node.has_method("reload_localization"): node.reload_localization()
	for child in node.get_children(): refresh(child)

func suspend_input(node: Node):
	if not is_instance_valid(node): return
	input_states.append({"node":node,"input":node.is_processing_input(),"unhandled":node.is_processing_unhandled_input()})
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child in node.get_children(): suspend_input(child)

func fade_to(amount: float):
	if not is_instance_valid(transition):
		transition = OriginalRestartFade.new()
		transition.layer = 300
		transition.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(transition)
		# _ready supplies layer90, so restore the top layer after adding it.
		transition.layer = 300
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(transition.set_amount,transition.overlay.color.a,amount,OriginalRestartFade.DURATION)
	await tween.finished

func reveal_startup():
	transitioning = true
	if not is_instance_valid(transition):
		transition = OriginalRestartFade.new()
		add_child(transition)
		transition.layer = 300
	transition.set_amount(1)
	await fade_to(0)
	transitioning = false

func change_scene(path: String):
	if transitioning: return
	transitioning = true
	await fade_to(1)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_to(0)
	transitioning = false
