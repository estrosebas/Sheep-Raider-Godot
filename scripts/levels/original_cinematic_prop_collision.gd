extends Node
# MiscStatic boxes are world-aligned, but their position must follow CIN tracks.
# Keep collision with the live prop (or its movie duplicate during playback),
# and persist moved scenery together with the checkpoint.
var actor: Node3D
var body: StaticBody3D
var director: Node
var tracks: Array = []
func _ready():
	process_physics_priority = -40
	add_to_group("checkpoint_controllers")
	director.progress_restored.connect(restore_played_pose)
	sync_position()
func _physics_process(_delta): sync_position()
func sync_position():
	for entry in tracks:
		if entry.movie.playing:
			body.global_position = entry.movie.actors[entry.key].global_position
			return
	body.global_position = actor.global_position
func capture_world_state():
	return {"position":SaveFiles.vector(actor.global_position),"rotation":SaveFiles.vector(actor.rotation),"visible":actor.visible}
func restore_world_state(record: Dictionary):
	if SaveFiles.valid_vector(record.get("position")): actor.global_position = SaveFiles.to_vector(record.position)
	if SaveFiles.valid_vector(record.get("rotation")): actor.rotation = SaveFiles.to_vector(record.rotation)
	actor.visible = bool(record.get("visible",true)); sync_position()
func restore_played_pose():
	# Also repair older saves which predate scenery-transform snapshots.
	for entry in tracks:
		if not entry.movie.played: continue
		for track in entry.movie.data.tracks:
			if "%d:%d"%[int(track.selector),int(track.index)]!=entry.key: continue
			for record in track.records:
				var keys: Array = record.get("keys",[])
				if keys.is_empty(): continue
				var value = keys[-1].value
				if int(record.opcode)==1: actor.global_position = GameSpace.original_point(Vector3(value[0],value[1],value[2]))
				elif int(record.opcode)==2: actor.rotation = Vector3(value[0],-value[1],-value[2])*TAU/4096
	sync_position()
static func install(level: ImportedLevel,director_node: Node):
	var solids = level.get_node_or_null("OriginalObjectCollisions")
	if not solids: return
	for node in level.get_children():
		if not node is Node3D or node.get_meta("original_class","")!="MiscStatic": continue
		var links: Array = []
		for movie in director_node.movies.values():
			for key in movie.world_actors:
				if movie.world_actors[key]==node: links.append({"movie":movie,"key":key})
		if links.is_empty(): continue
		for solid in solids.get_children():
			if solid.get_meta("original_resource",-1)!=node.get_meta("original_resource"): continue
			var follower = load("res://scripts/levels/original_cinematic_prop_collision.gd").new()
			follower.name = "CinematicPropCollision_%d"%int(node.get_meta("original_resource"))
			follower.actor = node; follower.body = solid; follower.director = director_node; follower.tracks = links
			level.add_child(follower)
