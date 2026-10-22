extends Node3D
class_name OriginalElasticController

# Port of elastic.cpp's rider, band mesh, tension, pull-up and sine projection.
# Coordinates are metres (100 native units); rules belong to the item record.
var item: GameItem
var definition: Dictionary = {}
var max_length = 11.5
var two_anchor_max_length = 11.5
var full_charge_threshold = 1.0
var minimum_launch_charge = 0.0
var automatic_launch_hold = 1.0
var projection_distance = 50.0
var projection_height = 5.0
var projection_speed = 20.0
var mode = "item"
var tree_a: Node3D
var tree_b: Node3D
var wolf: RalphController
var pulling = false
var engaged = false
var engaged_side = 0
var tension = 0.0
var hold_time = 0.0
var handle = Vector3.ZERO
var band: MeshInstance3D
var material: StandardMaterial3D
var flight: Dictionary = {}
var retract: Dictionary = {}
var vibration: Dictionary = {}
var shot_camera: Camera3D
var previous_camera: Camera3D
var previous_lock = false
var pending_shot: Dictionary = {}
var stretch_audio: AudioStreamPlayer3D
var stretch_requested = false
var return_speed = 6.14
var spring_strength = 1.0
var interacting = false
var measurement: Dictionary = {}
var last_measurement: Dictionary = {}
var inventory_record: Dictionary = {}

func _ready():
	max_length = float(definition.get("max_length",max_length))
	two_anchor_max_length = float(definition.get("two_anchor_max_length",max_length))
	full_charge_threshold = float(definition.get("full_charge_threshold",1.0))
	minimum_launch_charge = float(definition.get("minimum_launch_charge",0.0))
	automatic_launch_hold = float(definition.get("automatic_launch_hold",1.0))
	projection_distance = float(definition.get("distance",projection_distance))
	projection_height = float(definition.get("height",projection_height))
	projection_speed = float(definition.get("speed",projection_speed))
	return_speed = float(definition.get("return_speed",6.14))
	spring_strength = float(definition.get("spring_strength",1.0))
	preload("res://scripts/testing/elastic_tuning_settings.gd").apply_saved(self)
	add_to_group("elastic_controllers"); add_to_group("world_interactables")
	band = MeshInstance3D.new(); add_child(band); band.top_level = true
	band.global_transform = Transform3D.IDENTITY
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	band.material_override = material
	stretch_audio = AudioStreamPlayer3D.new(); add_child(stretch_audio)
	stretch_audio.top_level = true; stretch_audio.max_distance = 25; stretch_audio.volume_db = -3
	var sound_path = str(definition.get("stretch_sound","res://assets/levels/lvl_03/audio/284.wav"))
	if ResourceLoader.exists(sound_path):
		var stream: AudioStreamWAV = load(sound_path).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0; stream.loop_end = int(stream.get_length()*stream.mix_rate)
		stretch_audio.stream = stream
	call_deferred("bind_wolf")

func bind_wolf():
	for actor in get_tree().get_nodes_in_group("player"):
		if actor.get_world_3d()==get_world_3d():
			wolf = actor
			wolf.respawned.connect(on_respawn)
			break

func has_anchor(tree: Node3D) -> bool: return tree==tree_a or tree==tree_b

func accepts_tree(tree: Node3D,actor: RalphController) -> bool:
	return wolf==actor and (mode=="one" or (mode=="strung" and has_anchor(tree))) and flight.is_empty() and retract.is_empty() and vibration.is_empty()

func tree_action(tree: Node3D,actor: RalphController) -> bool:
	if not tree.nearby(actor): return false
	if mode=="item" and item.holder==actor:
		return actor.item_actions.begin([
			{"clip":"throw_place","enter":func(): actor.item_actions.face(tree.global_position),
			"exit":func(): tie_first(tree,actor)}, {"clip":"throw_end"}])
	if mode=="one":
		if tree==tree_a:
			reset_item(); item.global_position = actor.global_position
			item.available = true; item.show(); item.original_visual.show()
			return item.collect(actor.inventory)
		tree_b = tree; mode = "strung"; engaged = false; tension = 0
		return true
	if mode=="strung" and has_anchor(tree):
		return actor.item_actions.begin([{"clip":"pickup_start","exit":func():
			if tree==tree_a: tree_a = tree_b
			tree_b = null; mode = "one"; engaged = false; tension = 0}])
	return false

func tie_first(tree: Node3D,actor: RalphController):
	wolf = actor; tree_a = tree; tree_b = null; mode = "one"
	item.holder = null; item.available = false; item.deployed = true
	item.global_transform = Transform3D.IDENTITY
	item.show(); item.original_visual.hide()
	inventory_record = actor.inventory.state.items.get(item.item_id,{
		"id":item.item_id,"class_id":42,"label":item.item_label,"icon":item.icon_path,"kept":item.kept}).duplicate(true)
	actor.inventory.state.remove(item.item_id)
	handle = actor.global_position

func project(point: Vector3) -> Dictionary:
	if not is_instance_valid(tree_a) or not is_instance_valid(tree_b): return {}
	var a = tree_a.anchor(); var b = tree_b.anchor()
	var axis = Vector3(b.x-a.x,0,b.z-a.z)
	var length_sq = axis.length_squared()
	if length_sq<.0001: return {}
	var t = Vector3(point.x-a.x,0,point.z-a.z).dot(axis)/length_sq
	var foot = a.lerp(b,t)
	var normal = Vector3(-axis.z,0,axis.x).normalized()
	var side_distance = (point-foot).dot(normal)
	return {"inside":t>=0 and t<=1,"distance":absf(side_distance),"side":1 if side_distance>=0 else -1,"foot":foot}

func can_interact(actor: RalphController) -> bool:
	if is_instance_valid(actor.carried_sheep): return false
	if actor!=wolf or not flight.is_empty() or not retract.is_empty() or not vibration.is_empty(): return false
	if pulling: return true
	if is_instance_valid(actor.inventory.equipped_node): return false
	if mode!="strung": return false
	var p = project(actor.global_position)
	return not p.is_empty() and p.inside and (engaged or (p.distance<1 and absf(actor.global_position.y-p.foot.y)<1.6))

func action_label(_actor: RalphController) -> String:
	return GameLocalization.text("lvl_03",0,60 if pulling else 59)

func interact(actor: RalphController) -> bool:
	if not can_interact(actor): return false
	if pulling: release_pull(); return true
	if is_instance_valid(actor.inventory.equipped_node): return false
	# WolfDoAction(CTX_ELASTIC_PULL) enters DRAU1 directly. TAKE1A belongs
	# to detaching/recovering an endpoint, not to gripping the middle.
	actor.interrupt_actions()
	pulling = true; mode = "pulled"; actor.elastic_pull_controller = self
	var p = project(actor.global_position)
	actor.item_actions.face(p.foot)
	actor.play_anim("elastic_pull_idle")
	return true

func step_pull(actor: RalphController,delta: float):
	if not pulling: return
	var locked = actor.inventory_controls_locked or actor.launch_controls_locked or actor.tutorial_movement_locked
	if not locked and Input.is_action_just_pressed("jump"):
		release_pull(); actor.jump_timer = 0
		actor.current_jump_height = actor.JUMP_HEIGHT*actor.jump_height_scale
		actor.current_jump_duration = actor.JUMP_DURATION
		actor.set_state(actor.WolfState.JUMP); return
	var input = Input.get_vector("move_left","move_right","move_forward","move_backward")
	if locked: input = Vector2.ZERO
	var direction = actor.camera_pivot.global_basis*Vector3(input.x,0,input.y)
	direction.y = 0
	actor.velocity = direction*actor.walk_speed
	if not actor.is_on_floor(): actor.velocity.y -= actor.FALL_GRAVITY*delta
	modify_move(actor,delta)
	actor.move_and_slide()
	var clip = "elastic_pull_move" if input.length_squared()>.01 else "elastic_pull_idle"
	if actor.animation_player.current_animation!=clip: actor.play_anim(clip)
	actor.handle_audio(delta,input.length_squared()>.01,actor.is_on_floor())
	actor.state_time += delta
	if not actor.is_on_floor() and actor.global_position.y<tree_a.anchor().y-1.6: release_pull()

func apply_tension(amount: Vector3,velocity: Vector3,delta: float,one: bool) -> Dictionary:
	var limit = max_length if one else two_anchor_max_length
	stretch_requested = velocity.length()>.5 and amount.dot(velocity)>.01
	# Vec3s truncates movement/force to native centimetres. Without that
	# quantization a floating spring approaches MAX forever and never retracts.
	var step = native_vector(velocity*delta)
	var combined = native_vector(amount)+step
	var length = floor(combined.length()*100)*.01; var speed = floor(velocity.length()*100)*.01
	var over = length>limit
	if over:
		combined = combined.normalized()*limit
		if one: step = combined*(-.2/maxf(speed,.01))
		else: step.x = 0; step.z = 0; length = limit
	elif length>limit*.5:
		var ratio = (length-limit*.5)/(limit*.5)
		var effective = length-limit*.5 if speed<6 else speed*ratio
		# C++ first converts speed to 10-bit units/ms, then multiplies integer
		# g_dtMs. Multiplying floats before rounding changes the yo-yo threshold.
		var rate = int(int(effective*100)*1024/1000)
		var force_distance = int(rate*maxi(1,int(delta*1000))/1024)*.01
		step -= native_vector(combined.normalized()*force_distance*spring_strength)
	tension = maxf(0,(length-limit*.5)/(limit*.5))
	if not one and tension>=full_charge_threshold: tension = 1.0
	return {"step":step,"over":over}

func native_vector(value: Vector3) -> Vector3:
	return Vector3(int(value.x*100),int(value.y*100),int(value.z*100))*.01

func protects_from_void(actor: RalphController) -> bool:
	return actor==wolf and mode=="one" and is_instance_valid(tree_a)

func modify_move(actor: RalphController,delta: float) -> bool:
	if actor!=wolf or not flight.is_empty() or not retract.is_empty() or not vibration.is_empty() or actor.cinematic_controls_locked: return false
	if mode=="one":
		if interacting:
			interacting = false
			if actor.global_position.y<tree_a.anchor().y-3:
				start_retract(actor); return true
		var stretched = apply_tension(actor.global_position-tree_a.anchor(),actor.velocity,delta,true)
		keep_ground_contact(actor,stretched)
		actor.velocity = stretched.step/delta; handle = actor.global_position
		if stretched.over and not actor.is_on_floor() and actor.global_position.y<tree_a.anchor().y-3:
			start_retract(actor)
		return true
	elif mode in ["strung","pulled"]:
		var p = project(actor.global_position)
		var next = project(actor.global_position+actor.velocity*delta)
		if p.is_empty() or next.is_empty(): return false
		if not pulling and next.inside:
			if not engaged and p.side!=next.side and actor.global_position.y<=p.foot.y and actor.global_position.y>=p.foot.y-1.6:
				engaged = true; engaged_side = next.side
			elif engaged and next.side!=engaged_side: engaged = false; tension = 0; hold_time = 0
		if pulling or engaged:
			var midpoint = (tree_a.anchor()+tree_b.anchor())*.5
			var amount = actor.global_position*2-midpoint*2
			var grounded = grounded_rider(actor)
			if engaged and not grounded and tension>0:
				actor.velocity.x *= .25; actor.velocity.z *= .25
			var stretched = apply_tension(amount,actor.velocity,delta,false)
			# Native gravity/contact keeps a grounded rider planted. Godot's zero
			# grounded velocity must not turn the anchor's .8m height into a jump.
			keep_ground_contact(actor,stretched)
			actor.velocity = stretched.step/delta; handle = actor.global_position
			if not pulling and tension>0 and p.distance>1:
				var charged = tension>=minimum_launch_charge
				hold_time = hold_time+delta if charged and tension>=.875 else 0
				if charged and (not grounded or hold_time>=automatic_launch_hold):
					start_vibration(handle,midpoint)
					start_launch(actor,amount,tension)
			else: hold_time = 0
			return true
	return false

func keep_ground_contact(actor: RalphController,stretched: Dictionary):
	# A zero/upward displacement toggles Godot's grounded flag and repeatedly
	# enters LAND, which brakes walking before the elastic can reach full charge.
	# Preserve native grounded contact on small slopes; a real jump stays free.
	if grounded_rider(actor):
		stretched.step.y = minf(-.01,stretched.step.y)

func grounded_rider(actor: RalphController) -> bool:
	# Sliding up a small floor slope can produce a tiny positive Y velocity.
	# That is still ground contact, not the native airborne quarter-speed branch.
	return actor.current_state!=actor.WolfState.JUMP and actor.velocity.y<=.5 and (actor.is_on_floor() or actor.ground_distance<.15)

func start_retract(actor: RalphController):
	var end = actor.global_position.lerp(tree_a.pull_up_point,.5-cos(PI*1.25)*.5)
	retract = {"start":actor.global_position,"time":0.0,
		"duration":maxf(.1,(tree_a.anchor().y-actor.global_position.y)/return_speed),
		"landing":safe_return_landing(actor,end)}
	actor.elastic_motion_owner = self
	actor.set_state(actor.WolfState.FALL)
	if is_instance_valid(actor.carried_sheep): actor.play_anim("sheep_carry_fall")
	play_snap()

func safe_return_landing(actor: RalphController,end: Vector3) -> Vector3:
	# Native BOX.min is above the ledge, near its edge. The narrower Godot
	# capsule can miss that edge on release. Keep the native height/cosine;
	# settle XZ smoothly onto the nearest supported, unobstructed upper floor.
	var space = get_world_3d().direct_space_state
	var body = actor.get_node("CollisionShape3D")
	for radius in [0.0,.4,.8,1.2,1.6,2.0]:
		for i in range(12):
			var point = end+Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*radius
			var hits: Array = []; var safe = true
			for offset in [Vector3.ZERO,Vector3(.3,0,0),Vector3(-.3,0,0),Vector3(0,0,.3),Vector3(0,0,-.3)]:
				var top = Vector3(point.x,tree_a.global_position.y+2,point.z)+offset
				var ray = PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*4,1)
				ray.exclude = [actor.get_rid()]
				var hit = space.intersect_ray(ray)
				if hit.is_empty() or hit.normal.y<.6 or hit.position.y<tree_a.global_position.y-.6:
					safe = false; break
				hits.append(hit.position)
			if not safe: continue
			point.y = hits[0].y+.03
			var query = PhysicsShapeQueryParameters3D.new(); query.shape = body.shape
			query.transform = Transform3D(Basis.IDENTITY,point+body.position)
			query.exclude = [actor.get_rid()]; query.collision_mask = actor.collision_mask
			if space.intersect_shape(query,1).is_empty(): return point
	return end

func release_pull():
	if not pulling: return
	pulling = false; wolf.elastic_pull_controller = null; mode = "strung"
	wolf.set_state(wolf.WolfState.IDLE); wolf.original_idle.reset(wolf)
	if engaged: return
	var midpoint = (tree_a.anchor()+tree_b.anchor())*.5
	start_vibration(wolf.global_position,midpoint)
	pending_shot = {"amount":wolf.global_position*2-midpoint*2,"ratio":tension if tension>=minimum_launch_charge else 0.0}
	var target = find_launch_target(wolf.global_position)
	if target and pending_shot.ratio>0: start_launch(target,pending_shot.amount,pending_shot.ratio)
	play_snap()

func find_launch_target(point: Vector3) -> Node3D:
	var best: Node3D; var score = INF
	var candidates: Array = []
	for group in ["elastic_launch_targets","sheep_targets","pushable_rocks","seesaw_boxes","game_items"]: candidates.append_array(get_tree().get_nodes_in_group(group))
	for candidate in candidates:
		if candidate==item or candidate==wolf or candidate.get_world_3d()!=get_world_3d() or not candidate.is_visible_in_tree(): continue
		if candidate is GameItem and (not candidate.available or candidate.holder): continue
		if candidate is OriginalSheep and (candidate.dead or candidate.carried_by): continue
		var d = candidate.global_position-point
		var distance = Vector2(d.x,d.z).length_squared()
		if absf(d.y)<=1.28 and distance<=.64 and distance<score: best = candidate; score = distance
	return best

func projection_for(target: Node3D) -> Dictionary:
	var result = {"distance":projection_distance,"height":projection_height}
	if not is_instance_valid(tree_a) or not is_instance_valid(tree_b): return result
	var a = int(tree_a.get_meta("original_resource",-1))
	var b = int(tree_b.get_meta("original_resource",-1))
	# Optional port balance belongs to an authored pair, not every elastic in
	# the level. Keep native projection for other trees and slingshot cargo.
	for profile in definition.get("launch_profiles",[]):
		var anchors: Array = profile.get("anchors",[])
		if anchors.size()!=2: continue
		# JSON resource IDs are floats; Array.has compares numeric types strictly.
		var first = int(anchors[0]); var second = int(anchors[1])
		if not ((first==a and second==b) or (first==b and second==a)): continue
		if profile.get("wolf_only",false) and target!=wolf: continue
		result.distance = float(profile.get("distance",result.distance))
		result.height = float(profile.get("height",result.height))
		break
	return result

func start_launch(target: Node3D,amount: Vector3,ratio: float):
	if ratio<=0 or amount.is_zero_approx(): return
	pending_shot.clear()
	finish_launch()
	var direction = -amount.normalized(); direction.y = 0
	var projection = projection_for(target)
	flight = {"target":target,"start":target.global_position,"direction":direction,"travelled":0.0,"charge":ratio,
		"distance":projection.distance*ratio,"height":projection.height*ratio,
		"physics":target.is_physics_processing()}
	if target is PhysicsBody3D and target!=wolf:
		flight["ignore_wolf"] = not target.get_collision_exceptions().has(wolf)
		if flight.ignore_wolf: target.add_collision_exception_with(wolf)
	engaged = false; hold_time = 0
	if target is RalphController:
		target.elastic_motion_owner = self; target.set_state(target.WolfState.FALL)
		if is_instance_valid(target.carried_sheep): target.play_anim("sheep_carry_fall")
	else:
		target.set_physics_process(false)
		if target is OriginalSheep: target.clear_seesaw_launch(); target.visual.idle("stand1")
		if target.is_in_group("pushable_rocks"):
			target.arc.clear(); target.seesaw_support = null
			if is_instance_valid(target.pushing_actor): target.stop_push(false)
		previous_lock = wolf.launch_controls_locked; wolf.launch_controls_locked = true
		previous_camera = get_viewport().get_camera_3d()
		shot_camera = Camera3D.new(); add_child(shot_camera)
		if definition.has("camera"):
			var p = definition.camera.eye
			shot_camera.global_position = GameSpace.original_point(Vector3(p[0],p[1],p[2]))
			shot_camera.fov = rad_to_deg(2*atan(384.0/float(definition.camera.focal)))
		else: shot_camera.global_position = target.global_position+Vector3(5,4,5)
		shot_camera.current = true
	play_snap()

func finish_launch():
	if not flight.is_empty():
		var target = flight.target
		if is_instance_valid(target):
			if flight.get("ignore_wolf",false) and is_instance_valid(wolf): target.remove_collision_exception_with(wolf)
			target.set_physics_process(flight.physics)
			if target is RalphController:
				target.elastic_motion_owner = null
				target.velocity = Vector3.DOWN
				target.floor_probe_warmup = 3
			elif target is OriginalSheep:
				target.velocity = Vector3.ZERO
				if not target.dead: target.begin_random_idle(false)
			elif target is CharacterBody3D: target.velocity = Vector3.ZERO
	flight.clear()
	if is_instance_valid(shot_camera):
		if shot_camera.current and is_instance_valid(previous_camera): previous_camera.current = true
		shot_camera.queue_free(); shot_camera = null
		if is_instance_valid(wolf): wolf.launch_controls_locked = previous_lock

func start_vibration(from: Vector3,midpoint: Vector3):
	vibration = {"from":from,"to":midpoint*2-from-Vector3.UP*1.6,"t":0.0,"rate":8.192,"amp":.5}

func play_snap():
	if stretch_audio: stretch_audio.stop()
	item.sound.global_position = handle
	item.play_item_sound(str(definition.get("snap_sound","res://assets/levels/lvl_03/audio/235.wav")))

func update_stretch_audio():
	stretch_audio.global_position = handle+Vector3.UP*.8
	var stretching = stretch_requested and tension>.01 and (mode in ["one","pulled"] or engaged)
	stretching = stretching and flight.is_empty() and retract.is_empty() and vibration.is_empty()
	if stretching and stretch_audio.stream:
		if not stretch_audio.playing: stretch_audio.play()
	else: stretch_audio.stop()

func _physics_process(delta: float):
	if not is_instance_valid(wolf): return
	measure_trip(delta)
	if wolf.current_state in [wolf.WolfState.PIT_FALL,wolf.WolfState.BLAST_DEATH,wolf.WolfState.SAM_DEATH]:
		cancel_motion(); return
	# Native ELASTIC_SUB_WOLF_INTERACTING: putting a bomb freezes its rider
	# move temporarily, then pulls up immediately below anchorY-300. Waiting
	# for MAX again after PUT1B wastes the entire dynamite fuse.
	if mode=="one" and (wolf.item_actions.busy or is_instance_valid(wolf.push_target)):
		interacting = true
		handle = wolf.global_position
	if not retract.is_empty():
		var angle = minf(retract.time/retract.duration,1.25)*PI
		wolf.global_position = retract.start.lerp(tree_a.pull_up_point,.5-cos(angle)*.5)
		var settle = smoothstep(PI,PI*1.25,angle)
		wolf.global_position.x = lerpf(wolf.global_position.x,retract.landing.x,settle)
		wolf.global_position.z = lerpf(wolf.global_position.z,retract.landing.z,settle)
		handle = wolf.global_position
		retract.time += delta
		if retract.time/retract.duration>=1.25:
			# StepPullUp deliberately passes the cosine peak before releasing at
			# 0xa00. BOX.min is a point above the destination, not a teleport spot.
			wolf.velocity = Vector3.ZERO; wolf.jump_origin_y = null
			wolf.elastic_motion_owner = null; wolf.floor_probe_warmup = 3; retract.clear()
	if not flight.is_empty():
		var target = flight.target
		if not is_instance_valid(target) or (target is OriginalSheep and target.dead): finish_launch()
		else:
			var collided = false
			# elastic::Update tests collision in three steps rather than tunnelling.
			for substep in range(3):
				flight.travelled = minf(flight.distance,flight.travelled+projection_speed*delta/3)
				var point = flight.start+flight.direction*flight.travelled
				point.y = flight.start.y+flight.height*sin(PI*flight.travelled/flight.distance)
				var step = point-target.global_position
				if target is PhysicsBody3D:
					collided = target.move_and_collide(step)!=null
				else:
					var query = PhysicsRayQueryParameters3D.create(target.global_position,point,1)
					query.exclude = [wolf.get_rid()]
					collided = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
					if not collided: target.global_position = point
				if collided: break
			if is_instance_valid(shot_camera): shot_camera.look_at(target.global_position+Vector3.UP*.4)
			if collided or flight.travelled>=flight.distance: finish_launch()
	if not vibration.is_empty():
		# Native SNAP scans along the vibrating band until it captures a target.
		if not pending_shot.is_empty() and pending_shot.ratio>0:
			var target = find_launch_target(handle)
			if target: start_launch(target,pending_shot.amount,pending_shot.ratio)
		vibration.t += vibration.rate*delta
		if absf(vibration.t-.5)>=vibration.amp:
			vibration.rate = -vibration.rate
			vibration.amp = floor(vibration.amp*4096*.75)/4096
			vibration.t = .5+signf(vibration.t-.5)*vibration.amp
		handle = vibration.from.lerp(vibration.to,vibration.t)
		if vibration.amp<=0: vibration.clear(); pending_shot.clear()
	elif mode in ["one","pulled"] or engaged: handle = wolf.global_position
	draw_band()
	update_stretch_audio()
	if mode=="strung" and not engaged and not pulling: tension = maxf(0,tension-delta*60/64)

func draw_band():
	band.visible = mode!="item" and is_instance_valid(tree_a)
	if not band.visible: return
	var a = tree_a.anchor()
	var b = tree_b.anchor() if is_instance_valid(tree_b) else handle+Vector3.UP*.8
	var middle = handle+Vector3.UP*.8 if pulling or engaged or not vibration.is_empty() else (a+b)*.5
	var mesh = ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Native six vertices, vertical12-unit ribbon, double-sided opaque faces.
	for pair in [[a,middle],[middle,b]]:
		var x: Vector3 = pair[0]; var y: Vector3 = pair[1]
		for vertex in [x,x-Vector3.UP*.12,y,y,x-Vector3.UP*.12,y-Vector3.UP*.12]: mesh.surface_add_vertex(vertex)
	mesh.surface_end(); band.mesh = mesh
	material.albedo_color = Color(1,.25,0).lerp(Color(.816,0,0),clampf(tension,0,1))

func cancel_motion():
	if not measurement.is_empty():
		last_measurement = measurement.duplicate(true); last_measurement["interrupted"] = true; measurement.clear()
	interacting = false
	stretch_requested = false
	if stretch_audio: stretch_audio.stop()
	finish_launch(); retract.clear(); vibration.clear(); pending_shot.clear(); pulling = false; engaged = false
	hold_time = 0; engaged_side = 0
	if is_instance_valid(wolf):
		if wolf.elastic_motion_owner==self: wolf.elastic_motion_owner = null
		if wolf.elastic_pull_controller==self: wolf.elastic_pull_controller = null
	if mode=="pulled": mode = "strung"

func reset_item():
	cancel_motion(); mode = "item"; tree_a = null; tree_b = null; tension = 0
	if band: band.hide()

func on_respawn():
	cancel_motion()
	# Wolf::StoreActiveItemInInventory resets/stores the active object, then
	# Inventory_Add. Checkpoint loading instead reconstructs its saved anchors.
	var save = wolf.get_parent().get_node_or_null("CheckpointSave")
	if save and save.restoring: return
	if mode=="one":
		reset_item()
		item.available = false
		item.owning_inventory = wolf.inventory
		item.original_visual.show()
		item.store()
		var record = inventory_record.duplicate(true)
		if record.is_empty(): record = {"id":item.item_id,"class_id":42,"label":item.item_label,"icon":item.icon_path,"kept":item.kept}
		wolf.inventory.pickup_nodes[item.item_id] = item
		if not wolf.inventory.state.items.has(item.item_id): wolf.inventory.state.add(record)

func capture_state() -> Dictionary:
	return {"a":int(tree_a.get_meta("original_resource",-1)) if is_instance_valid(tree_a) else -1,
		"b":int(tree_b.get_meta("original_resource",-1)) if is_instance_valid(tree_b) else -1,
		"kept":bool(inventory_record.get("kept",item.kept))}

func restore_saved_state(record: Dictionary):
	reset_item()
	inventory_record = {"id":item.item_id,"class_id":42,"label":item.item_label,"icon":item.icon_path,"kept":bool(record.get("kept",item.kept))}
	for tree in get_tree().get_nodes_in_group("elastic_trees"):
		if tree.get_world_3d()!=get_world_3d(): continue
		if int(tree.get_meta("original_resource",-1))==int(record.get("a",-2)): tree_a = tree
		if int(tree.get_meta("original_resource",-1))==int(record.get("b",-2)): tree_b = tree
	if is_instance_valid(tree_a):
		mode = "strung" if is_instance_valid(tree_b) else "one"
		item.available = false; item.holder = null; item.deployed = true
		item.show(); item.original_visual.hide(); draw_band()

func _exit_tree(): cancel_motion()

func measure_trip(delta: float):
	if mode!="one" or not is_instance_valid(tree_a): return
	var below = tree_a.anchor().y-wolf.global_position.y
	if measurement.is_empty() and not wolf.is_on_floor() and (wolf.velocity.y<-.1 or wolf.current_state==wolf.WolfState.FALL):
		measurement = {"elapsed":0.0,"descent":0.0,"return":0.0,"interaction":0.0,"return_started":false}
	if measurement.is_empty(): return
	measurement.elapsed += delta
	if not retract.is_empty():
		measurement.return_started = true; measurement["return"] += delta
	elif measurement.return_started: measurement["return"] += delta
	elif wolf.item_actions.busy: measurement.interaction += delta
	elif not measurement.return_started: measurement.descent += delta
	if measurement.return_started and retract.is_empty() and wolf.is_on_floor() and wolf.ground_drop()<.15 and below<1.6:
		last_measurement = measurement.duplicate(true); measurement.clear()

func tuning_values() -> Dictionary:
	return {"max_length":max_length,"two_anchor_max_length":two_anchor_max_length,
		"full_charge_threshold":full_charge_threshold,"minimum_launch_charge":minimum_launch_charge,
		"automatic_launch_hold":automatic_launch_hold,"return_speed":return_speed,
		"spring_strength":spring_strength,"projection_distance":projection_distance,
		"projection_height":projection_height,"projection_speed":projection_speed}

func apply_tuning(values: Dictionary):
	for key in tuning_values():
		if values.has(key): set(key,float(values[key]))
	tension = 0; hold_time = 0
