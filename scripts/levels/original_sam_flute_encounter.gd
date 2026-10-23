extends Node
# Sam::SAM_STT_CIN01 consumes the flute, plays CIN2, then follows its trajectory.
var definition: Dictionary
var sam: OriginalSam
var level: ImportedLevel
var director
var phase_two = false
var pending = false
func _ready():
	level = get_parent(); director = level.get_node("LevelCinematics")
	for actor in level.get_children():
		if actor is OriginalSam and int(actor.get_meta("original_resource",-1))==int(definition.guard): sam = actor
	sam.flute_cinematic_requested.connect(func(): pending = true)
	director.movies[int(definition.cine_id)].finished.connect(finished)
	level.player.respawned.connect(func(): if phase_two: call_deferred("consume_flute"))
	add_to_group("checkpoint_controllers")
func consume_flute():
	var inventory = level.player.inventory
	for identity in inventory.state.items.keys():
		if int(inventory.state.items[identity].class_id)==41:
			if inventory.pickup_nodes.has(identity): inventory.pickup_nodes[identity].store()
			inventory.state.remove(identity)
func _process(_delta):
	if not pending or phase_two or level.player.cinematic_controls_locked or director.active_movie: return
	# Store before start_sequence hides live actors, so no flute remains on Ralph.
	consume_flute()
	if director.start_movie(int(definition.cine_id)): pending = false
func finished(_skipped):
	phase_two = true; apply_phase()
func apply_phase():
	var points: Array[Vector3] = []
	for point in definition.patrol: points.append(GameSpace.original_point(Vector3(point[0],point[1],point[2])))
	sam.configure_patrol(points,float(definition.patrol_speed))
	for entry in definition.staged_mines:
		for mine in get_tree().get_nodes_in_group("defusable_mines"):
			if mine.get_parent()==level and int(mine.get_meta("original_resource"))==int(entry.resource): mine.deploy_at(GameSpace.original_point(Vector3(entry.position[0],entry.position[1],entry.position[2])))
func capture_world_state(): return {"phase_two":phase_two}
func restore_world_state(record: Dictionary):
	phase_two = bool(record.get("phase_two",false)); pending = false
	if phase_two: apply_phase(); consume_flute()
