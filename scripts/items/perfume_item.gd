extends "res://scripts/items/game_item.gd"
class_name PerfumeItem

func _init() -> void:
	class_id = 39

var blow_time = 0.0
var blow_heading = Vector3.FORWARD
var blown = false
var wind_this_frame = false
var actor_visual: OriginalCinematicActor
var scent: Node3D
var last_report: Dictionary = {}
var report_age = 1.0

func _ready() -> void:
	super._ready()
	visual.hide()
	actor_visual = load("res://assets/items/perfume/worn.tscn").instantiate()
	add_child(actor_visual)
	actor_visual.sample_animation("objet",0)
	scent = preload("res://scripts/effects/original_perfume_scent.gd").new()
	add_child(scent)
	add_to_group("fan_targets")
	add_to_group("sheep_attractors")

func use_item(actor: Node3D) -> Dictionary:
	if actor is RalphController:
		if not actor.is_on_floor() or not actor.inventory.allow_world_placement: return {"success":false}
		return {"success":actor.item_actions.begin([
			{"clip":"throw_place","exit":func():
				var point = OriginalPlacement.probe(actor,self,true)
				if point.is_empty():
					actor.item_actions.stages[actor.item_actions.index+1] = {"clip":"placement_refused"}; return
				deactivate(); holder = null; global_position = point.position; rotation = Vector3.ZERO
				OriginalPlacement.follow_support(self,point)
				available = true; deployed = true; active = true; show()
				actor.inventory.state.remove(item_id)
				actor_visual.sample_animation("objet",0)
				placed.emit(global_position)},
			{"clip":"throw_end"}]),"consumed":false}
	var success = place_in_world(actor)
	if success:
		active = true
		activated.emit(actor)
	return {"success": success, "consumed": false}

func on_fan_blow(direction: Vector3, _delta: float) -> void:
	if active and deployed:
		wind_this_frame = true
		blown = true
		blow_heading = direction.normalized()

func item_step(delta: float) -> void:
	report_age += delta
	if active and deployed:
		# Query active fans here as well: sibling physics order must not
		# alternate/cancel wind, or leave the particle flag permanently false.
		blown = false
		for fan in get_tree().get_nodes_in_group("fan_sources"):
			if fan.active and is_instance_valid(fan.holder) and ItemRules.in_fan_cone(fan.holder.global_position,fan.holder.item_facing(),global_position): on_fan_blow(fan.holder.item_facing(),delta)
		wind_this_frame = blown
		blow_time = ItemRules.perfume_blow_step(blow_time, blown, delta)

func scent_position() -> Vector3:
	# Sheep walks to the bottle; the wind extends the detection corridor.
	return global_position

func scent_strength() -> float:
	return ItemRules.perfume_distance(blow_time)+.9 if active and deployed else 0.0

func can_smell_from(point: Vector3) -> bool:
	if not active or not deployed: return false
	var difference = point-global_position
	difference.y = 0
	var heading = Vector3(blow_heading.x,0,blow_heading.z).normalized()
	# Flock_AddScentSource adds 90; TestScentSource accepts +/-1024 and
	# at most 200 lateral units. Original distance ignores height.
	return difference.length() <= scent_strength() and difference.dot(heading) >= 0 and absf(difference.cross(heading).y) <= 2.0

func report_sheep(sheep: Node3D):
	var difference = sheep.global_position-global_position; difference.y = 0
	var proximity = clampi(int(difference.length()*65535/maxf(scent_strength(),.001)),0,65535)
	if last_report.is_empty() or proximity <= int(last_report.value) or report_age >= .5:
		last_report = {"sheep":true,"value":proximity}; report_age = 0

func detection_report() -> Dictionary:
	return last_report if active and deployed and report_age <= .5 else {}

func deactivate() -> void:
	blow_time = 0.0
	blown = false
	wind_this_frame = false
	last_report = {}; report_age = 1
	super.deactivate()
	if scent: scent.clear()

func equip_to(actor: Node3D):
	super.equip_to(actor)
	actor_visual.sample_animation("link" if actor_visual.rig.animations.has("link") else "objet",0)

func _update_held_position():
	if holder is RalphController:
		global_transform = holder.skeleton.global_transform*holder.legacy_skin.last_matrices[18]
		global_basis *= GameSpace.EXPORT_TO_GODOT
	else: super._update_held_position()
