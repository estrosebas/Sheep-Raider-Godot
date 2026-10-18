extends "res://scripts/items/game_item.gd"
class_name GhostCostumeItem

func _init() -> void:
	class_id = 125

func equip_to(actor: Node3D) -> void:
	holder = actor
	available = false
	hide()
	actor.set_item_costume("ghost", self)

func use_item(actor: Node3D) -> Dictionary:
	if actor.costume_visual:
		actor.costume_visual.perform_action()
	for ghost in get_tree().get_nodes_in_group("ghost_targets"):
		if ghost is Node3D and ghost.has_method("on_ghost_boo"):
			var delta = ghost.global_position - actor.global_position
			if absf(delta.y) <= 2.0 and Vector2(delta.x, delta.z).length() <= ItemRules.GHOST_BOO_RADIUS:
				ghost.on_ghost_boo(actor)
	play_item_sound("res://assets/items/audio/ghost_boo.wav")
	activated.emit(actor)
	return {"success": true, "consumed": false}

func deactivate() -> void:
	if is_instance_valid(holder) and holder.costume_item == self:
		holder.set_item_costume("", null)
	super.deactivate()
