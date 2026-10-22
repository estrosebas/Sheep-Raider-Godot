extends Node3D
# Wolf's CLIMBBOXES are world regions; scenery already contains the vines.
var definition: Dictionary = {}
var rules: Dictionary = {}
var bounds: AABB
var source_level = "lvl_05"
var heading = 0.0
var wall_direction = Vector3.FORWARD
var wall_right = Vector3.RIGHT

static func install(level: Node3D,path: String):
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for record in data.get("zones",[]):
		var zone = load("res://scripts/levels/original_climb_zone.gd").new()
		zone.name = "ClimbZone_%d"%int(record.index)
		zone.definition = record; zone.rules = data
		zone.source_level = level.manifest.level
		level.add_child(zone)

func _ready():
	var lo = definition.min; var hi = definition.max
	var minimum = GameSpace.original_point(Vector3(lo[0],hi[1],hi[2]))
	var maximum = GameSpace.original_point(Vector3(hi[0],lo[1],lo[2]))
	bounds = AABB(minimum,maximum-minimum)
	heading = float(definition.heading)*TAU/4096
	wall_direction = Vector3(-sin(heading),0,cos(heading))
	wall_right = Vector3(-cos(heading),0,-sin(heading))
	position = bounds.get_center()
	add_to_group("climb_zones"); add_to_group("world_interactables")

func contains(point: Vector3,tolerance: float = .02) -> bool:
	return bounds.grow(tolerance).has_point(point)

func can_interact(actor: RalphController) -> bool:
	if actor.climb_motion.zone==self: return true
	# CLIMBBOXWALK is a separate native mechanic, not a vertical wall climb.
	if definition.get("walkable",false): return false
	if actor.climb_motion.active() or not actor.can_use_inventory(): return false
	if is_instance_valid(actor.carried_sheep) or is_instance_valid(actor.active_rocket) or is_instance_valid(actor.active_bush): return false
	if actor.item_actions.busy or actor.current_state==actor.WolfState.SWIM: return false
	return contains(actor.global_position)

func interact(actor: RalphController) -> bool:
	if actor.climb_motion.zone==self:
		actor.climb_motion.release(actor,false); return true
	return actor.climb_motion.begin(actor,self) if can_interact(actor) else false

func action_label(actor: RalphController) -> String:
	return GameLocalization.text(source_level,0,0x3f if actor.climb_motion.zone==self else 0x35)
