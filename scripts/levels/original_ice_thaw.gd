extends Node3D
# IceCube::Update: one accumulated second of THAW; FOND1 pauses without heat,
# then finishes freely and leaves FLAC1. Keep the native world-aligned box.
var visual: OriginalCinematicActor
var body: StaticBody3D
var shape: CollisionShape3D
var original_size: Vector3
var original_center: Vector3
var heat_time = 0.0
var animation_time = 0.0
var pending_heat = 0.0
var melted = false
var duration = 4.5
signal thawed

func configure(actor: OriginalCinematicActor,solid: StaticBody3D):
	visual = actor; body = solid; shape = body.get_child(0)
	original_size = shape.shape.size; original_center = shape.position
	# Never mutate the shared imported shape resource.
	shape.shape = shape.shape.duplicate()
	top_level = true
	global_position = visual.global_position
	visual.idle_clip = ""; visual.set_process(false)
	duration = float(visual.rig.animations.fond1.duration)
	add_to_group("thaw_targets")
	reset_frozen()

func on_heat(delta: float): pending_heat = maxf(pending_heat,delta)

func _physics_process(delta: float):
	if not visual: return
	if melted:
		animation_time = minf(duration,animation_time+delta)
	elif pending_heat > 0:
		heat_time += pending_heat
		animation_time += pending_heat
		if heat_time >= 1:
			melted = true
			shape.set_deferred("disabled",true)
			thawed.emit()
	pending_heat = 0
	if heat_time > 0 or melted:
		visual.sample_animation("flac1" if animation_time >= duration else "fond1",animation_time)
		# Shrink only the top, keeping the base fixed, until the prisoner is free.
		var height = maxf(.02,original_size.y*(1-clampf(heat_time,0,1)))
		shape.shape.size.y = height
		shape.position.y = original_center.y-(original_size.y-height)/2

func reset_frozen():
	heat_time = 0; animation_time = 0; pending_heat = 0; melted = false
	shape.set_deferred("disabled",false)
	shape.shape.size = original_size; shape.position = original_center
	visual.sample_animation("stand2",0)

func capture_state() -> Dictionary:
	return {"melted":melted}

func restore_state(saved: Dictionary):
	reset_frozen()
	if saved.get("melted",false):
		melted = true; heat_time = 1; animation_time = duration
		shape.set_deferred("disabled",true)
		visual.sample_animation("flac1",0)
