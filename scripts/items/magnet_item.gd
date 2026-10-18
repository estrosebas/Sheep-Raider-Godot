extends "res://scripts/items/game_item.gd"
class_name MagnetItem

func _init() -> void:
	class_id = 66

@export var attraction_radius = 4.0
var caught: Array[Node3D] = []

func equip_to(actor: Node3D) -> void:
	super.equip_to(actor)
	active = true
	activated.emit(actor)

func use_item(actor: Node3D) -> Dictionary:
	return {"success": place_in_world(actor), "consumed": false}

func item_step(delta: float) -> void:
	if not active or not is_instance_valid(holder):
		return
	var next: Array[Node3D] = []
	for target in get_tree().get_nodes_in_group("magnetic_targets"):
		if not target is Node3D or not target.has_method("magnet_query"):
			continue
		var distance = target.global_position.distance_to(global_position)
		if distance > attraction_radius or not target.magnet_query(self) or next.size() >= ItemRules.MAGNET_MAX_TARGETS:
			continue
		if not target.has_method("magnet_pull"):
			continue
		next.append(target)
		target.magnet_pull(self, ItemRules.magnet_strength(distance), delta)
		if distance <= 0.65 and target.has_method("magnet_contact"):
			target.magnet_contact(self)
		if next.size() == 1 and target.has_method("magnet_is_anchored") and target.magnet_is_anchored():
			holder.apply_item_pull(target.global_position, ItemRules.magnet_strength(distance), delta)
	for target in caught:
		if is_instance_valid(target) and target not in next and target.has_method("magnet_release"):
			target.magnet_release(self)
	caught = next
	if not caught.is_empty():
		play_item_sound("res://assets/items/audio/magnet_hum.wav", true)
	else:
		sound.stop()

func deactivate() -> void:
	for target in caught:
		if is_instance_valid(target) and target.has_method("magnet_release"):
			target.magnet_release(self)
	caught.clear()
	super.deactivate()
