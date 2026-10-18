extends Node
class_name OriginalItemActions

# Wolf::FaceTargetActionStep and ItemFly_Start / Inventory_UpdateFx.
var actor: RalphController
var stages: Array = []
var index = 0
var time = 0.0
var busy = false
var cleanup = Callable()
var previously_locked = false
var completion = Callable()

func _ready() -> void:
	actor = get_parent()
	process_priority = 90

func begin(sequence: Array, on_cancel: Callable = Callable(), on_finish: Callable = Callable()) -> bool:
	if busy or not actor.can_use_inventory(): return false
	actor.interrupt_actions()
	previously_locked = actor.cinematic_controls_locked
	actor.cinematic_controls_locked = true
	stages = sequence
	cleanup = on_cancel
	completion = on_finish
	busy = true
	index = 0
	_enter()
	return true

func _enter() -> void:
	time = 0
	var stage: Dictionary = stages[index]
	actor.play_anim(stage.get("clip","idle"))
	if stage.has("enter"): stage["enter"].call()

func _process(delta: float) -> void:
	if not busy: return
	var stage: Dictionary = stages[index]
	var clip: String = stage.get("clip","idle")
	var duration: float = stage.get("duration",actor.animation_player.get_animation(clip).length)
	var previous = time
	time = minf(time+delta,duration)
	actor.animation_player.seek(minf(time,actor.animation_player.get_animation(clip).length),true)
	actor.animation_player.advance(0)
	actor.legacy_skin.update_pose()
	if stage.has("step"): stage["step"].call(time,duration)
	if actor.run_data["animations"].has(clip):
		for cue in actor.run_data["animations"][clip]["sound_cues"]:
			if float(cue["time"]) > previous-0.0001 and float(cue["time"]) <= time:
				var sound = actor.run_data["sounds"].get(str(int(cue["sound_id"])))
				if sound: actor.play_animation_sfx(sound["path"])
	if time >= duration:
		if stage.has("exit"): stage["exit"].call()
		index += 1
		if index < stages.size(): _enter()
		else: _finish()

func _finish(natural: bool = true) -> void:
	var callback = completion
	completion = Callable()
	busy = false
	stages.clear()
	cleanup = Callable()
	actor.cinematic_controls_locked = previously_locked
	actor.set_state(actor.WolfState.IDLE)
	if is_instance_valid(actor.push_target): actor.play_anim("push_loop")
	else: actor.original_idle.reset(actor)
	if natural and callback.is_valid(): callback.call()

func cancel() -> void:
	if not busy: return
	var callback = cleanup
	_finish(false)
	if callback.is_valid(): callback.call()

func pickup(item: GameItem, inventory: Node) -> bool:
	if inventory.state.items.has(item.item_id): return false
	var origin = item.global_position
	var added = [false]
	var start_flight = [Vector3.ZERO]
	var sequence = [
		{"clip":"pickup_start", "enter":func():
			item.available = false
			item.hint.hide()
			face(item.global_position),
		"exit":func():
			added[0] = inventory.add_item({"id":item.item_id,"class_id":item.class_id,"label":item.item_label,"icon":item.icon_path,"kept":item.kept},item,false)
			item.owning_inventory = inventory
			start_flight[0] = item.global_position
			inventory.wheel.set_open(true)},
		{"clip":"pickup_end", "step":func(t: float,_duration: float):
			# 4096 / 9600 seconds; original effect uses camera space (0,-120,384).
			var progress = clampf(t/(4096.0/9600.0),0,1)
			var camera = actor.get_viewport().get_camera_3d()
			item.global_position = start_flight[0].lerp(camera.global_transform*Vector3(0,1.2,-3.84),progress)
			item.visible = progress < 1,
		"exit":func():
			item.store()
			inventory.wheel.set_open(false)}]
	return begin(sequence,func():
		inventory.wheel.set_open(false)
		if added[0]: item.store()
		else:
			item.global_position = origin
			item.available = true
			item.show()
			item.hint.visible = false)

func face(point: Vector3) -> void:
	var direction = point-actor.global_position
	if Vector2(direction.x,direction.z).length() > 0.01:
		actor.skeleton.rotation.y = atan2(direction.x,direction.z)

func equip(item: GameItem, previous: GameItem) -> bool:
	if busy or not actor.can_use_inventory(): return false
	var sequence: Array = []
	if is_instance_valid(previous):
		var origin = previous.global_position
		previous.deactivate()
		previous.holder = null
		sequence.append({"clip":"item_stow","step":func(t: float,_duration: float):
			var camera = actor.get_viewport().get_camera_3d()
			var progress = clampf(t/(4096.0/9600.0),0,1)
			previous.global_position = origin.lerp(camera.global_transform*Vector3(0,1.2,-3.84),progress)
			previous.visible = progress < 1,
		"exit":func(): previous.store()})
	if is_instance_valid(item):
		sequence.append({"clip":"item_take_out","enter":func():
			item.show()
			item.hint.hide()
			if item.has_method("prepare_held_visual"): item.prepare_held_visual(),
		"step":func(t: float,_duration: float):
			var target = item.attachment_transform(actor) if item.has_method("attachment_transform") else Transform3D(Basis.IDENTITY,actor.item_hand_position())
			var camera = actor.get_viewport().get_camera_3d()
			item.global_transform = target
			item.global_position = (camera.global_transform*Vector3(0,1.2,-3.84)).lerp(target.origin,clampf(t/(4096.0/9600.0),0,1)),
		"exit":func(): item.equip_to(actor)})
	if sequence.is_empty(): return false
	return begin(sequence,func():
		if is_instance_valid(previous): previous.store()
		if is_instance_valid(item): item.equip_to(actor))
