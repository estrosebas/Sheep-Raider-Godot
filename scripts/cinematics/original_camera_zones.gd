extends Node
class_name OriginalCameraZones
# Shared optional camera assists. Movie/dialogue cameras remain independent.
var data: Dictionary
var player: RalphController
var camera_rule = -1
var saved_camera: Dictionary = {}
var camera_from: Dictionary = {}
var camera_target: Dictionary = {}
var camera_blend_time = 0.0
var camera_blend_duration = .9
var camera_returning = false
const CAMERA_ENTER_SECONDS = .9
const CAMERA_EXIT_SECONDS = 1.0

static func install(level: Node3D,directory: String):
	var path = directory+"/data/camera_zones.json"
	if not FileAccess.file_exists(path) or level.has_node("CameraZones"): return
	var controller = load("res://scripts/cinematics/original_camera_zones.gd").new()
	controller.name = "CameraZones"
	controller.data = JSON.parse_string(FileAccess.get_file_as_string(path))
	level.add_child(controller)

func _ready():
	player = get_parent().get_node("Player")
	process_priority = 150
	add_to_group("camera_zone_controllers")
	player.respawned.connect(release_camera)

static func angle_limit(value: float,lo: float,hi: float) -> float:
	if absf(hi-lo)>=359.9: return value
	if is_equal_approx(lo,hi): return deg_to_rad(lo)
	var span = fposmod(hi-lo,360)
	if fposmod(rad_to_deg(value)-lo,360)<=span: return value
	return deg_to_rad(lo if absf(wrapf(rad_to_deg(value)-lo,-180,180))<absf(wrapf(rad_to_deg(value)-hi,-180,180)) else hi)

func camera_snapshot() -> Dictionary:
	return {"rotation":player.camera_pivot.rotation,"length":player.camera_pivot.spring_length,"fov":player.camera.fov,"position":player.camera_pivot.position}

func start_camera_blend(target: Dictionary,returning: bool):
	camera_from = camera_snapshot()
	camera_target = target.duplicate(true)
	camera_blend_time = 0
	camera_returning = returning
	camera_blend_duration = CAMERA_EXIT_SECONDS if returning else CAMERA_ENTER_SECONDS

func blend_camera(delta: float):
	if camera_target.is_empty(): return
	camera_blend_time = minf(camera_blend_time+delta,camera_blend_duration)
	var t = camera_blend_time/camera_blend_duration
	# Smootherstep: zero velocity and acceleration at both ends. Shortest-angle
	# rotation avoids spinning across180 degrees when changing adjacent zones.
	var amount = t*t*t*(t*(t*6-15)+10)
	var start: Vector3 = camera_from.rotation
	var end: Vector3 = camera_target.rotation
	player.camera_pivot.rotation = Vector3(lerp_angle(start.x,end.x,amount),lerp_angle(start.y,end.y,amount),lerp_angle(start.z,end.z,amount))
	player.camera_pivot.position = camera_from.position.lerp(camera_target.position,amount)
	player.camera_pivot.spring_length = lerpf(camera_from.length,camera_target.length,amount)
	player.camera.fov = lerpf(camera_from.fov,camera_target.fov,amount)
	if t>=1:
		camera_target.clear(); camera_from.clear()
		if camera_returning:
			saved_camera.clear(); camera_returning = false

static func closest_path_point(eye: Vector3,points: Array,axis: int = 0) -> Vector3:
	var best = GameSpace.original_point(Vector3(points[0][0],points[0][1],points[0][2]))
	var distance = INF
	for i in range(maxi(1,points.size()-1)):
		var a = GameSpace.original_point(Vector3(points[i][0],points[i][1],points[i][2]))
		var last = mini(i+1,points.size()-1)
		var b = GameSpace.original_point(Vector3(points[last][0],points[last][1],points[last][2]))
		var direction = b-a
		var t = 0.0
		if axis==1 and absf(direction.x)>.001: t = (eye.x-a.x)/direction.x
		elif axis==2 and absf(direction.z)>.001: t = (eye.z-a.z)/direction.z
		elif direction.length_squared()>.001: t = (eye-a).dot(direction)/direction.length_squared()
		var point = a.lerp(b,clampf(t,0,1))
		if eye.distance_squared_to(point)<distance:
			best = point; distance = eye.distance_squared_to(point)
	return best

func desired_camera(rule: Dictionary) -> Dictionary:
	var pivot = player.camera_pivot
	var target = pivot.rotation
	target.x = -angle_limit(-target.x,float(rule.pitch[0]),float(rule.pitch[1]))
	target.y = angle_limit(target.y,float(rule.yaw[0]),float(rule.yaw[1]))
	var position: Vector3 = saved_camera.position
	var offset: Array = rule.get("aim_offset",[0,0,0])
	position += Vector3(offset[0],offset[1],offset[2])
	var length = clampf(pivot.spring_length,float(rule.distance[0]),float(rule.distance[1]))
	var trajectory: Array = rule.get("trajectory",[])
	if not trajectory.is_empty():
		var aim = player.to_global(position)
		var eye = aim+Basis.from_euler(target)*Vector3(0,0,length)
		var axis = 0
		if rule.snap_yaw: axis = 1 if absf(sin(target.y))<.001 else 2
		var fixed_eye = closest_path_point(eye,trajectory,axis)
		var arm = fixed_eye-aim
		length = maxf(.2,arm.length())
		target.x = -atan2(arm.y,Vector2(arm.x,arm.z).length())
		if Vector2(arm.x,arm.z).length()>.01: target.y = atan2(arm.x,arm.z)
	return {"rotation":target,"length":length,"position":position,"fov":rad_to_deg(2*atan(192.0/float(rule.focal))) if float(rule.focal)>0 else saved_camera.fov}

func _process(delta: float):
	if player.cinematic_controls_locked or player.current_state in [player.WolfState.PIT_FALL,player.WolfState.SAM_DEATH,player.WolfState.BLAST_DEATH]: return
	var selected: Dictionary = {}
	# Native update order: the last matching CameraRestriction owns the limits.
	if GameLocalization.camera_assists_enabled():
		for rule in data.cameras:
			if rule.follow and OriginalSam.contains(player.global_position,rule.boxes): selected = rule
	if selected.is_empty():
		if not saved_camera.is_empty() and not camera_returning:
			camera_rule = -1
			start_camera_blend(saved_camera,true)
		blend_camera(delta)
		return
	if saved_camera.is_empty(): saved_camera = camera_snapshot()
	var pivot = player.camera_pivot
	var desired = desired_camera(selected)
	var target: Vector3 = desired.rotation
	if camera_rule!=int(selected.resource) or camera_returning:
		camera_rule = int(selected.resource)
		start_camera_blend(desired,false)
	if not camera_target.is_empty(): blend_camera(delta)
	else:
		# After arrival, respect mouse/touch input inside the original limits;
		# approach an exceeded limit gently rather than snapping back to it.
		var amount = 1-exp(-4*delta)
		pivot.rotation.x = lerp_angle(pivot.rotation.x,target.x,amount)
		pivot.rotation.y = lerp_angle(pivot.rotation.y,target.y,amount)
		pivot.spring_length = lerpf(pivot.spring_length,desired.length,amount)
		pivot.position = pivot.position.lerp(desired.position,amount)

func release_camera():
	# Immediate restoration is reserved for respawn/reset, hidden by its iris.
	if not saved_camera.is_empty():
		player.camera_pivot.rotation = saved_camera.rotation
		player.camera_pivot.position = saved_camera.position
		player.camera_pivot.spring_length = saved_camera.length; player.camera.fov = saved_camera.fov
	saved_camera.clear(); camera_rule = -1; camera_returning = false
	camera_target.clear(); camera_from.clear()

