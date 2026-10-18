extends Node
# Shared river hazards and original seesaw adapter. All regions/rigs come from WAR.
var level: ImportedLevel
var player: RalphController
var rules: Dictionary
var data: Dictionary
var seesaw: OriginalSeesaw
var seesaws: Array[OriginalSeesaw] = []
var fish: Array = []
var attack: Dictionary = {}
var arc: Dictionary = {}
var rng = RandomNumberGenerator.new()
var launch_camera: Node3D
var launch_support: OriginalSeesaw

func _ready():
	level = get_parent(); player = level.player; rng.randomize()
	add_to_group("water_regions")
	rules = JSON.parse_string(FileAccess.get_file_as_string(level.asset_directory+"/data/environment.json"))
	data = {"sounds":{"264":level.asset_directory+"/audio/264.wav"}}
	var boards = rules.get("seesaws",[])
	if boards.is_empty() and rules.has("seesaw"): boards = [rules.seesaw]
	for definition in boards:
		var old = level.get_node_or_null("seesaw_%d"%int(definition.res))
		if old: old.queue_free()
		var board = OriginalSeesaw.new(); board.definition = definition
		board.name = "OriginalSeesaw" if seesaws.is_empty() else "OriginalSeesaw_%d"%int(definition.res)
		level.add_child(board); seesaws.append(board)
		board.position = GameSpace.from_export(Vector3(definition.pos[0],definition.pos[1],definition.pos[2]))
	if not seesaws.is_empty(): seesaw = seesaws[0]
	for entity in level.entities:
		if int(entity.class_id) != 117: continue
		var visual: OriginalCinematicActor = level.get_node("Piranhas_%d"%int(entity.res))
		var zone = water_at(visual.global_position)
		if zone.is_empty(): continue
		visual.global_position.y = -float(zone.min[1])*.01
		visual.idle("pirana2")
		var record = {"visual":visual,"zone":zone,"target":visual.global_position,"leaping":false,"time":0.0}
		fish.append(record); pick_target(record,false)
	# The imported atlas is scoped by full path, so Ralph/shared props stay intact.
	if FileAccess.file_exists(level.asset_directory+"/data/texture_scroll.json"):
		var scroll = OriginalTextureScroll.new(); scroll.name = "TextureScroll"; level.add_child(scroll)
	player.respawned.connect(reset)
	for cue in player.run_data.animations.piranha_death.sound_cues:
		var id = str(int(cue.sound_id)); var path = level.asset_directory+"/audio/"+id+".wav"
		if ResourceLoader.exists(path): player.run_data.sounds[id] = {"path":path,"loop":false}

func water_at(point: Vector3) -> Dictionary:
	for zone in rules.water:
		if OriginalSam.contains(point,[zone]): return zone
	return {}

func over_water(point: Vector3) -> bool:
	for zone in rules.water:
		var a = zone.min; var b = zone.max
		if point.x >= a[0]*.01 and point.x <= b[0]*.01 and point.z >= -b[2]*.01 and point.z <= -a[2]*.01 and point.y >= -b[1]*.01: return true
	return false

func pick_target(record: Dictionary,allow_leap: bool = true):
	var zone = record.zone; var a = zone.min; var b = zone.max
	record.start = record.visual.global_position
	for attempt in range(30):
		record.target = GameSpace.original_point(Vector3(rng.randf_range(a[0],b[0]),a[1]+rng.randf_range(200,400),rng.randf_range(a[2],b[2])))
		if Vector2(record.target.x-record.start.x,record.target.z-record.start.z).length_squared() >= 50: break
	record.time = 0.0; record.leaping = allow_leap and rng.randi_range(0,2) == 2
	record.points = [record.start,record.target]
	if record.leaping:
		# Native four-point path: skim five metres just below the surface.
		# PIRANA3 supplies the visible leap; adding a world-space arc doubles it.
		var distance: float = record.start.distance_to(record.target)
		var skim = maxf(0,(distance-5)/2)
		var direction: Vector3 = (record.target-record.start).normalized()
		var first: Vector3 = record.start+direction*skim
		var second: Vector3 = record.start+direction*(skim+5)
		first.y = -float(zone.min[1])*.01-.5; second.y = first.y
		record.points = [record.start,first,second,record.target]
	record.duration = 0.0
	for i in range(1,record.points.size()):
		record.duration += record.points[i-1].distance_to(record.points[i])/5.0
	record.visual.idle("pirana2")

func swim_step(record: Dictionary,delta: float):
	record.time += delta
	var remaining: float = record.time*5.0 # TrajFollower native speed 500.
	for i in range(1,record.points.size()):
		var start: Vector3 = record.points[i-1]; var end: Vector3 = record.points[i]
		var distance = start.distance_to(end)
		if remaining > distance and i < record.points.size()-1:
			remaining -= distance; continue
		var visual = record.visual
		visual.global_position = start.lerp(end,minf(remaining/maxf(distance,.001),1))
		var clip = "pirana3" if record.leaping and i == 2 else "pirana2"
		if visual.idle_clip != clip: visual.idle(clip)
		var direction = end-start
		visual.rotation.y = atan2(direction.x,direction.z)
		break
	if record.time >= record.duration: pick_target(record)

func player_launching() -> bool: return not arc.is_empty()
func start_launch_camera(camera: Dictionary,no_freeze: bool):
	if is_instance_valid(launch_camera): return
	launch_camera = preload("res://scripts/cinematics/original_launch_camera.gd").new()
	launch_camera.definition = camera; launch_camera.player = player; launch_camera.no_freeze = no_freeze
	add_child(launch_camera)
func launch(actor: Node3D,points: Array,rock_impact: bool = true):
	if actor is OriginalSheep:
		actor.launch_from_seesaw(seesaw,points,rock_impact); return
	if actor.is_in_group("pushable_rocks"):
		actor.launch(points); return
	if actor != player or not arc.is_empty(): return
	player.interrupt_actions(); player.tutorial_movement_locked = true; player.play_anim("jump")
	player.seesaw_launching = true
	if is_instance_valid(launch_camera): launch_camera.following_player_launch = true
	# The native plank's custom collision lets riders leave its upper face.
	# Godot's solid box can otherwise trap Ralph during its tilt reversal.
	# Use the same takeoff exception already used by OriginalSheep.
	for board in seesaws:
		if board.contact_ids.has(player.get_instance_id()):
			launch_support = board
			player.add_collision_exception_with(board)
			break
	arc = {"time":0.0,"start":player.global_position,"middle":OriginalSeesaw.source_point(points[1]),"end":OriginalSeesaw.source_point(points[2])}

func release_launch_support():
	if is_instance_valid(launch_support): player.remove_collision_exception_with(launch_support)
	launch_support = null

func clear_player_launch():
	arc.clear(); release_launch_support()
	player.seesaw_launching = false
	player.tutorial_movement_locked = false

func _physics_process(delta: float):
	if not arc.is_empty() and not player.seesaw_launching: clear_player_launch()
	if not arc.is_empty():
		if is_instance_valid(launch_support) and player.global_position.y>launch_support.surface_height(player.global_position)+.5:
			release_launch_support()
		arc.time += delta
		var target = OriginalSeesaw.arc_point(arc.start,arc.middle,arc.end,minf(arc.time/1.024,1))
		var motion = target-player.global_position
		var contact = player.move_and_collide(motion)
		if arc.time >= 1.024 or (contact and arc.time > .1 and (motion.y < 0 or absf(contact.get_normal().y)<.5)):
			clear_player_launch(); player.velocity = Vector3.ZERO; player.set_state(player.WolfState.FALL)
	var sheep: Array = []
	for actor in get_tree().get_nodes_in_group("sheep_targets"):
		if actor is OriginalSheep and actor.get_parent()==level: sheep.append(actor)
	for rock in get_tree().get_nodes_in_group("pushable_rocks"):
		if rock.get_parent()==level: sheep.append(rock)
	for box in get_tree().get_nodes_in_group("seesaw_boxes"):
		if box.get_parent()==level: sheep.append(box)
	for board in seesaws: board.step(delta,player,sheep,self)
	for record in fish:
		var visual = record.visual
		if not attack.is_empty() and attack.visual == visual: continue
		swim_step(record,delta)
	if not attack.is_empty():
		attack.time += delta
		if player.water_motion.zone.is_empty(): attack.clear(); return
		if player.water_motion.elapsed >= 1 and not attack.biting:
			attack.biting = true
			attack.bite_time = 0.0
			player.cinematic_controls_locked = false
			player.on_piranha_attack()
			attack.visual.idle_clip = ""
			# Fixed close framing at water entry/death, outside the spring arm.
			var target = player.global_position+Vector3.UP*.6
			player.camera.global_position = clear_death_camera(target)
			player.camera.look_at(target,Vector3.UP)
			player.pit_camera_start = player.camera.quaternion
			player.pit_camera_target = player.camera.quaternion
		if attack.biting:
			var previous_time: float = attack.bite_time
			attack.bite_time += delta
			attack.visual.global_position = player.global_position
			attack.visual.rotation.y = player.skeleton.rotation.y
			attack.visual.sample_animation("pirana1",attack.bite_time)
			for cue in attack.visual.rig.animations.pirana1.sound_cues:
				if float(cue.time)>previous_time and float(cue.time)<=attack.bite_time:
					var path = level.asset_directory+"/audio/%d.wav"%int(cue.sound_id)
					if ResourceLoader.exists(path): player.play_animation_sfx(path)
		return
	if player.cinematic_controls_locked or player.tutorial_movement_locked or player.restart_fade_remaining > 0 or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.BLAST_DEATH,player.WolfState.SAM_DEATH]: return
	var zone = player.water_motion.zone
	if zone.is_empty(): return
	# Wolf enters a water state 50 units below the surface, then Piranhas
	# freezes him for 1000 ms before sending KILL_PIRANHAS.
	if player.global_position.y > -float(zone.min[1])*.01-.5: return
	for record in fish:
		if record.zone != zone: continue
		attack = {"visual":record.visual,"time":0.0,"biting":false}; break
	if is_instance_valid(player.carried_sheep): player.carried_sheep.on_blast(player.global_position)

func reset():
	attack.clear(); clear_player_launch()
	for record in fish: pick_target(record,false)

func clear_death_camera(target: Vector3) -> Vector3:
	var space = level.get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid()]
	for actor in get_tree().get_nodes_in_group("grounded_npcs")+get_tree().get_nodes_in_group("sharks"):
		if actor is CollisionObject3D: excluded.append(actor.get_rid())
	var best = target+Vector3.UP*.5
	var best_distance = -1.0
	for angle in [0.0,PI/4,-PI/4,PI/2,-PI/2,PI,3*PI/4,-3*PI/4]:
		var direction: Vector3 = Basis(Vector3.UP,angle)*(-player.item_facing())
		for elevation in [1.6,.6,2.6]:
			var desired = target+direction*4+Vector3.UP*elevation
			var query = PhysicsRayQueryParameters3D.create(target,desired,3)
			query.exclude = excluded
			var hit = space.intersect_ray(query)
			var point: Vector3 = hit.position-(desired-target).normalized()*.25 if not hit.is_empty() else desired
			var shape_query = PhysicsShapeQueryParameters3D.new()
			var sphere = SphereShape3D.new(); sphere.radius = .2
			shape_query.shape = sphere; shape_query.transform.origin = point
			shape_query.collision_mask = 3; shape_query.exclude = excluded
			if not space.intersect_shape(shape_query,1).is_empty(): continue
			if hit.is_empty(): return desired
			var distance = point.distance_to(target)
			# Prefer a fully visible four-metre shot, then slide toward Ralph
			# on the visible side of the wall instead of leaving the camera behind it.
			if distance>best_distance:
				best = point; best_distance = distance
	return best
