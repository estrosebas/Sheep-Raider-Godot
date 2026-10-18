extends Node3D
class_name OriginalCinematicActor

const LegacySkin = preload("res://scripts/player/legacy_skin_renderer.gd")
@export var asset_directory: String
var rig: Dictionary
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var legacy_skin: RefCounted
var idle_clip = ""
var idle_time = 0.0
var idle_speed = 1.0
var static_shape: CollisionShape3D
var movie_shown = false

func _ready() -> void:
	rig = JSON.parse_string(FileAccess.get_file_as_string(asset_directory+"/worn_data.json"))
	if bool(rig.get("static",false)):
		var visual = MeshInstance3D.new()
		visual.mesh = load(asset_directory+"/worn.tres")
		add_child(visual)
		# Cinematic-only classless scenery is collidable only when its original
		# model supplies solid boxes. Decorative CIN 3 fragments have none.
		for box in rig.get("collision_boxes",[]):
			var body = StaticBody3D.new()
			static_shape = CollisionShape3D.new()
			var a = box["min"]
			var b = box["max"]
			var lo = GameSpace.original_point(Vector3(a[0],b[1],b[2]))
			var hi = GameSpace.original_point(Vector3(b[0],a[1],a[2]))
			var shape = BoxShape3D.new()
			shape.size = hi-lo
			static_shape.shape = shape
			static_shape.position = (lo+hi)/2
			static_shape.disabled = true
			body.add_child(static_shape)
			add_child(body)
		return
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	for index in range(rig["joints"].size()):
		var joint = rig["joints"][index]
		var offset = joint["offset"]
		skeleton.add_bone("joint_%02d" % index)
		skeleton.set_bone_parent(index,int(joint["parent"]))
		var rest = Transform3D(Basis.IDENTITY,Vector3(offset[0],offset[1],offset[2]))
		skeleton.set_bone_rest(index,rest)
		skeleton.set_bone_pose_position(index,rest.origin)
	var mesh = MeshInstance3D.new()
	mesh.name = "Visual"
	mesh.mesh = load(asset_directory+"/worn.tres")
	skeleton.add_child(mesh)
	legacy_skin = LegacySkin.new()
	legacy_skin.setup(skeleton,mesh)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animation_player)
	animation_player.add_animation_library("",load(asset_directory+"/animations.tres"))

func sample_animation(clip: String, time: float, looping: bool = false) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(clip):
		return
	if animation_player.current_animation != clip:
		animation_player.play(clip)
	var duration = animation_player.get_animation(clip).length
	animation_player.seek(fmod(time,duration) if looping and duration > 0 else minf(time,duration),true)
	animation_player.advance(0)
	legacy_skin.update_pose()

func movie_visibility(shown: bool) -> void:
	visible = shown
	if static_shape and movie_shown != shown:
		static_shape.set_deferred("disabled",not shown)
	movie_shown = shown

func idle(clip: String) -> void:
	idle_clip = clip
	idle_time = 0

func _process(delta: float) -> void:
	if not idle_clip.is_empty():
		idle_time += delta*idle_speed
		sample_animation(idle_clip,idle_time,true)
