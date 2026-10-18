extends GameItem
class_name OriginalWorldNote
var visual_scene = "res://assets/levels/lvl_01/models/21/worn.tscn"
var text = ""
var source_level = "lvl_01"
var native_text_index = -1
var opened = false
var actor: RalphController
var ui: CanvasLayer
var text_box: OriginalTextBox
@export var read_distance = .75
func _init() -> void: class_id = 78
func _ready() -> void:
	super._ready()
	add_to_group("world_interactables")
	var model = load(visual_scene).instantiate()
	add_child(model)
	item_label = "Nota"
	hint.text = "E · Leer nota"
	ui = CanvasLayer.new()
	ui.layer = 41
	add_child(ui)
	var body = Label.new()
	body.text = text.strip_edges()
	ui.add_child(body)
	body.hide()
	text_box = OriginalTextBox.new()
	text_box.text_label = body
	ui.add_child(text_box)
	text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hide()
func can_pickup(_player: RalphController) -> bool: return false
func collect(_inventory: Node) -> bool: return false
func can_interact(player: Node3D) -> bool:
	if opened or not available or not player.can_use_item() or not player.is_on_floor(): return false
	var distance = player.global_position.distance_to(global_position)
	if distance >= read_distance: return false
	# When the delivered item is nearer, E must collect it rather than read
	# this adjacent note. Standing nearer the note still allows reading it.
	for pickup in get_tree().get_nodes_in_group("inventory_pickups"):
		if pickup == self or not pickup is GameItem or pickup.get_world_3d() != get_world_3d(): continue
		if pickup.can_pickup(player) and player.global_position.distance_to(pickup.global_position) <= distance: return false
	return true
func interact(player: Node3D) -> bool:
	if not can_interact(player): return false
	actor = player
	actor.interrupt_actions()
	actor.tutorial_movement_locked = true
	opened = true
	ui.show()
	return true
func _input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("action") and not event.is_echo():
		opened = false
		ui.hide()
		actor.tutorial_movement_locked = false
		get_viewport().set_input_as_handled()

func reload_localization():
	if not has_meta("original_resource"): return
	if native_text_index >= 0:
		text = GameLocalization.text(source_level,79,native_text_index)
		text_box.text_label.text = text.strip_edges()
		return
	var notes = GameLocalization.load_data("res://assets/levels/lvl_01/data/notes.json")
	text = str(notes.get(str(int(get_meta("original_resource"))),text))
	text_box.text_label.text = text.strip_edges()
