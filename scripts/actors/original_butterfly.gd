extends Node3D

# Native Butterfly: local orbit arcs, vertical wandering and authored departure.
enum State { LEAVE, FLUTTER }
var definition: Dictionary
var configuration: Dictionary
var player: Node3D
var visual: OriginalCinematicActor
var state = State.LEAVE
var elapsed = 0.0
var appear_delay = 0
var zone_index = -1
var appear_position = Vector3.ZERO
var orbit_centre = Vector3.ZERO
var orbit_radius = Vector3.ZERO
var orbit_angle = 0.0
var orbit_direction = 1.0
var target_height = 0.0
var clip = ""

static func install(level: Node3D,path: String) -> void:
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for record in data.butterflies:
		var butterfly = new()
		butterfly.definition = record
		butterfly.configuration = data
		butterfly.player = level.player
		butterfly.name = "Butterfly_%d"%int(record.res)
		level.add_child(butterfly)

func _ready() -> void:
	add_to_group("ambient_butterflies")
	visual = load(definition.directory+"/worn.tscn").instantiate()
	add_child(visual)
	visual.set_process(false)
	rotation.y = PI
	leave()
	visual.hide()

func contains(point: Vector3,zone: Dictionary) -> bool:
	var lo = GameSpace.original_point(Vector3(zone.min[0],zone.max[1],zone.max[2]))
	var hi = GameSpace.original_point(Vector3(zone.max[0],zone.min[1],zone.min[2]))
	return point.x>=lo.x and point.x<=hi.x and point.z>=lo.z and point.z<=hi.z

func leave() -> void:
	state = State.LEAVE
	elapsed = 0
	clip = ["fly1","fly2","fly1a"][int(definition.variant)]
	visual.sample_animation(clip,0)

func start_arc(reverse: bool = false) -> void:
	if not contains(global_position,definition.zones[zone_index]):
		leave()
		return
	state = State.FLUTTER
	clip = "fly1" if int(definition.variant)==2 else "fly"
	# APAPIL02 has only its FLY1 clip in this PC bank.
	if not visual.rig.animations.has(clip): clip = "fly1"
	if reverse:
		orbit_centre = global_position*2-orbit_centre
		orbit_direction *= -1
	orbit_radius = global_position-orbit_centre
	orbit_angle = 0
	elapsed = 0
	appear_delay = 0

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	elapsed += delta
	if state == State.LEAVE:
		if elapsed >= float(visual.rig.animations[clip].duration):
			visual.hide()
			for index in range(definition.zones.size()):
				var zone: Dictionary = definition.zones[index]
				if not contains(player.global_position,zone): continue
				zone_index = index
				appear_position = GameSpace.original_point((Vector3(zone.min[0],zone.min[1],zone.min[2])+Vector3(zone.max[0],zone.max[1],zone.max[2]))*.5)
				global_position = appear_position
				orbit_centre = appear_position+Vector3.RIGHT*float(configuration.radius_m)
				rotation.y = PI
				orbit_direction = 1
				target_height = appear_position.y
				if appear_delay >= int(configuration.appearance_frames):
					visual.show()
					start_arc()
				else: appear_delay += 1
				break
	else:
		var angular_step = orbit_direction*float(configuration.angular_speed)*delta
		orbit_angle += angular_step
		if absf(orbit_angle) >= float(configuration.quarter_turn_units)*TAU/4096:
			start_arc(randi_range(0,1)==1)
		else:
			if absf(target_height-global_position.y)<.2:
				target_height = randf_range(appear_position.y,appear_position.y+float(configuration.vertical_range_m))
			var offset = orbit_radius.rotated(Vector3.UP,-orbit_angle)
			global_position = Vector3(orbit_centre.x+offset.x,move_toward(global_position.y,target_height,float(configuration.vertical_speed)*delta),orbit_centre.z+offset.z)
			rotation.y -= angular_step
	visual.sample_animation(clip,elapsed,state==State.FLUTTER)
