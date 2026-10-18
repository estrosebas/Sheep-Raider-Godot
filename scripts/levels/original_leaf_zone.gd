extends Node3D
# HeapOfLeaf54 is invisible logic, despite referencing a sheep dummy model.
# Leaf191 is the separate animated environmental leaf; both use source records.
var definition: Dictionary
var sounds: Dictionary = {}
var player: RalphController
var visual: OriginalCinematicActor
var emitter: OriginalSpriteEmitter
var sound: AudioStreamPlayer3D
var polygon = PackedVector2Array()
var guardian: Node
var rng = RandomNumberGenerator.new()
var home = Vector3.ZERO
var grounded = false
var timer = 0.0
var clip_time = 0.0
var animating = false
var noise_count = 0
var positions: Dictionary = {}

func _ready():
	player = get_parent().get_node("Player"); rng.randomize()
	if int(definition.class_id)==191:
		visual = load(definition.directory+"/worn.tscn").instantiate(); add_child(visual)
		visual.hide()
		call_deferred("ground_ambient_leaf")
	else:
		for point in definition.polygon: polygon.append(Vector2(float(point[0])*.01,-float(point[2])*.01))
		emitter = OriginalSpriteEmitter.new(); add_child(emitter)
		emitter.world_space = true
		emitter.life = .5; emitter.period = 819.0/4096; emitter.rise_speed = -.2; emitter.spread = .1
		emitter.size_start = .4; emitter.size_end = .9
		emitter.configure(definition.get("leaf_frames",[]),16)
		sound = AudioStreamPlayer3D.new(); add_child(sound); sound.max_distance = 35
		if sounds.has("129"): sound.stream = load(sounds["129"])
		add_to_group("noisy_leaf_zones")
	player.respawned.connect(reset_to_home)

func ground_ambient_leaf():
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*3,global_position+Vector3.DOWN*30,1)
	var excluded: Array[RID] = [player.get_rid()]
	for actor in get_tree().get_nodes_in_group("grounded_npcs"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	query.exclude = excluded
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): global_position.y = hit.position.y
	home = global_position; grounded = true
	timer = rng.randf_range(float(definition.respawn_min),float(definition.respawn_max))
	start_leaf()

func start_leaf():
	global_position = home+Vector3(rng.randf_range(-float(definition.range),float(definition.range)),0,rng.randf_range(-float(definition.range),float(definition.range)))
	rotation.y = rng.randf_range(0,TAU)
	clip_time = 0; animating = true; visual.show(); visual.sample_animation("fly",0)

func _physics_process(_delta: float):
	if int(definition.class_id)==191: return
	emitter.emitting = false
	if player.cinematic_controls_locked: return
	var candidates: Array = [player]
	candidates.append_array(get_tree().get_nodes_in_group("sheep_targets"))
	candidates.append_array(get_tree().get_nodes_in_group("bulls"))
	for actor in candidates:
		if not is_instance_valid(actor) or actor.get_parent()!=get_parent(): continue
		var key = actor.get_instance_id()
		var previous: Vector3 = positions.get(key,actor.global_position)
		positions[key] = actor.global_position
		var moving: bool = actor.global_position.distance_squared_to(previous)>.000001
		if actor.has_method("query_moved"): moving = actor.query_moved()
		if not moving: continue
		if actor is OriginalSheep and (actor.dead or is_instance_valid(actor.carried_by)): continue
		if not OriginalSam.contains(actor.global_position,definition.zone,false): continue
		var relative: Vector3 = actor.global_position-global_position
		if absf(relative.x)+absf(relative.z)>=float(definition.radius) or absf(relative.y)>=float(definition.height_tolerance): continue
		if not Geometry2D.is_point_in_polygon(Vector2(actor.global_position.x,actor.global_position.z),polygon): continue
		emitter.global_position = actor.global_position+Vector3.UP
		emitter.emitting = true; noise_count += 1
		if sound.stream and not sound.playing: sound.play()
		if not is_instance_valid(guardian):
			for candidate in get_parent().get_children():
				if int(candidate.get_meta("original_resource",-1))==int(definition.guardian): guardian = candidate; break
		if is_instance_valid(guardian) and guardian.has_method("wake_from_noise"): guardian.wake_from_noise()
		return

func _process(delta: float):
	if int(definition.class_id)==191:
		if not grounded: return
		if animating:
			clip_time += delta; visual.sample_animation("fly",clip_time)
			if clip_time>=float(visual.rig.animations.fly.duration):
				animating = false; visual.hide()
				timer = rng.randf_range(float(definition.respawn_min),float(definition.respawn_max))
		else:
			timer -= delta
			if timer<=0: start_leaf()
	else:
		# Emitter_UpdateDriftAnimated advances through the actual four DAV
		# frames across each particle's lifetime, rather than random confetti.
		for particle in emitter.particles:
			if particle.age>=emitter.life or emitter.frames.is_empty(): continue
			particle.sprite.texture = emitter.frames[mini(emitter.frames.size()-1,int(particle.age/emitter.life*emitter.frames.size()))]

func reset_to_home():
	positions.clear()
	if int(definition.class_id)==191:
		if grounded: start_leaf()
	else:
		emitter.clear(); sound.stop()
