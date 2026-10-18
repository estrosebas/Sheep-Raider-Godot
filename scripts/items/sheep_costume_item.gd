extends "res://scripts/items/game_item.gd"
class_name SheepCostumeItem

func _init() -> void:
	class_id = 80

func equip_to(actor: Node3D) -> void:
	holder = actor
	available = false
	hide()
	actor.set_item_costume("sheep", self)

func use_item(actor: Node3D) -> Dictionary:
	if actor.costume_visual:
		actor.costume_visual.perform_action()
	play_item_sound("res://assets/items/audio/sheep_bleat.wav")
	for sheep in get_tree().get_nodes_in_group("sheep_targets"):
		if sheep is Node3D and sheep.has_method("on_sheep_call"):
			var delta = sheep.global_position - actor.global_position
			if absf(delta.y) <= 1.5 and Vector2(delta.x, delta.z).length() <= ItemRules.SHEEP_CALL_RADIUS:
				sheep.on_sheep_call(actor)
	activated.emit(actor)
	return {"success": true, "consumed": false}

func deactivate() -> void:
	if is_instance_valid(holder) and holder.costume_item == self:
		holder.set_item_costume("", null)
	super.deactivate()
