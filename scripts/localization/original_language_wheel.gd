extends Node3D
class_name OriginalLanguageWheel

const SELECTION_ANGLE_OFFSET = -PI/2
var order: Array = []
var selected = 0
var angle = 0.0
var entry_end_angle = 0.0
var entry_angle_offset = 0.0
var wheel: OriginalCinematicActor
var daffy: OriginalCinematicActor
var base: OriginalCinematicActor
var music: AudioStreamPlayer
var caption: Label
var elapsed = 0.0
var confirming = false
signal closed
var modal = false
var camera: Camera3D
var next_scene = SaveFiles.STUDIO_SCENE

func _ready():
	GameLocalization.ensure()
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/wheel/source.json"))
	order = source.order
	selected = maxi(0,order.find(GameLocalization.locale))
	angle = selected*PI/2
	for definition in source.actors:
		var actor = load(definition.directory+"/worn.tscn").instantiate() as OriginalCinematicActor
		add_child(actor)
		var p = definition.position
		actor.position = Vector3(p[0],p[1],p[2])
		actor.rotation.y = definition.yaw
		if int(definition["class"]) == 152: wheel = actor
		elif int(definition["class"]) == 187: daffy = actor
		else:
			base = actor
			base.sample_animation("push",0)
	music = AudioStreamPlayer.new()
	music.name = "OriginalSelectionMusic"
	var track: AudioStreamWAV = load(source.music).duplicate()
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = roundi(track.get_length()*track.mix_rate)
	music.stream = track
	music.volume_db = -12
	add_child(music)
	music.play()
	var scenery = MeshInstance3D.new()
	scenery.name = "OriginalStudioScenery"
	scenery.mesh = load("res://assets/localization/wheel/background/scenery.tres")
	add_child(scenery)
	camera = Camera3D.new()
	add_child(camera)
	# Frame the final original pose, rather than the mesh origin before PUSH.
	wheel.sample_animation("push",float(wheel.rig.animations.push.duration))
	daffy.sample_animation("push",float(daffy.rig.animations.push.duration))
	var bounds = actor_bounds(wheel).merge(actor_bounds(daffy))
	var center = bounds.get_center()
	camera.position = center+Vector3(2.66,.9,4.95)
	camera.look_at(center)
	entry_end_angle = -float(wheel.rig.animations.push.frames[-1].joints[1].rot[0])
	entry_angle_offset = angle_difference(entry_end_angle,target_angle(selected))
	angle = entry_end_angle+entry_angle_offset
	camera.fov = 40
	camera.current = true
	var canvas = CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	canvas.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -100
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",30)
	caption.add_theme_color_override("font_outline_color",Color.BLACK)
	caption.add_theme_constant_override("outline_size",4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_caption()
	if not modal:
		var transitions = get_tree().root.get_node_or_null("LanguageMenu")
		if transitions: await transitions.reveal_startup()
		var statistics = get_tree().get_first_node_in_group("optional_statistics")
		if statistics: statistics.open_if_needed()

func update_caption():
	caption.text = str(GameLocalization.manifest.languages[order[selected]].name)+"\n← / →    Enter / E"

func turn(direction: int):
	if confirming: return
	selected = posmod(selected+direction,order.size())
	update_caption()

func confirm(navigate: bool = true) -> bool:
	if confirming: return false
	if not GameLocalization.select(order[selected]): return false
	confirming = true
	if navigate:
		await get_tree().create_timer(.5).timeout
		if modal: closed.emit()
		else:
			var transitions = get_tree().root.get_node_or_null("LanguageMenu")
			if transitions: transitions.change_scene(next_scene)
			else: get_tree().change_scene_to_file(next_scene)
	return true

func _input(event):
	var transitions = get_tree().root.get_node_or_null("LanguageMenu")
	if transitions and transitions.transitioning: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_LEFT,KEY_A]: turn(-1)
	elif event.physical_keycode in [KEY_RIGHT,KEY_D]: turn(1)
	elif event.physical_keycode in [KEY_ENTER,KEY_E,KEY_SPACE]: confirm()
	elif modal and event.physical_keycode in [KEY_ESCAPE,KEY_F5]: closed.emit()
	else: return
	get_viewport().set_input_as_handled()

func _process(delta):
	elapsed += delta
	# Scene_Wheel overrides joint1 X; DaffyWheel alternates native PUSH1/PUSH2.
	wheel.sample_animation("push",minf(elapsed,float(wheel.rig.animations.push.duration)))
	# Orient the entire native rolling entrance to the remembered language.
	# This preserves PUSH angular velocity and matches the selection pose exactly.
	if elapsed < float(wheel.rig.animations.push.duration):
		entry_angle_offset = lerp_angle(entry_angle_offset,angle_difference(entry_end_angle,target_angle(selected)),minf(1,delta*8))
		var native_rotation = wheel.skeleton.get_bone_pose_rotation(1)
		wheel.skeleton.set_bone_pose_rotation(1,Quaternion(Vector3.RIGHT,-entry_angle_offset)*native_rotation)
		angle = entry_end_angle+entry_angle_offset
	else:
		angle = lerp_angle(angle,target_angle(selected),minf(1,delta*8))
		var base_rotation = wheel.rig.animations.push.frames[-1].joints[1].rot
		wheel.skeleton.set_bone_pose_rotation(1,Basis.from_euler(Vector3(-angle,base_rotation[1],-base_rotation[2]),EULER_ORDER_ZXY).get_rotation_quaternion())
	wheel.legacy_skin.update_pose()
	if elapsed < float(daffy.rig.animations.push.duration): daffy.sample_animation("push",elapsed)
	else:
		var time = elapsed-float(daffy.rig.animations.push.duration)
		var first = float(daffy.rig.animations.push1.duration)
		var second = float(daffy.rig.animations.push2.duration)
		time = fmod(time,first+second)
		daffy.sample_animation("push1" if time < first else "push2",time if time < first else time-first)

func actor_bounds(actor: OriginalCinematicActor) -> AABB:
	var bounds = AABB()
	var first = true
	for surface in actor.rig.surfaces.values():
		for i in range(surface.verts.size()):
			var v = surface.verts[i]
			var joint = int(surface.bones[i])
			var point = actor.global_transform*actor.legacy_skin.last_matrices[joint]*actor.legacy_skin.inverse_rests[joint]*Vector3(v[0],v[1],v[2])
			if first: bounds = AABB(point,Vector3.ZERO); first = false
			else: bounds = bounds.expand(point)
	return bounds

static func target_angle(index: int) -> float:
	# Atlas sectors: English +X, Brazilian -Y, Spanish -X, Italian +Y.
	# Align the chosen sector with the recovered stand's bottom pointer.
	return index*PI/2+SELECTION_ANGLE_OFFSET
