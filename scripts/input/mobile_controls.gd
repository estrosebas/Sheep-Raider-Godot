extends CanvasLayer
# One touch surface for native Android and mobile web. Game actions stay in
# InputMap; legacy key-only menus receive the same mapped key events as PC.
# --touch-controls enables desktop testing without changing user settings.
var enabled = false
var canvas: TouchCanvas
var fingers: Dictionary = {}
var held_keys: Dictionary = {}
var move_vector = Vector2.ZERO
var stick_origin = Vector2.ZERO
var stick_position = Vector2.ZERO
var last_scene: Node
var context = "menu"
var buttons: Dictionary = {}
var safe = Rect2()
var unit = 1.0
var icon_cache: Dictionary = {}
var sneak_toggled = false
var sneak_latched_key = 0
const MOVEMENT = ["move_left","move_right","move_forward","move_backward"]

class TouchCanvas extends Control:
	var controls
	func _draw(): controls.draw_controls(self)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 280
	canvas = TouchCanvas.new(); canvas.controls = self
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_enabled(OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args())

func set_enabled(value: bool):
	if enabled != value: release_all()
	enabled = value
	if enabled: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if canvas: canvas.visible = enabled

func _process(_delta):
	if not enabled: return
	if last_scene != get_tree().current_scene:
		release_all(); last_scene = get_tree().current_scene
	var next = input_context()
	if next != context:
		# Inventory is held open with a second finger: retain its Tab press.
		release_movement()
		for key in [KEY_SHIFT,KEY_CTRL,KEY_C,KEY_SPACE,KEY_R]:
			if held_keys.has(key): held_keys.erase(key); send_key(key,false)
		# Menus temporarily release the latch; resume it on return to gameplay.
		if next=="game" and sneak_toggled: press_key(sneak_latched_key)
		for id in fingers.keys():
			if fingers[id].kind in ["stick","camera"]: fingers.erase(id)
		context = next
	update_layout()
	canvas.queue_redraw()

func input_context() -> String:
	var player = get_tree().get_first_node_in_group("player") as RalphController
	var loading = get_node_or_null("/root/LevelLoading")
	var language = get_node_or_null("/root/LanguageMenu")
	if get_tree().paused or not player or (loading and not loading.target.is_empty()) or (language and language.transitioning): return "menu"
	if player.inventory_controls_locked or player.cinematic_controls_locked: return "menu"
	return "game"

func update_layout():
	var size = canvas.size
	safe = Rect2(Vector2.ZERO,size)
	# Native safe area is in screen pixels; convert to viewport canvas units.
	if OS.has_feature("android") or OS.has_feature("ios"):
		var screen = Vector2(DisplayServer.screen_get_size())
		var area = DisplayServer.get_display_safe_area()
		if screen.x>0 and screen.y>0 and area.has_area():
			safe = Rect2(Vector2(area.position)/screen*size,Vector2(area.size)/screen*size)
	unit = minf(safe.size.x/1280.0,safe.size.y/720.0)
	var left = safe.position.x; var top = safe.position.y
	var right = safe.end.x; var bottom = safe.end.y
	buttons = {
		"pause":{"at":Vector2(right-52*unit,top+50*unit),"key":KEY_ESCAPE,"label":"Ⅱ"},
		"language":{"at":Vector2(right-155*unit,top+50*unit),"key":KEY_F5,"label":"IDIOMA"},
		"inventory":{"at":Vector2(left+62*unit,top+50*unit),"key":KEY_TAB,"label":"OBJETOS"},
		"action":{"at":Vector2(right-75*unit,bottom-195*unit),"key":KEY_E,"label":"E"},
	}
	if context=="game":
		buttons.merge({
			"jump":{"at":Vector2(right-80*unit,bottom-70*unit),"key":KEY_SPACE,"label":"SALTAR"},
			"run":{"at":Vector2(right-315*unit,bottom-70*unit),"key":KEY_SHIFT,"label":"CORRER"},
			"sneak":{"at":Vector2(right-200*unit,bottom-245*unit),"key":mapped_key("sneak",KEY_CTRL),"label":"SIGILO"},
		})
		if held_item()!=null:
			buttons["use"] = {"at":Vector2(right-200*unit,bottom-120*unit),"key":KEY_R,"label":"USAR"}
	else:
		buttons.action.label = "ACEPTAR"
		buttons.pause.label = "VOLVER"

func mapped_key(action: String,fallback: int) -> int:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: return event.physical_keycode if event.physical_keycode else event.keycode
	return fallback

func held_item() -> GameItem:
	var player = get_tree().get_first_node_in_group("player") as RalphController
	if not player or not player.inventory: return null
	var item = player.inventory.equipped_node as GameItem
	return item if is_instance_valid(item) and item.holder==player else null

func joystick_center() -> Vector2:
	return Vector2(safe.position.x+145*unit,safe.end.y-145*unit)

func _input(event):
	if event is InputEventScreenTouch and event.pressed and not enabled: set_enabled(true)
	if not enabled: return
	# The updater uses native GUI buttons, not the game's E/arrow translation.
	# Let real touch + emulated mouse reach Control._gui_input here.
	if not get_tree().get_nodes_in_group("update_launcher").is_empty(): return
	if event is InputEventScreenTouch:
		update_layout()
		if event.pressed: touch_down(event.index,event.position)
		else: touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		touch_drag(event.index,event.position,event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
		# A touch must not also request desktop pointer lock / click a menu.
		get_viewport().set_input_as_handled()

func touch_down(id: int,point: Vector2):
	var loading = get_node_or_null("/root/LevelLoading")
	if loading and not loading.target.is_empty():
		loading.request_touch_continue()
		return
	for name in buttons:
		var button = buttons[name]
		if point.distance_to(button.at)<=47*unit:
			if name=="sneak":
				sneak_toggled = not sneak_toggled
				sneak_latched_key = button.key
				if sneak_toggled: press_key(button.key)
				else: release_key(button.key)
				fingers[id] = {"kind":"toggle"}
				return
			fingers[id] = {"kind":"button","key":button.key,"name":name}
			press_key(button.key); return
	if point.distance_to(joystick_center())<=130*unit and not has_finger("stick"):
		stick_origin = joystick_center(); stick_position = point
		fingers[id] = {"kind":"stick"}; update_stick(point); return
	if context=="game" and point.x>safe.get_center().x and not has_finger("camera"):
		fingers[id] = {"kind":"camera"}

func has_finger(kind: String) -> bool:
	for finger in fingers.values():
		if finger.kind==kind: return true
	return false

func touch_drag(id: int,point: Vector2,relative: Vector2):
	if not fingers.has(id): return
	match fingers[id].kind:
		"stick": update_stick(point)
		"camera":
			var player = get_tree().get_first_node_in_group("player") as RalphController
			if player and context=="game" and not get_tree().paused: player.rotate_view(relative/maxf(unit,.01))

func touch_up(id: int):
	if not fingers.has(id): return
	var finger = fingers[id]; fingers.erase(id)
	if finger.kind=="button": release_key(finger.key)
	elif finger.kind=="stick": release_movement()

func update_stick(point: Vector2):
	var vector = ((point-stick_origin)/(90*unit)).limit_length()
	stick_position = stick_origin+vector*90*unit
	if context=="menu":
		var direction = Vector2.ZERO
		if vector.length()>.4:
			if absf(vector.x)>absf(vector.y): direction.x = signf(vector.x)
			else: direction.y = signf(vector.y)
		var old = move_vector; move_vector = direction
		var keys = [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
		var before = [old.x<0,old.x>0,old.y<0,old.y>0]
		var after = [direction.x<0,direction.x>0,direction.y<0,direction.y>0]
		for i in range(4):
			if before[i] and not after[i]: release_key(keys[i])
			elif after[i] and not before[i]: press_key(keys[i])
	else:
		move_vector = Vector2.ZERO if vector.length()<.15 else vector.normalized()*((vector.length()-.15)/.85)
		var strengths = [maxf(-move_vector.x,0),maxf(move_vector.x,0),maxf(-move_vector.y,0),maxf(move_vector.y,0)]
		for i in range(4):
			if strengths[i]>0: Input.action_press(MOVEMENT[i],strengths[i])
			else: Input.action_release(MOVEMENT[i])

func press_key(key: int):
	held_keys[key] = int(held_keys.get(key,0))+1
	if held_keys[key]==1: send_key(key,true)

func release_key(key: int):
	if not held_keys.has(key): return
	held_keys[key] -= 1
	if held_keys[key]<=0: held_keys.erase(key); send_key(key,false)

func send_key(key: int,pressed: bool):
	var event = InputEventKey.new(); event.physical_keycode = key; event.keycode = key
	event.pressed = pressed; event.device = 100
	# Some inherited bindings (Tab/R) carry an explicit device16 filter.
	for action in ["inventory","use_item"]:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey and binding.physical_keycode==key and binding.device>=0: event.device = binding.device
	Input.parse_input_event(event)

func release_movement():
	for action in MOVEMENT: Input.action_release(action)
	for key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		if held_keys.has(key): held_keys.erase(key); send_key(key,false)
	move_vector = Vector2.ZERO

func release_all():
	for key in held_keys.keys(): send_key(key,false)
	held_keys.clear(); fingers.clear(); release_movement()
	sneak_toggled = false; sneak_latched_key = 0

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: release_all()

func draw_controls(target: Control):
	if not enabled: return
	if not get_tree().get_nodes_in_group("update_launcher").is_empty(): return
	var loading = get_node_or_null("/root/LevelLoading")
	if loading and not loading.target.is_empty(): return
	update_layout()
	var center = stick_origin if has_finger("stick") else joystick_center()
	target.draw_circle(center,100*unit,Color(.03,.06,.1,.32))
	target.draw_arc(center,100*unit,0,TAU,48,Color(1,1,1,.55),2*unit,true)
	var knob = stick_position if has_finger("stick") else center
	target.draw_circle(knob,38*unit,Color(.75,.88,1,.45))
	if context=="menu":
		for hint in [Vector2(-72,0),Vector2(72,0),Vector2(0,-72),Vector2(0,72)]:
			var direction = hint.normalized()
			var at = center+hint*unit
			var wing = direction.orthogonal()*7*unit
			target.draw_polyline(PackedVector2Array([at-direction*6*unit+wing,at+direction*6*unit,at-direction*6*unit-wing]),Color.WHITE,2*unit,true)
	for name in buttons:
		var button = buttons[name]; var pressed = sneak_toggled if name=="sneak" else held_keys.has(button.key)
		target.draw_circle(button.at,44*unit,Color(.2,.5,.7,.75) if pressed else Color(.03,.06,.1,.45))
		target.draw_arc(button.at,44*unit,0,TAU,36,Color(1,1,1,.75),2*unit,true)
		var icon = button_icon(name)
		if icon:
			var extent = icon.get_size()
			var icon_size = extent*minf(65*unit/extent.x,65*unit/extent.y)
			var tint = Color.WHITE
			target.draw_texture_rect(icon,Rect2(button.at-icon_size/2,icon_size),false,tint)
		elif name=="pause":
			if context=="menu":
				var at: Vector2 = button.at
				target.draw_line(at+Vector2(18,0)*unit,at-Vector2(18,0)*unit,Color.WHITE,4*unit,true)
				target.draw_polyline(PackedVector2Array([at+Vector2(-4,-14)*unit,at+Vector2(-18,0)*unit,at+Vector2(-4,14)*unit]),Color.WHITE,4*unit,true)
			else:
				for x in [-12,5]: target.draw_rect(Rect2(button.at+Vector2(x,-17)*unit,Vector2(7,34)*unit),Color.WHITE)
		elif name=="language":
			# Neutral globe symbol until dedicated language artwork is supplied.
			target.draw_arc(button.at,22*unit,0,TAU,40,Color.WHITE,2*unit,true)
			target.draw_line(button.at+Vector2(-22,0)*unit,button.at+Vector2(22,0)*unit,Color.WHITE,2*unit,true)
			var meridian = PackedVector2Array()
			for i in range(41):
				var angle = TAU*i/40.0
				meridian.append(button.at+Vector2(cos(angle)*10,sin(angle)*22)*unit)
			target.draw_polyline(meridian,Color.WHITE,2*unit,true)

func button_icon(name: String) -> Texture2D:
	var path = ""
	if name=="action": path = "res://assets/ui/mobile/interact_hand.png"
	elif name in ["jump","run","sneak"]: path = "res://assets/ui/mobile/"+name+".png"
	elif name=="inventory": path = "res://assets/ui/inventory/cloud_0.png"
	elif name=="use":
		var item = held_item()
		if not item: return null
		path = item.icon_path
		var player = get_tree().get_first_node_in_group("player") as RalphController
		if player and player.inventory:
			var selected = player.inventory.state.get_selected_object()
			var candidate = str(selected.get("icon",""))
			if not candidate.is_empty() and ResourceLoader.exists(candidate): path = candidate
	if path.is_empty(): return null
	if not icon_cache.has(path):
		var texture: Texture2D = load(path)
		var sprite = AtlasTexture.new(); sprite.atlas = texture
		# Crop only the atlas sampling region, preserving the supplied PNG.
		# Original hand sprites and 500px custom art have different margins.
		sprite.region = Rect2(texture.get_image().get_used_rect()); sprite.filter_clip = true
		icon_cache[path] = sprite
	return icon_cache[path]
