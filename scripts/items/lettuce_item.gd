extends "res://scripts/items/game_item.gd"
class_name LettuceItem

func _init() -> void:
	class_id = 3

@export_file("*.tscn") var original_scene = ""
var original_visual: OriginalCinematicActor
var appear_time = -1.0
var eat_time = 0.0
var respawn_time = 0.0
var eating_frame = false
var ground_visual_offset = 0.0

func use_item(actor: Node3D) -> Dictionary:
	if not actor is RalphController: return {"success":place_in_world(actor),"consumed":false}
	if not actor.is_on_floor() or not actor.inventory.allow_world_placement: return {"success":false}
	return {"success":actor.item_actions.begin([
		{"clip":"throw_place","exit":func():
			var placement = OriginalPlacement.probe(actor,self,true)
			if placement.is_empty():
				actor.item_actions.stages[actor.item_actions.index+1] = {"clip":"placement_refused"}
				return
			deactivate()
			holder = null
			global_position = placement.position
			OriginalPlacement.follow_support(self,placement)
			rotation = Vector3.ZERO
			available = true
			deployed = true
			show()
			if original_visual:
				original_visual.idle("objet")
				original_visual.sample_animation("objet",0)
			actor.inventory.state.remove(item_id)
			placed.emit(global_position)},
		{"clip":"throw_end"}]),"consumed":false}

func scent_position() -> Vector3:
	return global_position

func attachment_transform(actor: RalphController) -> Transform3D:
	# Salad::MSG_PICKUP attaches LINK to Wolf's hand joint0x12 with no offset.
	var transform = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[18]
	transform.basis *= GameSpace.EXPORT_TO_GODOT
	return transform

func _update_held_position():
	if holder is RalphController: global_transform = attachment_transform(holder)
	else: super._update_held_position()

func prepare_held_visual():
	if original_visual:
		original_visual.position.y = 0
		original_visual.sample_animation("link",0)

func equip_to(actor: Node3D):
	prepare_held_visual()
	super.equip_to(actor)

func scent_strength() -> float:
	return ItemRules.LETTUCE_RADIUS if available and respawn_time <= 0.0 else 0.0

func eat(delta: float) -> bool:
	if not available or is_instance_valid(holder) or respawn_time > 0.0:
		return false
	eating_frame = true
	eat_time += delta
	if eat_time >= ItemRules.LETTUCE_EAT_TIME:
		available = false
		respawn_time = ItemRules.LETTUCE_RESPAWN_TIME
		eat_time = 0.0
		hide()
	return true

func _ready() -> void:
	super._ready()
	add_to_group("sheep_attractors")
	if not original_scene.is_empty():
		visual.hide()
		original_visual = load(original_scene).instantiate()
		add_child(original_visual)
		original_visual.idle("objet")
		original_visual.sample_animation("objet",0)
		# Salad::PostLoadInit/Reset use OBJET; STAND is a different tilted pose.
		# Ground their evaluated pose, rather than the unanimated mesh bounds.
		var lowest = INF
		for surface in original_visual.rig["surfaces"].values():
			for i in range(surface["verts"].size()):
				var vertex = surface["verts"][i]
				var point = Vector3(vertex[0],vertex[1],vertex[2])
				var joint = int(surface["bones"][i])
				point = original_visual.legacy_skin.last_matrices[joint]*original_visual.legacy_skin.inverse_rests[joint]*point
				lowest = minf(lowest,point.y)
		ground_visual_offset = -lowest
		original_visual.position.y = ground_visual_offset
		call_deferred("_ground_original_plant")

func _ground_original_plant() -> void:
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.5,global_position-Vector3.UP*2)
	query.collision_mask = 1
	var excluded: Array[RID] = []
	for actor in get_tree().get_nodes_in_group("player")+get_tree().get_nodes_in_group("grounded_npcs"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	query.exclude = excluded
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y+.005
	home_position = global_position

func item_step(delta: float) -> void:
	if original_visual:
		original_visual.position.y = 0 if is_instance_valid(holder) or deployed else ground_visual_offset
		if appear_time < 0:
			var idle = ("link" if original_visual.rig.animations.has("link") else "objet") if is_instance_valid(holder) else "objet"
			if original_visual.idle_clip != idle: original_visual.idle(idle)
	if appear_time >= 0 and original_visual:
		appear_time += delta
		original_visual.sample_animation("appear",appear_time)
		if appear_time >= float(original_visual.rig["animations"]["appear"]["duration"]):
			appear_time = -1
			original_visual.idle("objet")
	if respawn_time > 0.0:
		respawn_time = maxf(0.0, respawn_time - delta)
		if respawn_time == 0.0:
			global_position = home_position
			available = true
			show()
	# Original eatTime accumulates MSG_USE calls while the sheep eats.
	eating_frame = false

func restore() -> void:
	eat_time = 0.0
	respawn_time = 0.0
	super.restore()

func reveal_from_lesson() -> void:
	available = true
	show()
	if original_visual and original_visual.rig["animations"].has("appear"):
		appear_time = 0
		original_visual.idle_clip = ""
		original_visual.sample_animation("appear",0)
