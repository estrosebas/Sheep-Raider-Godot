extends OriginalNpcConversation
class_name OriginalLevel01Porky
var director: OriginalLevel01Daffy
var without_sheep_played = false
var with_sheep_played = false
var salads: Array[LettuceItem] = []
var show_active = false
var revealed: Dictionary = {}
var show_index = 0
var show_delay = 0.0
var cinematic_sheep: OriginalSheep
var sheep_before_lesson = Transform3D.IDENTITY
@export var talk_radius = 1.0
@export var lesson_radius = 2.0

func can_interact(actor: RalphController) -> bool:
	if not super.can_interact(actor): return false
	var difference = actor.global_position-daffy.global_position
	return Vector2(difference.x,difference.z).length() <= talk_radius and absf(difference.y) <= .8

func _ready() -> void:
	data_path = "res://assets/levels/lvl_01/data/porky.json"
	actor_prefix = "PorkyLevel01"
	super._ready()
	director = get_parent().get_node("DaffyLessons")
	for child in get_parent().get_children():
		if child is LettuceItem:
			salads.append(child)
			child.available = false
			child.hide()
	for identity in [int(data["cine_without"]),int(data["cine_with"])]:
		director.movies[identity].finished.connect(_lesson_finished.bind(identity))

func nearby_sheep() -> OriginalSheep:
	var best = 2.0
	var nearest: OriginalSheep
	for sheep in get_tree().get_nodes_in_group("sheep_targets"):
		if not sheep is OriginalSheep or sheep.get_parent() != get_parent(): continue
		var difference: Vector3 = sheep.goal_position()-player.global_position
		var distance = Vector2(difference.x,difference.z).length()
		if distance <= best:
			best = distance
			nearest = sheep
	return nearest

func try_lesson() -> void:
	if with_sheep_played or speaking or menu.visible or active_movie or director.active_movie or player.cinematic_controls_locked or not player.can_use_item(): return
	if not OriginalSam.contains(player.global_position,data["activation"],false): return
	if Vector2(player.global_position.x-daffy.global_position.x,player.global_position.z-daffy.global_position.z).length() > lesson_radius: return
	var sheep = nearby_sheep()
	var identity = int(data["cine_with"]) if sheep else int(data["cine_without"])
	if not sheep and without_sheep_played: return
	if sheep:
		cinematic_sheep = sheep
		if is_instance_valid(sheep.carried_by): sheep.drop()
		sheep_before_lesson = sheep.global_transform
		# CIN03's Sheep actor is the nearby sheep passed MSG_CINE_PLACE.
		director.movies[identity].world_actors["2:59"] = sheep
	if not director.start_movie(identity): return
	active_movie = director.movies[identity]
	if sheep:
		with_sheep_played = true
		show_active = true
		show_index = 0
		show_delay = float(data["salad_delay_ms"])/1000
	else: without_sheep_played = true

func _process(delta: float) -> void:
	super._process(delta)
	try_lesson()
	if show_active and active_movie and active_movie.playing:
		show_delay -= delta
		if show_delay <= 0:
			if show_index < salads.size(): show_salad(show_index)
			show_index += 1
			show_delay = .5
			show_active = show_index < salads.size()

func show_salad(index: int) -> void:
	if revealed.has(index): return
	var salad = salads[index]
	if is_instance_valid(salad.holder): return
	salad.reveal_from_lesson()
	revealed[index] = true

func _lesson_finished(_skipped: bool, identity: int) -> void:
	if active_movie != director.movies[identity]: return
	active_movie = null
	if identity == int(data["cine_with"]):
		for i in range(salads.size()): show_salad(i)
		show_active = false
	if is_instance_valid(cinematic_sheep):
		# The scripted demonstration travels away from the farm. Keep the real
		# stolen sheep at the lesson entrance when its cinematic proxy finishes.
		cinematic_sheep.global_transform = sheep_before_lesson
		cinematic_sheep.global_position = player.respawn_ground_position(cinematic_sheep.global_position)+Vector3.UP*.001
		cinematic_sheep.velocity = Vector3.ZERO
		cinematic_sheep.flock_target = null
		cinematic_sheep.flock_phase = "idle"
		cinematic_sheep.flock_timer = 0
		cinematic_sheep.show()
		cinematic_sheep.visual.idle(cinematic_sheep.idle_animation)
	cinematic_sheep = null

func reset_burnt() -> void:
	# Porky::Reset clears tint but keeps lesson progression and burnt-line flags.
	OriginalBurntTint.apply(daffy.legacy_skin,false)
