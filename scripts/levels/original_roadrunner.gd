extends Node3D
class_name OriginalRoadrunner

enum State { WAIT, ROAD, TUNNEL }
var definition: Dictionary
var player: RalphController
var actor: OriginalCinematicActor
var dust: RalphRunDust
var shadow: MeshInstance3D
var road = OriginalPathFollower.new()
var wall = OriginalPathFollower.new()
var state = State.WAIT
var runs_started = 0

func _ready() -> void:
	actor = load("res://assets/cinematics/tutorial_intro/bipbip/worn.tscn").instantiate()
	add_child(actor)
	actor.idle("run1") # Resource 55 starts with mapped animation 0, not CIN 1's BIPBIP.
	dust = RalphRunDust.new()
	dust.capacity = 16 # bipbip::PostLoadInit, same life/size/drift as the shared dust.
	add_child(dust)
	shadow = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = .2
	mesh.bottom_radius = .2
	mesh.height = .001
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0,0,0,.3)
	mesh.material = material
	shadow.mesh = mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	player.respawned.connect(reset)
	reset()

func reset() -> void:
	state = State.WAIT
	road.start(definition["road"],definition["speed_one"])
	actor.position = GameSpace.original_point(road.position)
	actor.hide()
	shadow.hide()
	dust.clear()
	_set_tunnel(false)

func _physics_process(delta: float) -> void:
	if player.cinematic_controls_locked or player.tutorial_movement_locked: return
	advance(delta)

func advance(delta: float) -> void:
	if state == State.WAIT:
		dust.update_dust(delta,false,actor.global_position,Vector3.ZERO,1,1)
		if TutorialProgress.contains(definition["trigger"],player.global_position):
			state = State.ROAD
			runs_started += 1
			actor.show()
			shadow.show()
			dust.clear()
		return
	# Original dtMs is capped to roughly 41 ms; keep the same path stepping.
	var milliseconds = clampi(roundi(delta*1000),0,41)
	var was_tunnel = state == State.TUNNEL
	var result = road.step(milliseconds)
	if was_tunnel:
		wall.step(milliseconds)
	elif result == OriginalPathFollower.Result.NEXT_SEGMENT:
		road.speed = roundi(float(definition["speed_two"])*100)
		if road.to_index >= road.points.size()-1:
			state = State.TUNNEL
			shadow.hide()
			wall.start(definition["wall"],definition["speed_two"])
			wall.rate = road.rate
	actor.position = GameSpace.original_point(road.position)
	actor.rotation.y = road.heading
	shadow.position = actor.position+Vector3.UP*.005
	var facing = Vector3(sin(road.heading),0,cos(road.heading))
	dust.update_dust(delta,not was_tunnel,actor.global_position,facing,1,1)
	if was_tunnel and result == OriginalPathFollower.Result.END: reset()

func _process(_delta: float) -> void:
	_set_tunnel(state == State.TUNNEL)
	if state != State.TUNNEL: return
	var camera = get_viewport().get_camera_3d()
	if camera == null: return
	var view = camera.global_transform.affine_inverse()
	var farthest_z = 0.0
	# bipbip::Render puts the farthest transformed vertex at the wall point's depth.
	for surface in actor.rig["surfaces"].values():
		for i in range(surface["verts"].size()):
			var v = surface["verts"][i]
			var bone = int(surface["bones"][i])
			var palette = actor.legacy_skin.last_matrices[bone]*actor.legacy_skin.inverse_rests[bone]
			var vertex = view*actor.skeleton.global_transform*palette*Vector3(v[0],v[1],v[2])
			farthest_z = minf(farthest_z,vertex.z)
	for material in actor.legacy_skin.materials:
		material.set_shader_parameter("tunnel_road_point",actor.global_position)
		material.set_shader_parameter("tunnel_wall_point",global_transform*GameSpace.original_point(wall.position))
		material.set_shader_parameter("tunnel_farthest_view_z",farthest_z)

func _set_tunnel(enabled: bool) -> void:
	for material in actor.legacy_skin.materials:
		material.set_shader_parameter("tunnel_projection",enabled)
