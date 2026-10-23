extends CharacterBody3D
class_name RalphController

const RunRules = preload("res://scripts/player/ralph_run_rules.gd")
const StepRules = preload("res://scripts/player/ralph_step_rules.gd")
const InventoryComponent = preload("res://scripts/inventory/inventory_component.gd")
const LegacySkin = preload("res://scripts/player/legacy_skin_renderer.gd")
const AirRules = preload("res://scripts/player/ralph_air_rules.gd")
const Dust = preload("res://scripts/player/ralph_run_dust.gd")
signal run_impact(collider: Object, normal: Vector3, point: Vector3, speed: float)
signal run_recovery_started
signal respawned


# Authentic Sheep Raider / Sheep, Dog 'n' Wolf Player Controller
# Ported directly from sdw-decomp src/game/wolf.cpp & wolf_move.cpp
#
# Constants (100 game units = 1.0 meter, SCALE = 0.01):
#   Walk Speed: 6.0 m/s (maxSpeed = 600)
#   Sneak Speed: 2.5 m/s (maxSpeed = 250)
#   Run Speed: 12.0 m/s (maxSpeed = 1200)
#   Jump Height: 2.0 m (params[1] = 0xc8 = 200 units)
#   Jump Duration: 0.312 s (params[2] = 0x4fd = 1277 in 4.12 fixed point, 1277 / 4096 = 0.3118s)
#   Initial Jump Velocity: 2 * 2.0 / 0.3118 = 12.83 m/s
#   Double Jump Height: 1.5 m (params[3] = 0x96 = 150 units, params[4] = 0x4cc = 1228 / 4096 = 0.300s)
#   Falling Gravity: 29.0 m/s^2 (wolf.cpp:4065 tuningRow[8] = 0xb54 = 2900 units/s^2)
#   Terminal Velocity: 20.0 m/s (wolf_move.cpp:289 ApplyGravity terminal = 2000 units/s)

@export var walk_speed: float = 6.0
@export var run_speed: float = 12.0
@export var sneak_speed: float = 2.5
@export var rotation_speed: float = 16.0
@export var mouse_sensitivity: float = 0.003
@export_range(0.5,1.0,0.01) var jump_height_scale = 0.9
@export_range(0.0,0.3,0.01) var coyote_time = 0.18
@export_range(0.1,3.0,0.1) var jump_void_drop_margin = 1.0

# Physics constants from decomp
const JUMP_HEIGHT: float = 2.0
const JUMP_DURATION: float = 0.312
const DOUBLE_JUMP_HEIGHT: float = 1.5
const DOUBLE_JUMP_DURATION: float = 0.300
const FALL_GRAVITY: float = 29.0
const TERMINAL_VELOCITY: float = 20.0

# Node references
@onready var camera_pivot: SpringArm3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var skeleton: Skeleton3D = $Skeleton3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var loop_audio_player: AudioStreamPlayer3D = get_node_or_null("LoopAudioPlayer")

# Authentic SDW states
enum WolfState {
	IDLE,
	WALK,
	SNEAK,
	RUN_START,
	RUN,
	RUN_STOP,
	JUMP,
	FALL,
	LAND,
	RUN_CRASH,
	RUN_RECOVER,
	RUN_AIR,
	PIT_FALL,
	BLAST_DEATH,
	SAM_DEATH,
	SWIM,
	COVER_ENTER,
	COVER_HIDDEN,
	FLUTE_IDLE,
	FLUTE_WALK,
	CLIMB
}

var current_state: WolfState = WolfState.IDLE
var mouse_captured: bool = true
var footstep_timer: float = 0.0
var sneak_step_count: int = 0
var jump_timer: float = 0.0
var current_jump_height: float = JUMP_HEIGHT
var current_jump_duration: float = JUMP_DURATION
var can_double_jump: bool = false
var was_on_floor: bool = true
var sfx_cache: Dictionary = {}
var state_time: float = 0.0
var run_tap_timer: float = 0.0
var run_active: bool = false
var run_direction: Vector3 = Vector3.FORWARD
var run_audio_phase: String = ""
var run_data: Dictionary = {}
var animation_sfx_players: Array[AudioStreamPlayer3D] = []
var reaction_pose_active: bool = false
var inventory_controls_locked = false
var cinematic_controls_locked = false
var launch_controls_locked = false # CamShot's MSG_FREEZE masks input, not physics.
var tutorial_movement_locked = false
var seesaw_launching = false # Native MSG_LAUNCHED: the launch arc owns movement.
var inventory: Node
var item_actions: OriginalItemActions
var sneak_audio_player: AudioStreamPlayer3D
var active_rocket: Node
var carried_sheep: OriginalSheep
var carried_object: Node3D
var catapult_motion_owner: Node3D
var item_pull_velocity = Vector3.ZERO
var item_costume = ""
var costume_item: Node
var costume_visual: Node3D
var legacy_skin: RefCounted
var run_dust: Node3D
var safe_position: Vector3
var safe_camera_rotation: Vector3
var saved_camera_local: Transform3D
var pit_camera_start: Quaternion
var pit_camera_target: Quaternion
var death_camera_parent: Node
var death_animation_override = ""
var crushing_rock: CollisionObject3D
var pit_respawn_count = 0
var checkpoint_facing: Variant = null
var checkpoint_position: Variant = null
var checkpoint_camera_rotation = Vector3.ZERO
var ground_distance = INF
var restart_fade: OriginalRestartFade
var restart_fade_remaining = 0.0
@export_range(0.6,5.0,0.1) var direct_fall_impact_time = 2.0
@export_range(0,25,1) var direct_fall_camera_tilt = 12.0
@export_range(0.2,1.5,0.05) var direct_fall_camera_tilt_time = .8
var pit_is_air_run = false
var direct_fall_impact_played = false
var void_impact_audio: AudioStreamPlayer
var void_impact: OriginalCinematicActor
var floor_probe_warmup = 2
var jump_void_grace = 0.0
var coyote_remaining = 0.0
var jump_origin_y: Variant = null
var last_ground_y = 0.0

func _ready() -> void:
	preload("res://scripts/input/platform_controls.gd").configure()
	add_to_group("player")
	# Run after AnimationPlayer's idle evaluation when applying legacy skin poses.
	process_priority = 100
	restart_fade = OriginalRestartFade.new()
	restart_fade.name = "RestartFade"
	add_child(restart_fade)
	camera_pivot.add_excluded_object(get_rid())
	var camera_guard = SphereShape3D.new()
	camera_guard.radius = 0.2
	camera_pivot.shape = camera_guard
	legacy_skin = LegacySkin.new()
	legacy_skin.setup(skeleton, skeleton.get_node("MeshInstance3D"))
	dizzy_effect = preload("res://scripts/player/original_dizzy_effect.gd").new()
	dizzy_effect.name = "DizzyEffect"
	add_child(dizzy_effect)
	run_dust = Dust.new()
	run_dust.name = "RunDust"
	add_child(run_dust)
	void_impact = preload("res://assets/effects/void_impact/worn.tscn").instantiate()
	void_impact.name = "VoidImpact"
	add_child(void_impact)
	void_impact.top_level = true
	void_impact.hide()
	safe_position = global_position
	last_ground_y = global_position.y
	inventory = InventoryComponent.new()
	inventory.name = "Inventory"
	add_child(inventory)
	item_actions = preload("res://scripts/inventory/original_item_actions.gd").new()
	item_actions.name = "ItemActions"
	add_child(item_actions)
	# Development panel/HUD disabled for normal gameplay (Suprimir).
	# Keep the implementation to re-enable it for future tuning sessions.
	# var elastic_tuning = preload("res://scripts/testing/elastic_tuning_menu.gd").new()
	# elastic_tuning.name = "ElasticTuning"; add_child(elastic_tuning)
	var action_prompt = OriginalActionPrompt.new()
	action_prompt.name = "ActionPrompt"
	add_child(action_prompt)
	sneak_audio_player = AudioStreamPlayer3D.new()
	sneak_audio_player.name = "SneakAudioPlayer"
	sneak_audio_player.volume_db = -2.0
	sneak_audio_player.max_distance = 30.0
	add_child(sneak_audio_player)
	capture_mouse(true)
	run_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_run_data.json"))
	run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_catapult_data.json")),true)
	var sam_attacks = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_sam_attacks.json"))
	run_data.animations.merge(sam_attacks.animations,true)
	run_data.sounds.merge(sam_attacks.sounds,true)
	run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_sneak_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_water_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_water_data.json")),true)
		run_data.sounds.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_water_audio.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_interaction_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_interaction_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_cover_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_cover_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_held_idle_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_held_idle_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_crush_data.json"):
		var crush_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_crush_data.json"))
		run_data.animations.merge(crush_data.animations,true)
		run_data.sounds.merge(crush_data.sounds,true)
	if FileAccess.file_exists("res://assets/models/ralph_elastic_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_elastic_data.json")),true)
	if FileAccess.file_exists("res://assets/models/ralph_flute_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_flute_data.json")),true)
		for cue in run_data.animations.bull_death.sound_cues:
			var path = "res://assets/levels/lvl_04/audio/%d.wav"%int(cue.sound_id)
			if ResourceLoader.exists(path): run_data.sounds[str(int(cue.sound_id))] = {"path":path,"loop":false}
	if FileAccess.file_exists("res://assets/models/ralph_shark_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_shark_data.json")),true)
	if loop_audio_player:
		loop_audio_player.finished.connect(_on_run_sound_finished)
	if FileAccess.file_exists("res://assets/models/ralph_climb_data.json"):
		run_data.animations.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_climb_data.json")),true)
		run_data.sounds.merge(JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/ralph_climb_audio.json")),true)
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if inventory_controls_locked or launch_controls_locked or cinematic_controls_locked or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH] or restart_fade_remaining > 0:
		return
	if event.is_action_pressed("cancel"):
		capture_mouse(not mouse_captured)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Web pointer lock must be requested directly inside a real input event.
		# The browser can release it without changing our desired capture state.
		capture_mouse(true,true)
		get_viewport().set_input_as_handled()
		return
		
	if mouse_captured and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion and camera_pivot:
		rotate_view(event.relative)

func rotate_view(relative: Vector2) -> void:
	# Shared mouse/touch camera limits and cinematic/death locks.
	if not camera_pivot or inventory_controls_locked or launch_controls_locked or cinematic_controls_locked or restart_fade_remaining>0 or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return
	camera_pivot.rotate_y(-relative.x*mouse_sensitivity)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x-relative.y*mouse_sensitivity,deg_to_rad(-75),deg_to_rad(65))

func capture_mouse(capture: bool, from_input: bool = false) -> void:
	mouse_captured = capture
	var touch = get_node_or_null("/root/MobileControls")
	if touch and touch.enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	# _ready(), scene loads and animated menu returns are outside the browser's
	# user gesture. Remember the intent and let the next click acquire the lock.
	if capture and OS.has_feature("web") and not from_input: return
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

var original_idle = preload("res://scripts/player/original_ralph_idle.gd").new()
var dizzy_effect: Node3D
var push_target: CharacterBody3D
var active_bush: Node3D
var elastic_motion_owner: Node3D
var elastic_pull_controller: Node3D
var water_motion = preload("res://scripts/player/original_water_motion.gd").new()
var rock_cover = preload("res://scripts/player/original_rock_cover.gd").new()
var climb_motion = preload("res://scripts/player/original_climb_motion.gd").new()

func _process(delta: float) -> void:
	if is_instance_valid(elastic_pull_controller) or is_instance_valid(elastic_motion_owner):
		apply_legacy_reaction_pose(); return
	if current_state == WolfState.IDLE and not cinematic_controls_locked and not is_instance_valid(push_target) and not is_instance_valid(carried_sheep) and not is_instance_valid(carried_object) and not is_instance_valid(active_rocket):
		var fan_active = inventory.equipped_node is FanItem and inventory.equipped_node.active
		if fan_active:
			apply_legacy_reaction_pose()
			return
		if original_idle.base_clip != original_idle.base_for(self): original_idle.reset(self)
		if not inventory_controls_locked and not tutorial_movement_locked and restart_fade_remaining <= 0:
			original_idle.step(self,delta)
	apply_legacy_reaction_pose()

func apply_legacy_reaction_pose() -> void:
	if legacy_skin:
		legacy_skin.update_pose()
	# Native attached props render after their parent evaluates the hand matrix.
	# Flute must use this displayed pose, not the previous physics-tick hand.
	if inventory and inventory.equipped_node is FluteItem and inventory.equipped_node.holder==self:
		inventory.equipped_node.sync_held_pose()
	if dizzy_effect: dizzy_effect.update_attachment()

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if seesaw_launching or is_instance_valid(elastic_motion_owner) or is_instance_valid(catapult_motion_owner): return
	# One shared floor probe is evaluated even during jump, flight and carry.
	ground_distance = ground_drop()
	floor_probe_warmup = maxi(0,floor_probe_warmup-1)
	if restart_fade_remaining > 0:
		restart_fade_remaining = maxf(0,restart_fade_remaining-delta)
		restart_fade.set_amount(restart_fade_remaining)
		if restart_fade_remaining == 0: restart_fade.set_iris(false)
		velocity = Vector3(0,0 if is_on_floor() else maxf(-TERMINAL_VELOCITY,velocity.y-FALL_GRAVITY*delta),0)
		move_and_slide()
		return
	if cinematic_controls_locked:
		return
	if climb_motion.step(self,delta): return
	if is_instance_valid(elastic_pull_controller):
		elastic_pull_controller.step_pull(self,delta); return
	if water_motion.step(self,delta): return
	if is_instance_valid(active_bush) and active_bush.is_rising():
		# Native WOLF_ST_BUSH_RISE is stationary until HEAD1 completes.
		velocity.x = 0
		velocity.z = 0
		velocity.y = 0 if is_on_floor() else maxf(-TERMINAL_VELOCITY,velocity.y-FALL_GRAVITY*delta)
		move_and_slide()
		return
	if is_instance_valid(push_target):
		push_target.step_pusher(self,delta)
		return
	if inventory.equipped_node is FanItem and inventory.equipped_node.active and is_on_floor():
		var input = Input.get_vector("move_left","move_right","move_forward","move_backward")
		var direction = camera_pivot.global_basis*Vector3(input.x,0,input.y)
		direction.y = 0
		if direction.length_squared() > .01: skeleton.rotation.y = lerp_angle(skeleton.rotation.y,atan2(direction.x,direction.z),minf(1,6*delta))
		var clip = "fan_blow_turn" if direction.length_squared() > .01 else "fan_blow_idle"
		if animation_player.current_animation != clip: play_anim(clip)
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if tutorial_movement_locked:
		velocity.x = 0
		velocity.z = 0
		velocity.y = 0 if is_on_floor() else move_toward(velocity.y,-TERMINAL_VELOCITY,FALL_GRAVITY*delta)
		move_and_slide()
		return
	if inventory.equipped_node is FluteItem and inventory.equipped_node.active:
		if inventory.equipped_node.step_player(self,delta): return
	if is_instance_valid(active_rocket):
		run_dust.update_dust(delta,false,global_position,item_facing(),0,run_speed)
		active_rocket.flight_step(delta, Input.get_vector("move_left", "move_right", "move_forward", "move_backward"), Input.is_action_pressed("run"))
		return
	if is_instance_valid(carried_sheep):
		carried_sheep.move_carrier(delta)
		return
	if is_instance_valid(carried_object):
		carried_object.move_carrier(delta)
		return

	var previous_time = state_time
	state_time += delta
	advance_animation_sound_cues(previous_time, state_time)
	var on_ground = is_on_floor()
	if rock_cover.step(self,delta):
		was_on_floor = is_on_floor()
		check_void_below()
		return
	if on_ground and current_state != WolfState.JUMP:
		coyote_remaining = coyote_time
	else:
		coyote_remaining = maxf(0,coyote_remaining-delta)
	jump_void_grace = maxf(0,jump_void_grace-delta)
	var just_landed = not was_on_floor and on_ground
	if current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]:
		step_pit_fall(delta)
		return
	if current_state == WolfState.RUN_AIR:
		step_air_run(delta)
		return
	# Decide pit death after jump input below: the first apex must leave time
	# to press the second jump, including on the frame that changes to FALL.
	if on_ground and current_state != WolfState.JUMP:
		jump_void_grace = 0
		jump_origin_y = null
		last_ground_y = global_position.y
		if has_safe_footing():
			safe_position = global_position
			safe_camera_rotation = camera_pivot.rotation
	elif current_state in [WolfState.RUN_START,WolfState.RUN]:
		var drop = ground_distance
		if AirRules.can_air_run(run_active,Vector2(velocity.x,velocity.z).length(),drop,walk_speed):
			set_state(WolfState.RUN_AIR)
			step_air_run(delta)
			return

	# 1. Authentic Jump & Gravity Physics
	if on_ground:
		can_double_jump = true
		if velocity.y < 0:
			velocity.y = 0.0
		if just_landed and current_state not in [WolfState.RUN_CRASH, WolfState.RUN_RECOVER, WolfState.RUN_START, WolfState.RUN]:
			set_state(WolfState.LAND)
	else:
		if current_state == WolfState.JUMP:
			jump_timer += delta
			if jump_timer <= current_jump_duration:
				# Exact Wolf_JumpVelocity parabolic derivative:
				# v(t) = (2 * height / duration) * (1 - t / duration)
				var initial_v = (2.0 * current_jump_height) / current_jump_duration
				velocity.y = initial_v * (1.0 - (jump_timer / current_jump_duration))
			else:
				set_state(WolfState.FALL)
		else:
			# Falling: authentic 29.0 m/s^2 gravity, capped at terminal velocity (20.0 m/s)
			velocity.y = move_toward(velocity.y, -TERMINAL_VELOCITY, FALL_GRAVITY * delta)
			if velocity.y < 0.0 and current_state != WolfState.FALL:
				set_state(WolfState.FALL)

	# 2. Authentic Jump & Double-Jump Input (wolf.cpp:1140-1146)
	if not inventory_controls_locked and not launch_controls_locked and Input.is_action_just_pressed("jump") and current_state not in [WolfState.RUN_START, WolfState.RUN, WolfState.RUN_AIR, WolfState.RUN_STOP, WolfState.RUN_CRASH]:
		if (on_ground or coyote_remaining > 0) and current_state != WolfState.JUMP:
			jump_origin_y = global_position.y if on_ground else last_ground_y
			coyote_remaining = 0
			jump_timer = 0.0
			current_jump_height = JUMP_HEIGHT * jump_height_scale
			current_jump_duration = JUMP_DURATION
			velocity.y = (2.0 * current_jump_height) / current_jump_duration
			can_double_jump = not is_instance_valid(active_bush)
			jump_void_grace = JUMP_DURATION+DOUBLE_JUMP_DURATION
			set_state(WolfState.JUMP)
		elif not on_ground and can_double_jump and jump_timer >= (current_jump_duration * 0.25):
			# Authentic double jump
			can_double_jump = false
			coyote_remaining = 0
			jump_timer = 0.0
			current_jump_height = DOUBLE_JUMP_HEIGHT * jump_height_scale
			current_jump_duration = DOUBLE_JUMP_DURATION
			jump_void_grace = DOUBLE_JUMP_DURATION
			velocity.y = (2.0 * current_jump_height) / current_jump_duration
			set_state(WolfState.JUMP)
			play_anim("jump")
			play_sfx("res://assets/audio/sfx/jump.wav", 1.15)

	# 3. Input direction & Camera orientation
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if inventory_controls_locked or launch_controls_locked:
		input_dir = Vector2.ZERO
	var is_moving = input_dir.length_squared() > 0.01

	var cam_basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction = (right * input_dir.x + forward * -input_dir.y).normalized()

	# Run logic is independent of Input/audio via RunRules; Godot supplies edges.
	if current_state in [WolfState.RUN_START, WolfState.RUN]:
		run_tap_timer += delta
		var tap = RunRules.run_tap_check(run_tap_timer, run_active, Input.is_action_just_pressed("run") and not launch_controls_locked)
		run_tap_timer = tap["timer"]
		run_active = tap["active"]
		update_run_sound()

	# 4. Ground state adapter. One-shot states finish their actual animation.
	if on_ground and current_state != WolfState.JUMP:
		match current_state:
			WolfState.RUN_CRASH:
				if state_animation_finished("run_crash"):
					set_state(WolfState.IDLE)
			WolfState.RUN_RECOVER:
				if is_moving:
					set_state(WolfState.WALK)
				elif state_time >= RunRules.RECOVER_IDLE_TIME:
					set_state(WolfState.IDLE)
			WolfState.LAND:
				if state_animation_finished("land") or is_moving:
					set_state(WolfState.IDLE)
			WolfState.RUN_START:
				if state_animation_finished("run_start"):
					set_state(WolfState.RUN if run_active else WolfState.RUN_STOP)
			WolfState.RUN:
				if not run_active and Vector2(velocity.x, velocity.z).length() < walk_speed:
					set_state(WolfState.RUN_STOP)
			WolfState.RUN_STOP:
				if state_animation_finished("run_stop"):
					set_state(WolfState.RUN_RECOVER)
			_:
				if Input.is_action_pressed("sneak"):
					set_state(WolfState.SNEAK)
				elif not is_moving:
					set_state(WolfState.IDLE)
				elif Input.is_action_just_pressed("run") and item_costume.is_empty():
					run_direction = move_direction
					set_state(WolfState.RUN_START)
				else:
					set_state(WolfState.WALK)

	# Native SNEAK_IDLE (STAND11) stays quiet and keeps the sneak flag.
	# Retaining one gameplay state preserves perception/cover and the eight-step
	# sound sequence while switching only its stationary/moving animation.
	if on_ground and current_state==WolfState.SNEAK:
		var sneak_clip = "sneak" if is_moving else "sneak_idle"
		if animation_player.current_animation!=sneak_clip: play_anim(sneak_clip)

	# 5. Apply Horizontal Velocity
	var target_speed = 0.0
	match current_state:
		WolfState.WALK:
			target_speed = walk_speed if item_costume.is_empty() else 2.5
		WolfState.SNEAK:
			target_speed = sneak_speed
		WolfState.RUN_START:
			target_speed = run_speed
		WolfState.RUN:
			target_speed = run_speed
		WolfState.JUMP, WolfState.FALL:
			# JumpAscendStep/FallStep use profile 0 (600 units/s) through
			# Mobile_Steer. Run input never switches an ordinary jump to RUN.
			target_speed = 2.5 if not item_costume.is_empty() else walk_speed

	if current_state in [WolfState.RUN_START, WolfState.RUN, WolfState.RUN_STOP]:
		if is_moving:
			var heading = atan2(run_direction.x, run_direction.z)
			var wanted = atan2(move_direction.x, move_direction.z)
			var turn = clampf(wrapf(wanted - heading, -PI, PI), -RunRules.TURN_SPEED * delta, RunRules.TURN_SPEED * delta)
			run_direction = Vector3(sin(heading + turn), 0, cos(heading + turn))
		var speed = RunRules.run_speed_step(Vector2(velocity.x, velocity.z).length(),
			run_active and current_state != WolfState.RUN_STOP, run_speed, delta)
		velocity.x = run_direction.x * speed
		velocity.z = run_direction.z * speed
		if skeleton:
			skeleton.rotation.y = atan2(run_direction.x, run_direction.z)
	elif current_state in [WolfState.RUN_CRASH, WolfState.RUN_RECOVER]:
		velocity.x = 0.0
		velocity.z = 0.0
	elif is_moving and current_state != WolfState.LAND:
		var accel = 45.0 if on_ground else 25.0
		velocity.x = move_toward(velocity.x, move_direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * target_speed, accel * delta)
		if skeleton:
			var target_angle = atan2(move_direction.x, move_direction.z)
			skeleton.rotation.y = lerp_angle(skeleton.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)

	# 6. Audio Footsteps & Loops
	handle_audio(delta, is_moving, on_ground)

	# 7. Commit movement
	if not item_pull_velocity.is_zero_approx():
		velocity += item_pull_velocity
		velocity.y = maxf(velocity.y, -3.0)
		item_pull_velocity = Vector3.ZERO
	was_on_floor = is_on_floor()
	var elastic_base_velocity = velocity
	var elastic_adjusted = false
	for elastic in get_tree().get_nodes_in_group("elastic_controllers"):
		if elastic.get_world_3d()==get_world_3d(): elastic_adjusted = elastic.modify_move(self,delta) or elastic_adjusted
	if is_instance_valid(elastic_motion_owner): return
	var incoming_velocity = velocity
	move_and_slide()
	if elastic_adjusted:
		# MSG_MODIFY_MOVE changes the displacement, not Wolf's gravity/speed
		# accumulator. Feeding its spring correction back into velocity creates
		# an artificial equilibrium before LONGUEUR_MAX and prevents the yo-yo.
		velocity = elastic_base_velocity
		for index in range(get_slide_collision_count()):
			var normal = get_slide_collision(index).get_normal()
			if velocity.dot(normal)<0: velocity = velocity.slide(normal)
	resolve_run_contacts(incoming_velocity)
	check_void_below()
	run_dust.update_dust(delta,current_state in [WolfState.RUN_START,WolfState.RUN,WolfState.RUN_STOP] and is_on_floor(),global_position,item_facing(),Vector2(velocity.x,velocity.z).length(),run_speed)

func ground_drop() -> float:
	# Start above the feet so a collision recovery that briefly penetrates the
	# ground cannot make a ray starting inside the floor look like a bottomless pit.
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.5,global_position-Vector3.UP*320)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	if is_instance_valid(carried_sheep): query.exclude.append(carried_sheep.get_rid())
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return maxf(0,global_position.y-hit["position"].y) if not hit.is_empty() else INF

func has_safe_footing() -> bool:
	# Do not save a capsule hanging partly over a ledge as the respawn point.
	for offset in [Vector3.ZERO,Vector3.RIGHT*0.45,Vector3.LEFT*0.45,Vector3.FORWARD*0.45,Vector3.BACK*0.45]:
		var origin = global_position+offset
		var query = PhysicsRayQueryParameters3D.create(origin+Vector3.UP*0.2,origin-Vector3.UP*0.3)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit["normal"].y < 0.5:
			return false
	return true

func step_air_run(delta: float) -> void:
	run_tap_timer += delta
	var tap = RunRules.run_tap_check(run_tap_timer,run_active,Input.is_action_just_pressed("run") and not launch_controls_locked)
	run_tap_timer = tap["timer"]
	run_active = tap["active"] and state_time <= AirRules.RUN_AIR_LIMIT
	# Wolf::RUN_AIR clears the run flag/tap timer at timeout, but lets
	# SteerRun brake horizontally before testing the walking-speed threshold.
	if state_time > AirRules.RUN_AIR_LIMIT: run_tap_timer = 0
	var direction = Vector2.ZERO if launch_controls_locked else Input.get_vector("move_left","move_right","move_forward","move_backward")
	if direction.length_squared() > 0.01:
		var basis = camera_pivot.global_basis
		var wanted = basis.x*direction.x+basis.z*direction.y
		var heading = atan2(run_direction.x,run_direction.z)
		var change = clampf(wrapf(atan2(wanted.x,wanted.z)-heading,-PI,PI),-RunRules.TURN_SPEED*delta,RunRules.TURN_SPEED*delta)
		run_direction = Vector3(sin(heading+change),0,cos(heading+change))
	var speed = RunRules.run_speed_step(Vector2(velocity.x,velocity.z).length(),run_active,run_speed,delta)
	velocity = run_direction*speed
	skeleton.rotation.y = atan2(run_direction.x,run_direction.z)
	update_run_sound()
	was_on_floor = is_on_floor()
	move_and_slide()
	run_dust.update_dust(delta,true,global_position,item_facing(),speed,run_speed)
	var drop = ground_drop()
	if is_on_wall():
		set_state(WolfState.FALL)
	elif is_on_floor() or drop <= AirRules.LANDING_DROP:
		set_state(WolfState.RUN)
	elif speed < walk_speed:
		set_state(WolfState.PIT_FALL if drop >= AirRules.PIT_DROP else WolfState.FALL)

func check_void_below() -> bool:
	for elastic in get_tree().get_nodes_in_group("elastic_controllers"):
		if elastic.get_world_3d()==get_world_3d() and elastic.protects_from_void(self): return false
	if floor_probe_warmup > 0: return false
	if current_state == WolfState.PIT_FALL or is_instance_valid(active_rocket) or cinematic_controls_locked or tutorial_movement_locked: return false
	var environment = get_parent().get_node_or_null("LevelEnvironment")
	if environment and environment.over_water(global_position): return false # Water owns its plunge/attack, even if the bottom ray misses.
	ground_distance = ground_drop()
	# A finite ray hit hundreds of metres below is still a pit. Keep its
	# depth relative to takeoff/last ground: falling closer to the bottom
	# must not turn a previously fatal drop into a safe landing.
	var origin_y = float(jump_origin_y) if jump_origin_y != null else last_ground_y
	var drop = maxf(ground_distance,ground_distance+origin_y-global_position.y)
	if drop < AirRules.PIT_DROP: return false
	# Protect the entire second ascent, not just positive velocity (the apex
	# has velocity zero). First jump gets a bounded opportunity for jump two.
	if current_state == WolfState.JUMP or jump_void_grace > 0 or (coyote_remaining > 0 and not is_instance_valid(carried_sheep)): return false
	# The second apex enters ordinary FALL. Keep the original first takeoff
	# height through both jumps; do not measure from the higher second apex.
	if jump_origin_y != null:
		if velocity.y >= 0 or global_position.y >= float(jump_origin_y)-jump_void_drop_margin: return false
	if current_state in [WolfState.RUN_START,WolfState.RUN] and AirRules.can_air_run(run_active,Vector2(velocity.x,velocity.z).length(),ground_distance,walk_speed):
		set_state(WolfState.RUN_AIR)
		return false
	set_state(WolfState.PIT_FALL)
	return true

func step_pit_fall(delta: float) -> void:
	velocity = Vector3.ZERO
	if death_animation_override == "crush_death" and is_instance_valid(crushing_rock):
		# Wolf::WOLF_ST_DIE_CRUSHED keeps the flattened body beneath its killer.
		global_position.y = minf(global_position.y,crushing_rock.bottom())
	if current_state == WolfState.PIT_FALL and not pit_is_air_run and state_time < direct_fall_impact_time:
		# WOLF_ST_FALL_TO_DEATH / DEAD1 moves down, unlike stationary STRIKE2.
		velocity.y = -minf(TERMINAL_VELOCITY,FALL_GRAVITY*state_time)
		global_position.y += velocity.y*delta
	if current_state == WolfState.BLAST_DEATH and not is_on_floor():
		velocity.y = -minf(TERMINAL_VELOCITY,FALL_GRAVITY*state_time)
		move_and_slide()
	run_dust.update_dust(delta,false,global_position,item_facing(),0,run_speed)
	if current_state == WolfState.PIT_FALL and not pit_is_air_run:
		# Keep the camera's world position anchored at the rim. Only pitch it
		# gently down; tracking Ralph's position would chase him off the map.
		var progress = smoothstep(0.0,direct_fall_camera_tilt_time,state_time)
		camera.quaternion = pit_camera_start.slerp(pit_camera_target,progress)
	else:
		camera.quaternion = pit_camera_start.slerp(pit_camera_target,clampf(state_time/0.4,0,1))
	var clip = sam_death_clip() if current_state == WolfState.SAM_DEATH else ("blast_death" if current_state == WolfState.BLAST_DEATH else pit_animation())
	var duration = animation_player.get_animation(clip).length+AirRules.RESTART_DELAY
	if current_state == WolfState.SAM_DEATH and clip in ["sam_death","sam_hit"]:
		# Wolf::Die adds 0x2000 ticks after both Sam finishes.
		duration = animation_player.get_animation(clip).length+2.0
	if current_state == WolfState.PIT_FALL and not pit_is_air_run:
		# Original uses a five-second upper bound; the port shortens the direct fall.
		duration = direct_fall_impact_time+OriginalRestartFade.DURATION
		if state_time >= direct_fall_impact_time and not direct_fall_impact_played:
			direct_fall_impact_played = true
			play_void_impact()
		if direct_fall_impact_played:
			void_impact.sample_animation("boom",state_time-direct_fall_impact_time)
	restart_fade.set_amount(clampf(state_time-(duration-1.0),0,1))
	if state_time >= duration:
		pit_respawn_count += 1
		respawn_at_checkpoint()

func respawn_ground_position(point: Vector3) -> Vector3:
	# Wolf::Reset queries ground at savedRespawnPos before setting its position.
	var query = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*30)
	query.collision_mask = 1
	var excluded: Array[RID] = [get_rid()]
	for group in ["grounded_npcs","sheep_targets"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is CollisionObject3D: excluded.append(actor.get_rid())
	query.exclude = excluded
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): point.y = hit["position"].y
	return point

func sam_death_clip() -> String:
	return death_animation_override if not death_animation_override.is_empty() else "sam_death"

func on_piranha_attack():
	if cinematic_controls_locked or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return
	interrupt_actions()
	death_animation_override = "piranha_death"
	set_state(WolfState.SAM_DEATH)

func on_blast(_origin: Vector3) -> void:
	if cinematic_controls_locked or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return
	set_state(WolfState.BLAST_DEATH)

func on_shark_attack(shark: Node3D) -> bool:
	if cinematic_controls_locked or restart_fade_remaining>0 or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return false
	interrupt_actions()
	# Wolf::HandleMessage(KILL_SHARK): EAT at the killer's exact origin and
	# rotation, paired with Shark EAT. Its own animation supplies the motion.
	global_position = shark.global_position
	skeleton.rotation = shark.rotation
	death_animation_override = "shark_death"
	set_state(WolfState.SAM_DEATH)
	var environment = get_parent().get_node_or_null("LevelEnvironment")
	if environment and environment.has_method("clear_death_camera"):
		var target = global_position+Vector3.UP*.6
		camera.global_position = environment.clear_death_camera(target)
		camera.look_at(target,Vector3.UP)
		pit_camera_start = camera.quaternion; pit_camera_target = camera.quaternion
	return true

func on_bull_attack(bull: Node3D) -> bool:
	if cinematic_controls_locked or restart_fade_remaining>0 or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return false
	interrupt_actions()
	var direction = bull.global_position-global_position
	skeleton.rotation.y = atan2(direction.x,direction.z)
	death_animation_override = "bull_death"
	set_state(WolfState.SAM_DEATH)
	return true

func on_rock_crush(rock: CollisionObject3D) -> bool:
	if cinematic_controls_locked or restart_fade_remaining > 0 or current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: return false
	interrupt_actions()
	# WSF_SKIP_BOX_TEST: let the killer settle against terrain instead of
	# standing on Ralph's live capsule while SQUASH3 flattens the model.
	add_collision_exception_with(rock)
	rock.add_collision_exception_with(self)
	crushing_rock = rock
	death_animation_override = "crush_death"
	set_state(WolfState.SAM_DEATH)
	return true

func respawn_at_checkpoint() -> void:
	if is_instance_valid(catapult_motion_owner): catapult_motion_owner.reset_controller()
	if is_instance_valid(carried_object): carried_object.return_home()
	void_impact.hide()
	climb_motion.clear(self)
	seesaw_launching = false
	water_motion.reset(self)
	if is_instance_valid(crushing_rock):
		remove_collision_exception_with(crushing_rock)
		crushing_rock.remove_collision_exception_with(self)
	crushing_rock = null
	OriginalBurntTint.apply(legacy_skin,false)
	var was_pit = current_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]
	if item_actions: item_actions.cancel()
	if is_instance_valid(active_rocket):
		active_rocket.finish_flight()
	if was_pit:
		if is_instance_valid(death_camera_parent): camera.reparent(death_camera_parent,true)
		camera.top_level = false
		camera.transform = saved_camera_local
	death_animation_override = ""
	global_position = checkpoint_position if checkpoint_position != null else safe_position
	if checkpoint_facing != null:
		global_position = respawn_ground_position(global_position)
		skeleton.rotation.y = checkpoint_facing
	camera_pivot.rotation = checkpoint_camera_rotation if checkpoint_position != null else safe_camera_rotation
	velocity = Vector3.ZERO
	was_on_floor = false
	can_double_jump = false
	jump_void_grace = 0
	coyote_remaining = 0
	jump_origin_y = null
	inventory.state.drop_uncommitted()
	set_state(WolfState.IDLE)
	if was_pit:
		restart_fade_remaining = OriginalRestartFade.DURATION
		restart_fade.set_amount(1)
	respawned.emit()

func interrupt_actions() -> void:
	climb_motion.clear(self)
	if is_instance_valid(elastic_motion_owner): elastic_motion_owner.cancel_motion()
	if is_instance_valid(elastic_pull_controller): elastic_pull_controller.cancel_motion()
	if seesaw_launching:
		seesaw_launching = false
		tutorial_movement_locked = false
	rock_cover.leave(self)
	if is_instance_valid(push_target): push_target.stop_push(false)
	if is_instance_valid(active_bush): active_bush.leave(false,false)
	if item_actions: item_actions.cancel()
	# Freeze starts a neutral pose, so releasing the lock cannot resume a jump/run.
	if inventory:
		inventory.close_wheel(true)
		if is_instance_valid(inventory.equipped_node) and inventory.equipped_node.class_id in [7,10,41]:
			inventory.equipped_node.deactivate()
	if is_instance_valid(active_rocket):
		active_rocket.finish_flight()
	velocity = Vector3.ZERO
	item_pull_velocity = Vector3.ZERO
	run_active = false
	run_tap_timer = 0
	jump_timer = 0
	can_double_jump = false
	jump_void_grace = 0
	coyote_remaining = 0
	jump_origin_y = null
	footstep_timer = 0
	sneak_step_count = 0
	state_time = 0
	reaction_pose_active = false
	stop_loop_sfx()
	audio_player.stop()
	sneak_audio_player.stop()
	for sound in animation_sfx_players:
		sound.stop()
	run_dust.clear()
	void_impact.hide()
	set_state(WolfState.IDLE)
	play_anim("idle")
	animation_player.advance(0)
	apply_legacy_reaction_pose()

func set_state(new_state: WolfState) -> void:
	if current_state == new_state:
		return
	if new_state!=WolfState.CLIMB and climb_motion.climbing(): climb_motion.clear(self)
	if new_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]: climb_motion.clear(self)
	if new_state not in [WolfState.COVER_ENTER,WolfState.COVER_HIDDEN]: rock_cover.clear(self)
	if dizzy_effect: dizzy_effect.stop()
	if new_state == WolfState.PIT_FALL:
		pit_is_air_run = current_state == WolfState.RUN_AIR
		direct_fall_impact_played = false
		void_impact.hide()
	if new_state in [WolfState.PIT_FALL,WolfState.BLAST_DEATH,WolfState.SAM_DEATH]:
		if is_instance_valid(carried_object): carried_object.return_home()
		if inventory.equipped_node is FluteItem: inventory.equipped_node.deactivate()
		if seesaw_launching:
			seesaw_launching = false
			tutorial_movement_locked = false
		if is_instance_valid(push_target): push_target.stop_push(false)
		if is_instance_valid(active_bush): active_bush.leave(false,false)
		coyote_remaining = 0
		if item_actions: item_actions.cancel()
		inventory.close_wheel(true)
		if is_instance_valid(active_rocket): active_rocket.finish_flight()
		if is_instance_valid(carried_sheep): carried_sheep.reset_to_home()
	
	if new_state == WolfState.BLAST_DEATH: OriginalBurntTint.apply(legacy_skin,true)
	current_state = new_state
	if new_state != WolfState.SNEAK and sneak_audio_player:
		sneak_audio_player.stop()
	state_time = 0.0
	if new_state not in [WolfState.RUN_START, WolfState.RUN, WolfState.RUN_AIR]:
		run_active = false
		stop_loop_sfx()
	
	match new_state:
		WolfState.IDLE:
			stop_loop_sfx()
			original_idle.reset(self)
		WolfState.WALK:
			stop_loop_sfx()
			footstep_timer = 0.0
			play_anim("walk")
		WolfState.SNEAK:
			stop_loop_sfx()
			footstep_timer = 0.0
			sneak_step_count = 0
			play_anim("sneak")
		WolfState.COVER_ENTER:
			play_anim("cover_enter")
		WolfState.COVER_HIDDEN:
			play_anim("cover_hidden")
		WolfState.FLUTE_IDLE:
			play_anim("flute_idle")
		WolfState.FLUTE_WALK:
			play_anim("flute_walk")
		WolfState.RUN_START:
			run_tap_timer = 0.0
			run_active = true
			play_anim("run_start")
			begin_run_sound()
		WolfState.RUN:
			if animation_player.current_animation != "run":
				play_anim("run")
			update_run_sound()
		WolfState.RUN_AIR:
			velocity.y = 0
			if animation_player.current_animation != "run":
				play_anim("run")
			update_run_sound()
		WolfState.PIT_FALL, WolfState.BLAST_DEATH, WolfState.SAM_DEATH:
			restart_fade.set_iris(true)
			velocity = Vector3.ZERO
			play_anim(sam_death_clip() if new_state == WolfState.SAM_DEATH else ("blast_death" if new_state == WolfState.BLAST_DEATH else pit_animation()))
			saved_camera_local = camera.transform
			var held = camera.global_transform
			# SpringArm updates child placement internally, even with top_level.
			# Detach for death so the exact world view cannot follow the fall.
			death_camera_parent = camera.get_parent()
			camera.reparent(get_parent(),true)
			camera.top_level = true
			camera.global_transform = held
			if new_state == WolfState.PIT_FALL and not pit_is_air_run:
				pit_camera_start = camera.quaternion
				# A local pitch preserves heading. Limit steep views so an already
				# downward-facing camera never flips past vertical.
				var pitch = asin(clampf((-camera.global_basis.z).y,-1,1))
				var tilt = minf(deg_to_rad(direct_fall_camera_tilt),maxf(0,pitch+deg_to_rad(80)))
				pit_camera_target = pit_camera_start*Quaternion(Vector3.RIGHT,-tilt)
				play_animation_sfx("res://assets/audio/sfx/original_void_fall.wav")
				return
			pit_camera_start = camera.quaternion
			camera.look_at(global_position+Vector3.UP*1.0+item_facing()*0.65,Vector3.UP)
			pit_camera_target = camera.quaternion
			camera.quaternion = pit_camera_start
		WolfState.RUN_STOP:
			play_anim("run_stop")
		WolfState.RUN_CRASH:
			velocity.x = 0.0
			velocity.z = 0.0
			play_anim("run_crash")
			dizzy_effect.start()
		WolfState.RUN_RECOVER:
			play_anim("run_recover")
			run_recovery_started.emit()
		WolfState.JUMP:
			stop_loop_sfx()
			play_anim("jump")
			# Mode-1 JUMP4 dispatches its own recovered sound14 cue.
			if not is_instance_valid(carried_sheep):
				play_sfx("res://assets/audio/sfx/jump.wav", randf_range(0.98, 1.05))
		WolfState.FALL:
			stop_loop_sfx()
			play_anim("fall")
		WolfState.LAND:
			stop_loop_sfx()
			play_anim("land")
			play_sfx("res://assets/audio/sfx/land.wav", randf_range(0.95, 1.05))

	advance_animation_sound_cues(-0.001, 0.0)

func play_anim(anim_name: String) -> void:
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.has_animation(anim_name):
		# STRIKE1/STAND7 contain squash/stretch. Older imported clips have no
		# scale tracks, so reset those channels when leaving the reaction.
		if skeleton:
			skeleton.clear_bones_global_pose_override()
			reaction_pose_active = false
			for bone in range(skeleton.get_bone_count()):
				skeleton.set_bone_pose_scale(bone, Vector3.ONE)
		animation_player.play(anim_name)

func handle_audio(delta: float, is_moving: bool, on_ground: bool) -> void:
	if not on_ground:
		return

	if (current_state == WolfState.WALK or is_instance_valid(elastic_pull_controller)) and is_moving:
		footstep_timer += delta
		if footstep_timer >= 0.44:
			footstep_timer = 0.0
			var pitch = randi_range(12,20)/16.0
			play_sfx("res://assets/audio/sfx/footstep.wav", pitch)
	elif current_state == WolfState.SNEAK and is_moving:
		footstep_timer += delta
		var step_clip = animation_player.current_animation
		if not animation_player.has_animation(step_clip): step_clip = "sneak"
		var interval = StepRules.step_interval(animation_player.get_animation(step_clip).length)
		if sneak_step_count < 8 and footstep_timer >= interval:
			footstep_timer = 0.0
			var cue = StepRules.sneak_step(sneak_step_count)
			# SNDF_NO_RETRIGGER: a still-playing step keeps its pitch/volume.
			if not sneak_audio_player.playing:
				sneak_audio_player.stream = preload("res://assets/audio/sfx/sneak_step.wav")
				sneak_audio_player.pitch_scale = cue["pitch"]
				sneak_audio_player.volume_db = -2.0 + linear_to_db(cue["volume"])
				sneak_audio_player.play()
			sneak_step_count += 1

func can_use_inventory() -> bool:
	if climb_motion.active(): return false
	if is_instance_valid(elastic_motion_owner) or is_instance_valid(elastic_pull_controller): return false
	if is_instance_valid(push_target) or is_instance_valid(active_bush): return false
	if launch_controls_locked or cinematic_controls_locked or tutorial_movement_locked or restart_fade_remaining > 0:
		return false
	if is_instance_valid(active_rocket):
		return false
	return current_state in [WolfState.IDLE, WolfState.WALK, WolfState.SNEAK,
		WolfState.JUMP, WolfState.FALL, WolfState.LAND, WolfState.RUN_RECOVER, WolfState.SWIM, WolfState.COVER_ENTER, WolfState.COVER_HIDDEN, WolfState.FLUTE_IDLE, WolfState.FLUTE_WALK]

func hidden_from_observer(observer: Vector3) -> bool:
	return rock_cover.hidden_from(self,observer)

func can_use_item() -> bool:
	if climb_motion.climbing(): return not cinematic_controls_locked and not launch_controls_locked and restart_fade_remaining<=0
	if is_instance_valid(elastic_pull_controller): return not cinematic_controls_locked and restart_fade_remaining<=0
	return can_use_inventory() or is_instance_valid(active_rocket)

func item_facing() -> Vector3:
	return (skeleton.global_transform.basis.z if skeleton else global_transform.basis.z).normalized()

func item_hand_position() -> Vector3:
	if legacy_skin and legacy_skin.last_matrices.size() > 18:
		return (skeleton.global_transform * legacy_skin.last_matrices[18]).origin
	return global_position + Vector3.UP * 0.85 + item_facing() * 0.65

func apply_item_pull(point: Vector3, strength: float, delta: float) -> void:
	item_pull_velocity += (point - global_position).normalized() * strength * delta

func set_item_costume(kind: String, item: Node) -> void:
	item_costume = kind
	costume_item = item
	if costume_visual:
		costume_visual.queue_free()
		costume_visual = null
	var mesh = skeleton.get_node_or_null("MeshInstance3D") if skeleton else null
	if mesh:
		mesh.visible = kind.is_empty()
	if not kind.is_empty():
		var path = "res://assets/items/%s_costume/worn.tscn" % kind
		if ResourceLoader.exists(path):
			costume_visual = load(path).instantiate()
			add_child(costume_visual)
			costume_visual.actor = self
		else:
			# Keep Ralph visible if an asset was not built yet.
			if mesh:
				mesh.show()

func play_sfx(path: String, pitch: float = 1.0) -> void:
	if not audio_player:
		audio_player = get_node_or_null("AudioStreamPlayer3D")
	if not audio_player or not audio_player.is_inside_tree() or not ResourceLoader.exists(path):
		return
	if not sfx_cache.has(path):
		sfx_cache[path] = load(path)
	var stream = sfx_cache[path]
	if stream:
		audio_player.stream = stream
		audio_player.pitch_scale = pitch
		audio_player.play()

func play_loop_sfx(path: String) -> void:
	if not loop_audio_player or not ResourceLoader.exists(path):
		return
	if not sfx_cache.has(path + "#loop"):
		var stream = load(path).duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		sfx_cache[path + "#loop"] = stream
	if loop_audio_player.stream != sfx_cache[path + "#loop"]:
		loop_audio_player.stream = sfx_cache[path + "#loop"]
	if not loop_audio_player.playing:
		loop_audio_player.play()

func stop_loop_sfx() -> void:
	if loop_audio_player:
		loop_audio_player.stop()
	run_audio_phase = ""

func begin_run_sound() -> void:
	stop_loop_sfx()
	if audio_player:
		audio_player.stop()
	if loop_audio_player:
		run_audio_phase = "start"
		loop_audio_player.stream = load("res://assets/audio/sfx/run_start.wav")
		loop_audio_player.play()

func _on_run_sound_finished() -> void:
	if current_state in [WolfState.RUN_START, WolfState.RUN, WolfState.RUN_AIR]:
		run_audio_phase = "loop"
		play_loop_sfx("res://assets/audio/sfx/run_loop.wav")

func update_run_sound() -> void:
	# Preserve the start handle across RUN_START -> RUN, as SetStateKeepSound.
	if loop_audio_player and not loop_audio_player.playing:
		_on_run_sound_finished()

func state_animation_finished(name: String) -> bool:
	if animation_player and animation_player.has_animation(name):
		return state_time >= animation_player.get_animation(name).length
	return state_time >= 1.0

func resolve_run_contacts(incoming_velocity: Vector3) -> void:
	if current_state not in [WolfState.RUN_START, WolfState.RUN, WolfState.RUN_STOP]:
		return
	for index in range(get_slide_collision_count()):
		var hit = get_slide_collision(index)
		var normal = hit.get_normal()
		if abs(normal.y) >= 0.7:
			continue
		var collider = hit.get_collider()
		var exempt = collider != null and collider.has_meta("run_impact_exempt") and bool(collider.get_meta("run_impact_exempt"))
		var contact_height = hit.get_position().y-global_position.y
		if collider is Node3D and collider.has_meta("original_solid_top"):
			# Original object tests use overlapping boxes' upper contact extent.
			# Capsule/convex Godot contacts can instead report only a foot tangent.
			contact_height = minf(1.65,collider.global_position.y+float(collider.get_meta("original_solid_top"))-global_position.y)
		if RunRules.is_run_crash(incoming_velocity, normal, contact_height, run_speed, exempt):
			var speed = Vector2(incoming_velocity.x, incoming_velocity.z).length()
			set_state(WolfState.RUN_CRASH)
			# Equivalent to MSG_BUMP; objects can implement their own response.
			if collider != null and collider.has_method("on_ralph_run_impact"):
				collider.on_ralph_run_impact(self, hit.get_position(), normal, speed)
			run_impact.emit(collider, normal, hit.get_position(), speed)
			return

func advance_animation_sound_cues(previous_time: float, time: float) -> void:
	var name = ""
	match current_state:
		WolfState.RUN_STOP: name = "run_stop"
		WolfState.RUN_CRASH: name = "run_crash"
		WolfState.RUN_RECOVER: name = "run_recover"
		WolfState.PIT_FALL: name = pit_animation()
		WolfState.BLAST_DEATH: name = "blast_death"
		WolfState.SAM_DEATH: name = sam_death_clip()
	if name.is_empty() or run_data.is_empty():
		return
	var animation = run_data["animations"][name]
	var duration: float = animation["duration"]
	var first_cycle = maxi(0, int(maxf(previous_time, 0.0) / duration)) if name == "run_recover" else 0
	var last_cycle = int(time / duration) if name == "run_recover" else 0
	for cycle in range(first_cycle, last_cycle + 1):
		for cue in animation["sound_cues"]:
			var cue_time: float = cue["time"] + cycle * duration
			if cue_time > previous_time and cue_time <= time:
				var sound = run_data["sounds"].get(str(int(cue["sound_id"])))
				if sound:
					play_animation_sfx(sound["path"],current_state==WolfState.SAM_DEATH)

func play_animation_sfx(path: String,native_falloff: bool = false) -> void:
	# Animation cues can overlap, but the same sample cannot retrigger itself.
	var available: AudioStreamPlayer3D = null
	for player in animation_sfx_players:
		if player.playing and player.stream.resource_path == path:
			return
		if not player.playing:
			available = player
	if available == null:
		available = preload("res://scripts/audio/original_character_audio.gd").new()
		add_child(available)
		animation_sfx_players.append(available)
	available.configure_native(native_falloff,-2.0)
	available.stream = load(path)
	available.play()

func play_void_impact() -> void:
	# Native state 0x0e replaces Ralph with AEXPLOS2 / BOOM, not run dust.
	void_impact.hide()
	# The direct fall travels beyond positional-audio range while its camera
	# stays above the map. This offscreen impact belongs to the restart view.
	if not is_instance_valid(void_impact_audio):
		void_impact_audio = AudioStreamPlayer.new()
		void_impact_audio.volume_db = -2
		add_child(void_impact_audio)
		void_impact_audio.stream = load("res://assets/audio/sfx/original_void_impact.wav")
	void_impact_audio.play()
	# The impact artwork is placed near the camera for a bottomless pit.
	# Test the real view first so this presentation cannot draw over a wall.
	var viewport_size = get_viewport().get_visible_rect().size
	var point = camera.unproject_position(global_position)
	if camera.is_position_behind(global_position): point.x = viewport_size.x*.5
	point.x = clampf(point.x,viewport_size.x*.25,viewport_size.x*.75)
	point.y = viewport_size.y*.78
	# Do not cast down the low-screen effect ray all the way to fallen Ralph:
	# it almost always meets distant terrain after the camera tilts downward.
	# Only nearby walls in front of the held camera should suppress BOOM.
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*6.0,3)
	query.exclude = [get_rid()]
	var obstruction = get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and obstruction.normal.y<.65: return
	void_impact.global_transform = Transform3D(Basis(camera.global_basis.x,camera.global_basis.z,-camera.global_basis.y).scaled(Vector3.ONE*.045),camera.project_position(point,2.0))
	void_impact.sample_animation("boom",0)
	void_impact.show()

func pit_animation() -> String:
	return "pit_fall" if pit_is_air_run else "fall_death"
