extends "res://scripts/inventory/inventory_pickup.gd"
class_name GameItem

signal activated(actor: Node3D)
signal deactivated
signal placed(position: Vector3)
@export var definition_key = ""
@export var show_pickup_hint = true
@export var preserve_source_pivot = false
var holder: Node3D
var owning_inventory: Node
var active = false
var deployed = false
var home_position = Vector3.ZERO
var visual: MeshInstance3D
var hint: Label3D
var sound: AudioStreamPlayer3D
var definition: Dictionary = {}
var delivery_mailbox: OriginalMailbox

func _ready() -> void:
	super._ready()
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/definitions.json"))
	definition = definitions.get(str(class_id), {})
	if not definition.is_empty():
		definition_key = str(definition["slug"])
		item_label = GameLocalization.ui(str(definition["label"]))
		icon_path = "res://assets/items/%s/icon.png" % definition_key
		var original_icon = "res://assets/ui/inventory/icon_%d.png" % class_id
		if ResourceLoader.exists(original_icon):
			icon_path = original_icon
		visual = get_node_or_null("Visual")
		if visual == null:
			visual = MeshInstance3D.new()
			visual.name = "Visual"
			add_child(visual)
		visual.mesh = load(definition["mesh"])
		# Keep source pivots; pickup mesh origins are not always at ground level.
		var box = visual.mesh.get_aabb()
		visual.position.y = 0.0 if preserve_source_pivot else -box.position.y
	home_position = global_position
	hint = Label3D.new()
	hint.text = "E · " + item_label
	hint.font_size = 36
	hint.pixel_size = 0.005
	hint.position.y = 0.9
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.visible = false
	add_child(hint)
	sound = AudioStreamPlayer3D.new()
	sound.volume_db = -3.0
	sound.max_distance = 25.0
	add_child(sound)
	add_to_group("game_items")

func collect(inventory: Node) -> bool:
	if not available:
		return false
	if inventory.actor is RalphController and inventory.actor.item_actions:
		return inventory.actor.item_actions.pickup(self,inventory)
	available = false
	deployed = false
	deactivate()
	if not inventory.add_item({"id": item_id, "class_id": class_id, "label": item_label,
		"icon": icon_path, "kept": kept}, self):
		available = true
		return false
	owning_inventory = inventory
	return true

func can_pickup(actor: RalphController) -> bool:
	# Point-object branch of ScanInteractables: radius 100, yRange 50 units.
	var difference = global_position-actor.global_position
	return available and actor.is_on_floor() and absf(difference.y) <= 0.5 and Vector2(difference.x,difference.z).length_squared() <= 1.0

func equip_to(actor: Node3D) -> void:
	holder = actor
	available = false
	deployed = false
	show()
	hint.hide()
	_update_held_position()

func store() -> void:
	deactivate()
	holder = null
	deployed = false
	hide()

func deactivate() -> void:
	active = false
	if sound:
		sound.stop()
	deactivated.emit()

func restore() -> void:
	deactivate()
	holder = null
	deployed = false
	global_position = home_position
	available = true
	show()
	hint.visible = false

func use_item(_actor: Node3D) -> Dictionary:
	return {"success": false, "consumed": false}

func place_in_world(actor: Node3D) -> bool:
	if actor is RalphController and not actor.inventory.allow_world_placement: return false
	var spot = actor.global_position + actor.item_facing() * 1.2
	var query = PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot - Vector3.UP * 5.0)
	query.exclude = [actor.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["normal"].y < 0.5:
		return false
	deactivate()
	holder = null
	global_position = hit["position"]
	if preserve_source_pivot and visual:
		global_position.y -= visual.mesh.get_aabb().position.y
	rotation = Vector3.ZERO
	available = true
	deployed = true
	show()
	hint.visible = false
	if owning_inventory:
		owning_inventory.state.remove(item_id)
	placed.emit(global_position)
	return true

func _physics_process(delta: float) -> void:
	if class_id in [2,3,39] and follows_ground_support() and not has_node("MovingSupport"):
		add_child(preload("res://scripts/items/original_moving_support.gd").new())
	if is_instance_valid(holder):
		_update_held_position()
	item_step(delta)

func follows_ground_support() -> bool:
	return deployed and available and not is_instance_valid(holder)

func _update_held_position() -> void:
	# Hand attachment follows the evaluated original skeleton, independent of level.
	if not is_instance_valid(holder):
		return
	global_position = holder.item_hand_position()
	look_at(global_position + holder.item_facing(), Vector3.UP, true)

func item_step(_delta: float) -> void:
	pass

func play_item_sound(path: String, loop: bool = false) -> void:
	if not sound or not ResourceLoader.exists(path):
		return
	if sound.playing:
		return
	var stream = load(path)
	if loop and stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	sound.stream = stream
	sound.play()

func reload_localization():
	if definition.has("label"): item_label = GameLocalization.ui(str(definition.label))
