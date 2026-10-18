extends Node
# Entry sequencing is separate from death/respawn and from resource loading.
# Level01: CIN00 camera -> CIN04 Lucas -> outward iris -> gameplay.
var stage = "waiting"
var player: RalphController
var lessons: Node
var plan: Dictionary

func begin():
	if stage!="waiting": return
	player = get_parent().get_node_or_null("Player")
	if not player: stage = "done"; return
	plan = OriginalCameraCatalog.entry_for(get_parent().get("asset_directory") if get_parent().get("asset_directory")!=null else "")
	lessons = get_parent().get_node_or_null(plan.get("director","DaffyLessons"))
	var first = find_movie(plan.get("first",""))
	var last = find_movie(plan.get("last",""))
	if first and last and not lessons.intro_finished and not last.played:
		stage = "cinematic"
		player.restart_fade_remaining = 0
		player.restart_fade.set_iris(false); player.restart_fade.set_amount(0)
		last.finished.connect(_intro_finished,CONNECT_ONE_SHOT)
		# Select the first cinematic camera before the loading overlay disappears:
		# never reveal Ralph's gameplay camera for a frame at this point.
		if lessons.active_movie==null: lessons.start_movie(int(first.camera_descriptor.cine_id))
	else: open_iris()

func find_movie(identity: String):
	var descriptor = OriginalCameraCatalog.named(identity)
	if descriptor.is_empty() or not lessons: return null
	for movie in lessons.movies.values():
		if movie.sequence_path==descriptor.source: return movie
	return null

func _intro_finished(_skipped: bool):
	if stage=="cinematic": stage = "iris" if player.restart_fade_remaining>0 else "done"

func open_iris():
	stage = "iris"
	OriginalCameraCatalog.apply_return(player,"iris")

func _process(_delta: float):
	if stage=="iris" and is_instance_valid(player) and player.restart_fade_remaining<=0: stage = "done"
