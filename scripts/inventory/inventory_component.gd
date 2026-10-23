extends Node

const State = preload("res://scripts/inventory/inventory_state.gd")
const Wheel = preload("res://scenes/ui/InventoryWheel.tscn")
const WheelRules = preload("res://scripts/inventory/inventory_wheel_rules.gd")
signal equipped(item: Dictionary)
signal use_requested(item: Dictionary, actor: Node)
signal item_used(item: Dictionary)
var state = State.new()
var wheel: CanvasLayer
var wheel_open = false
var rotation_remaining = 0.0
var equipped_id = ""
var use_handlers: Dictionary = {}
var pickup_nodes: Dictionary = {}
var actor: Node
var repeat_timer = 0.0
var equipped_node: Node
var animate_selection = false
@export var allow_world_placement = true

func _ready() -> void:
	actor = get_parent()
	wheel = Wheel.instantiate()
	add_child(wheel)
	wheel.bind_state(state)
	state.changed.connect(_on_inventory_changed)
	state.rolled_back.connect(_on_rollback)
	equipped.connect(_equip_world_item)
	set_process_input(true)

func can_open() -> bool:
	if actor is RalphController and is_instance_valid(actor.carried_object): return false
	if actor is RalphController and is_instance_valid(actor.carried_sheep): return false
	return actor.has_method("can_use_inventory") and actor.can_use_inventory()

func open_wheel() -> bool:
	if actor is RalphController and is_instance_valid(actor.carried_object): return false
	if wheel_open:
		return true
	if not can_open():
		return false
	state.clear_selection()
	wheel_open = true
	rotation_remaining = 0.0
	repeat_timer = 0.0
	actor.inventory_controls_locked = true
	wheel.set_open(true)
	return true

func close_wheel(cancelled: bool = false) -> void:
	if not wheel_open:
		return
	wheel_open = false
	actor.inventory_controls_locked = false
	if cancelled:
		if state.items.has(equipped_id):
			state.select_class(int(state.items[equipped_id]["class_id"]))
		else:
			state.clear_selection()
	else:
		var item = state.get_selected_object()
		equipped_id = str(item.get("id", ""))
		animate_selection = true
		equipped.emit(item)
		animate_selection = false
	wheel.set_open(false)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag: return
	if actor is RalphController and is_instance_valid(actor.active_bush) and event.is_action_pressed("action") and not event.is_echo() and not actor.cinematic_controls_locked:
		actor.active_bush.leave()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not event.is_echo():
		open_wheel()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("inventory"):
		close_wheel()
		get_viewport().set_input_as_handled()
	elif wheel_open:
		if event.is_action_pressed("cancel"):
			close_wheel(true)
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()
	# Disabled generic Q drop: this was a port/debug shortcut, not an item
	# action. Keep for reference; placement belongs to each item's use_item
	# (lettuce, perfume, etc.), so Q cannot discard equipment or a rocket.
	# elif allow_world_placement and event.is_action_pressed("drop_item") and not event.is_echo() and not wheel_open and actor.can_use_item():
	#	if is_instance_valid(equipped_node) and equipped_node.has_method("place_in_world") and actor.active_rocket == null:
	#		if equipped_node is LettuceItem: use_selected()
	#		else: equipped_node.place_in_world(actor)
	#	get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action") and not event.is_echo() and actor.can_use_item():
		interact_or_use()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_item") and not event.is_echo() and actor.can_use_item():
		use_selected()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	rotation_remaining = maxf(0.0, rotation_remaining - delta)
	repeat_timer = maxf(0.0, repeat_timer - delta)
	if wheel_open:
		if not can_open():
			close_wheel()
			return
		if rotation_remaining <= 0.0 and repeat_timer <= 0.0:
			if Input.is_action_pressed("move_left"):
				turn(-1)
			elif Input.is_action_pressed("move_right"):
				turn(1)

func turn(direction: int) -> bool:
	if not wheel_open or rotation_remaining > 0.0:
		return false
	if direction < 0:
		state.select_prev()
	else:
		state.select_next()
	rotation_remaining = WheelRules.TURN_DURATION
	repeat_timer = WheelRules.TURN_DURATION
	wheel.animate_turn(direction, rotation_remaining)
	return true

func add_item(item: Dictionary, pickup: Node = null, equip_immediately: bool = true) -> bool:
	if not state.add(item):
		return false
	if pickup != null:
		pickup_nodes[str(item["id"])] = pickup
	state.select_class(int(item["class_id"]))
	if equip_immediately:
		equipped_id = str(item["id"])
		equipped.emit(state.get_selected_object())
	wheel.show_message(GameLocalization.ui("Recogido: ") + str(item.get("label", "Objeto")))
	return true

func register_use_handler(kind: int, handler: Callable) -> void:
	use_handlers[kind] = handler

func use_selected() -> bool:
	if actor is RalphController and is_instance_valid(actor.carried_object): return actor.carried_object.interact(actor)
	if actor is RalphController and actor.climb_motion.active(): return false
	if actor is RalphController and is_instance_valid(actor.carried_sheep): return false
	var item = state.get_selected_object()
	if item.is_empty() or wheel_open or not actor.can_use_item():
		return false
	use_requested.emit(item, actor)
	var handler: Callable = use_handlers.get(int(item["class_id"]), Callable())
	if not handler.is_valid() and is_instance_valid(equipped_node) and equipped_node.has_method("use_item"):
		handler = func(_item, using_actor): return equipped_node.use_item(using_actor)
	if not handler.is_valid():
		wheel.show_message("%s: uso pendiente de implementar" % item.get("label", "Objeto"))
		return false
	# Contract: {success: bool, consumed: bool}. Failed/unsupported uses retain items.
	var result = handler.call(item, actor)
	if not result is Dictionary or not bool(result.get("success", false)):
		return false
	if bool(result.get("consumed", false)):
		state.remove(str(item["id"]))
	item_used.emit(item)
	return true

func interact_or_use() -> void:
	if actor.active_rocket != null:
		use_selected()
		return
	var target = interaction_target()
	if target:
		if target.is_in_group("world_interactables"): target.interact(actor)
		else: target.collect(self)
		return
	use_selected()

func interaction_target() -> Node3D:
	if not actor.can_use_item():
		return null
	if is_instance_valid(actor.carried_object): return actor.carried_object
	if actor.climb_motion.climbing(): return actor.climb_motion.zone
	var nearest: Node3D = null
	var best = 2.5
	for pickup in get_tree().get_nodes_in_group("inventory_pickups"):
		if not pickup.available or pickup.get_world_3d() != actor.get_world_3d():
			continue
		if pickup is GameItem and actor is RalphController and not pickup.can_pickup(actor): continue
		var distance = actor.global_position.distance_to(pickup.global_position)
		if distance < best:
			best = distance
			nearest = pickup
	for target in get_tree().get_nodes_in_group("world_interactables"):
		if target.get_world_3d() != actor.get_world_3d() or not target.is_visible_in_tree(): continue
		if target.can_interact(actor):
			# A harvestable vegetable beside an NPC must not open its dialogue.
			if nearest and target is OriginalNpcConversation: return nearest
			return target
	return nearest

func _on_inventory_changed() -> void:
	if not equipped_id.is_empty() and not state.items.has(equipped_id):
		var replacement = state.get_selected_object()
		equipped_id = str(replacement.get("id", ""))
		equipped.emit(replacement)

func _on_rollback(items: Array) -> void:
	for item in items:
		var pickup = pickup_nodes.get(str(item["id"]))
		if is_instance_valid(pickup):
			pickup.restore()

func _equip_world_item(item: Dictionary) -> void:
	var next = pickup_nodes.get(str(item.get("id", "")))
	if animate_selection and next != equipped_node and actor is RalphController and (next == null or next is GameItem) and (equipped_node == null or equipped_node is GameItem):
		if actor.item_actions.equip(next,equipped_node):
			equipped_node = next
			return
	if is_instance_valid(equipped_node) and equipped_node != next and equipped_node.has_method("store"):
		# A placed object already left inventory; don't hide it on unequip.
		if (equipped_node is GameItem and equipped_node.holder == actor and not equipped_node.deployed) or (not equipped_node is GameItem and state.items.has(equipped_node.item_id)):
			equipped_node.store()
	equipped_node = next if is_instance_valid(next) else null
	if is_instance_valid(equipped_node) and equipped_node.has_method("equip_to"):
		equipped_node.equip_to(actor)

func reload_localization():
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	for item in state.items.values():
		var definition: Dictionary = definitions.get(str(int(item.class_id)),{})
		if definition.has("label"): item["label"] = GameLocalization.ui(definition.label)
	state.changed.emit()
