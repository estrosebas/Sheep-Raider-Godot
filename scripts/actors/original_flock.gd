extends Node
class_name OriginalFlock
var sheep: Array[OriginalSheep] = []
var guard: OriginalSam
var outside_sheep: OriginalSheep
var reservations: Dictionary = {}
var idle_variant_owner: OriginalSheep

func _ready() -> void:
	guard = get_tree().get_first_node_in_group("sam_guards")
	for actor in get_tree().get_nodes_in_group("sheep_targets"):
		if actor is OriginalSheep and actor.get_parent() == get_parent():
			sheep.append(actor)
			actor.flock = self
			actor.movement_speed = 2.5 # Sheep::MoveToward: 250 source units/s.
			actor.idle_animation = "stand1" if OriginalSam.contains(actor.global_position,guard.rules["orange"]) else "stand3"
			actor.begin_random_idle(true)
			# ThinkThisFrame staggers sheep by index within each game-second.
			actor.button_think_timer = float(sheep.size()-1)/60.0

func restricted(actor: OriginalSheep) -> bool:
	return is_instance_valid(outside_sheep) and outside_sheep != actor and OriginalSam.contains(actor.global_position,guard.rules["orange"])

func _physics_process(_delta: float) -> void:
	for actor in sheep:
		actor.button_think_timer -= _delta
		actor.button_think_due = actor.button_think_timer <= 0
		if actor.button_think_due: actor.button_think_timer += 1.0
	outside_sheep = null
	for actor in sheep:
		# The distant scripted sheep is outside the flock from the outset.
		if not OriginalSam.contains(actor.home,guard.rules["orange"]): continue
		if actor.carried_by or not OriginalSam.contains(actor.global_position,guard.rules["orange"]):
			outside_sheep = actor
			break
	reservations.clear()
	# SHSF_KEEPS_RESERVATION: keep an approach/eat target until consumed.
	# Reassigning every frame can restart SMEL1 forever when two sheep compete.
	for actor in sheep:
		var target = actor.flock_target
		if actor.carried_by or actor.dead or actor.sleepy or not actor.seesaw_arc.is_empty() or restricted(actor): continue
		if is_instance_valid(target) and target.has_method("scent_strength") and target.scent_strength() > 0 and not reservations.has(target):
			if target is OriginalPressureButton and actor.button_think_due: continue # Reconsider food before keeping the button.
			var difference: Vector3 = target.scent_position()-actor.global_position
			if target is PerfumeItem:
				if target.can_smell_from(actor.global_position): reservations[target] = actor
				continue
			# A chain target can be 6m from lastFoodPos plus the .9m eating offset.
			var radius = target.scent_strength() if target.is_in_group("bushes") else (6.0 if target is OriginalPressureButton else 6.9)
			if absf(difference.y) <= 1.5 and Vector2(difference.x,difference.z).length() <= radius:
				reservations[target] = actor
	var candidates: Array[Dictionary] = []
	for attractor in get_tree().get_nodes_in_group("sheep_attractors"):
		if reservations.has(attractor) or not attractor.has_method("scent_strength") or attractor.scent_strength() <= 0: continue
		for actor in sheep:
			if actor.carried_by or actor.dead or actor.sleepy or not actor.seesaw_arc.is_empty() or restricted(actor) or reservations.values().has(actor): continue
			if attractor is OriginalPressureButton and not actor.button_think_due: continue
			if attractor is OriginalPressureButton and actor.flock_target is OriginalPressureButton and attractor != actor.flock_target: continue
			var p: Vector3 = attractor.scent_position()
			if attractor is PerfumeItem:
				if attractor.can_smell_from(actor.global_position):
					var offset = p-actor.global_position
					candidates.append({"actor":actor,"target":attractor,"distance":Vector2(offset.x,offset.z).length()})
				continue
			# FindNearestAttractor(1) searches around lastFoodPos after eating.
			var origin: Vector3 = actor.last_food_position if actor.last_food_position != null and not attractor is OriginalPressureButton and not attractor.is_in_group("bushes") else actor.global_position
			if absf(p.y-origin.y) > 1.5: continue
			var distance = Vector2(origin.x-p.x,origin.z-p.z).length()
			if distance <= attractor.scent_strength():
				candidates.append({"actor":actor,"target":attractor,"distance":distance,"score":distance*distance+(72 if attractor is OriginalPressureButton else 0)})
	candidates.sort_custom(func(a,b): return a.get("score",a.distance*a.distance) < b.get("score",b.distance*b.distance))
	for candidate in candidates:
		if not reservations.has(candidate.target) and not reservations.values().has(candidate.actor):
			reservations[candidate.target] = candidate.actor

func attraction(actor: OriginalSheep) -> Node3D:
	var nearest: Node3D
	var best = INF
	for attractor in reservations:
		if reservations[attractor] != actor: continue
		var point: Vector3 = attractor.scent_position()
		var distance = Vector2(actor.global_position.x-point.x,actor.global_position.z-point.z).length()
		if distance < best:
			best = distance
			nearest = attractor
	return nearest

func claim_idle_variant(actor: OriginalSheep) -> bool:
	# Port presentation rule: one ambient STAND4/BAH at once per flock.
	if is_instance_valid(idle_variant_owner):
		var owner = idle_variant_owner
		if not owner.dead and not owner.carried_by and not owner.sleepy and owner.flock_phase == "idle" and owner.visual.idle_clip in ["stand4","bah"]:
			return owner == actor
	idle_variant_owner = actor
	return true

func release_idle_variant(actor: OriginalSheep):
	if idle_variant_owner == actor: idle_variant_owner = null
