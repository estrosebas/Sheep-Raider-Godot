extends CharacterBody3D
class_name SheepItemReceiver

# Item-response adapter. Full Flock/Sam/navigation logic remains separate.
@export var movement_speed = 1.5
var call_actor: Node3D
var call_time = 0.0
var attraction_target: Node3D

func _ready() -> void:
	add_to_group("sheep_targets")

func on_sheep_call(actor: Node3D) -> void:
	call_actor = actor
	call_time = 4.0

func _physics_process(delta: float) -> void:
	call_time = maxf(0.0, call_time - delta)
	var destination = global_position
	var attractor: Node3D
	var best = INF
	for candidate in get_tree().get_nodes_in_group("sheep_attractors"):
		if not candidate.has_method("scent_strength") or candidate.scent_strength() <= 0.0:
			continue
		var distance = global_position.distance_to(candidate.scent_position())
		if candidate is PerfumeItem:
			if not candidate.can_smell_from(global_position): continue
			var offset = candidate.scent_position()-global_position
			distance = Vector2(offset.x,offset.z).length()
		if candidate is LettuceItem:
			var offset: Vector3 = candidate.scent_position()-global_position
			if absf(offset.y) > 1.5: continue
			distance = Vector2(offset.x,offset.z).length()
		if distance < candidate.scent_strength() and distance < best:
			best = distance
			attractor = candidate
	attraction_target = attractor
	if attractor:
		destination = attractor.scent_position()
	elif call_time > 0.0 and is_instance_valid(call_actor):
		destination = call_actor.global_position
	var direction = destination - global_position
	direction.y = 0.0
	var stop_distance = 1.2 if is_instance_valid(attractor) and attractor.is_in_group("bushes") else .55
	if direction.length() > stop_distance:
		direction = direction.normalized()
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
		rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if attractor and attractor.has_method("eat"):
			attractor.eat(delta)
	velocity.y = move_toward(velocity.y, -20.0, 29.0 * delta) if not is_on_floor() else 0.0
	move_and_slide()
