extends "res://scripts/items/game_item.gd"
class_name RocketItem

func _init() -> void:
	class_id = 10

@export var fuel_seconds = 300.0
@export_file("*.tscn") var original_scene = "res://assets/items/rocket/worn.tscn"
@export var durability = 2.0
@export var maximum_speed = 12.0
var fuel = 0.0
var health = 0.0
var flight_time = 0.0
var heading = 0.0
var flight_speed = 0.0
var flight_actor: CharacterBody3D
var start_played = false
var mount_remaining = 0.0
var rocket_visual: OriginalCinematicActor
var flight_bounds: AABB
var has_flight_bounds = false
const TURN_LIMIT = TAU*1024/4096.0
const TURN_ACCELERATION = TAU*2048/4096.0
var turn_rate = 0.0
var spent = false
var disposal_time = 0.0
var crash_sound_played = false

func _ready() -> void:
	super._ready()
	fuel = fuel_seconds
	health = durability
	# The shared static preview remains useful for icons; gameplay uses AFUSEE01.
	rocket_visual = load(original_scene).instantiate()
	add_child(rocket_visual)
	visual.hide()
	rocket_visual.idle("stand")
	process_priority = 110

func _process(delta: float) -> void:
	if is_instance_valid(holder): _update_held_position()
	if spent: step_disposal(delta)

func use_item(actor: Node3D) -> Dictionary:
	if active:
		finish_flight()
		return {"success": true, "consumed": true}
	if spent or fuel <= 0.0 or health <= 0.0 or not actor is CharacterBody3D:
		return {"success": false}
	if has_flight_bounds and not contains_flight_point(actor.global_position): return {"success":false}
	flight_actor = actor
	active = true
	flight_time = 0.0
	flight_speed = 0.0
	turn_rate = 0.0
	var direction = actor.item_facing()
	heading = atan2(direction.x, direction.z)
	actor.active_rocket = self
	start_played = false
	actor.stop_loop_sfx()
	mount_remaining = actor.animation_player.get_animation("rocket_mount").length if actor.is_on_floor() else 0.0
	actor.play_anim("rocket_mount" if mount_remaining > 0 else "rocket_ignite")
	rocket_visual.idle("rocket0" if mount_remaining > 0 else "rocket2")
	activated.emit(actor)
	return {"success": true, "consumed": false}

func flight_step(delta: float, input: Vector2, boosted: bool) -> void:
	if not active or not is_instance_valid(flight_actor):
		return
	if mount_remaining > 0:
		mount_remaining = maxf(0,mount_remaining-delta)
		flight_actor.velocity = Vector3.ZERO
		if mount_remaining == 0:
			flight_actor.play_anim("rocket_ignite")
			rocket_visual.idle("rocket2")
		return
	flight_time += delta
	if flight_time >= ItemRules.ROCKET_LAUNCH_TIME and flight_actor.animation_player.current_animation != "rocket_ride":
		flight_actor.play_anim("rocket_ride")
		rocket_visual.idle("rocket3")
	if not start_played:
		play_item_sound("res://assets/items/audio/rocket_start.wav")
		start_played = true
	elif not sound.playing:
		play_item_sound("res://assets/items/audio/rocket_loop.wav", true)
	# Only vertical steering is inverted. Keep the port's normal A/D direction.
	# Normal-ground movement profile 9: 1024 angle units/s, acceleration 2048.
	# The bank follows angular velocity, so reversing the stick passes through zero.
	var wanted_turn = -signf(input.x)*TURN_LIMIT if absf(input.x) > .01 else 0.0
	turn_rate = move_toward(turn_rate,wanted_turn,TURN_ACCELERATION*delta)
	heading += turn_rate * delta
	flight_speed = move_toward(flight_speed, maximum_speed if boosted or flight_time < ItemRules.ROCKET_LAUNCH_TIME else maximum_speed * 0.5, (24.0 if boosted else 12.0) * delta)
	var velocity = Vector3(sin(heading) * flight_speed, flight_actor.velocity.y, cos(heading) * flight_speed)
	if flight_time < ItemRules.ROCKET_LAUNCH_TIME:
		velocity.y = ItemRules.rocket_launch_velocity(flight_time)
	else:
		velocity.y = move_toward(velocity.y, input.y * maximum_speed, 12.0 * delta)
	fuel = ItemRules.rocket_fuel_step(fuel, boosted, delta)
	if sound:
		sound.pitch_scale = move_toward(sound.pitch_scale, 2.0 if boosted else 1.0, delta * 0.5)
	flight_actor.velocity = velocity
	if has_flight_bounds and delta > 0:
		# Wolf::ClampDeltaToBox(FLYBOX, step, 7), before resolving world collision.
		var target = (flight_actor.global_position+velocity*delta).clamp(flight_bounds.position,flight_bounds.end)
		flight_actor.velocity = (target-flight_actor.global_position)/delta
	if flight_actor.skeleton:
		# Wolf::RocketFlyStep: pitch from vertical/horizontal velocity,
		# bank = -moveDirAngVel/2. Convert the original Y/Z axes once.
		var pitch = 0.0 if flight_time < ItemRules.ROCKET_LAUNCH_TIME else -atan2(velocity.y,flight_speed)
		flight_actor.skeleton.rotation = Vector3(pitch,heading,-turn_rate*0.5)
	flight_actor.move_and_slide()
	for index in range(flight_actor.get_slide_collision_count()):
		var collision = flight_actor.get_slide_collision(index)
		var impact = maxf(0.0, -velocity.dot(collision.get_normal()))
		if impact > 0.5:
			health = maxf(0.0, health - impact * delta)
	if fuel <= 0.0 or health <= 0.0:
		finish_flight()

func _update_held_position() -> void:
	if is_instance_valid(holder): global_transform = attachment_transform(holder)

func attachment_transform(actor: RalphController) -> Transform3D:
	# Wolf::EquipItem passes joint 3. Rocket::MSG_PICKUP adds {0,10,20}.
	var joint: Transform3D = actor.skeleton.global_transform*actor.legacy_skin.last_matrices[3]
	# last_matrices maps EXPORTED local coordinates into the native world.
	# Converting the local offset to native as well inverted Z a second time.
	return Transform3D(joint.basis*GameSpace.EXPORT_TO_GODOT,joint*Vector3(0,-0.1,0.2))

func contains_flight_point(point: Vector3) -> bool:
	return point.x >= flight_bounds.position.x and point.x <= flight_bounds.end.x and point.y >= flight_bounds.position.y and point.y <= flight_bounds.end.y and point.z >= flight_bounds.position.z and point.z <= flight_bounds.end.z

func finish_flight() -> void:
	if not active: return
	var actor = flight_actor
	flight_actor = null
	super.deactivate()
	if is_instance_valid(actor):
		actor.skeleton.rotation.x = 0
		actor.skeleton.rotation.z = 0
		actor.active_rocket = null
		actor.set_state(actor.WolfState.FALL)
		# Wolf removes the rocket then sends MSG_DROP(placed=1): CRASH1.
		holder = null
		global_position = actor.global_position
		global_basis = Basis.from_euler(Vector3(PI/2,heading,0))
		spent = true
		available = false
		deployed = true
		disposal_time = 0.0
		crash_sound_played = false
		rocket_visual.idle_clip = ""
		rocket_visual.sample_animation("crash1",0)
		show()
		if owning_inventory: owning_inventory.state.remove(item_id)

func step_disposal(delta: float) -> void:
	disposal_time += delta
	var duration = float(rocket_visual.rig["animations"]["crash1"]["duration"])
	if disposal_time < duration:
		rocket_visual.sample_animation("crash1",disposal_time)
	else: hide()
	if disposal_time >= .05 and not crash_sound_played:
		play_item_sound("res://assets/items/audio/rocket_crash.wav")
		crash_sound_played = true
	# Rocket::Update waits 0x3000 ticks after CRASH1, then returns home.
	if disposal_time >= duration+3.0: restore()

func deactivate() -> void:
	if active:
		finish_flight()
	else:
		super.deactivate()

func restore() -> void:
	super.restore()
	spent = false
	disposal_time = 0.0
	rotation = Vector3.ZERO
	if rocket_visual: rocket_visual.idle("stand")
	fuel = fuel_seconds
	health = durability

func store() -> void:
	# Rocket::MSG_INVENTORY_STORED calls Reset, refilling fuel and durability.
	super.store()
	fuel = fuel_seconds
	health = durability
