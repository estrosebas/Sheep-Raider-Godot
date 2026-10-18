extends Node3D
class_name CostumeVisual

const Rules = preload("res://scripts/player/ralph_run_rules.gd")
const LegacySkin = preload("res://scripts/player/legacy_skin_renderer.gd")
@export var asset_directory = "res://assets/items/sheep_costume"
var actor: Node3D
var rig: Dictionary
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var action_time = 0.0
var legacy_skin: RefCounted

func _ready() -> void:
	process_priority = 110
	rig = JSON.parse_string(FileAccess.get_file_as_string(asset_directory + "/worn_data.json"))
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	var global_rests: Array[Transform3D] = []
	var skin = Skin.new()
	for bone in range(rig["joints"].size()):
		var joint = rig["joints"][bone]
		var offset = joint["offset"]
		var rest = Transform3D(Basis.IDENTITY, Vector3(offset[0], offset[1], offset[2]))
		skeleton.add_bone("joint_%02d" % bone)
		skeleton.set_bone_parent(bone, int(joint["parent"]))
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)
		var global_rest = rest if int(joint["parent"]) < 0 else global_rests[int(joint["parent"])] * rest
		global_rests.append(global_rest)
		skin.add_bind(bone, global_rest.affine_inverse())
	var mesh = MeshInstance3D.new()
	mesh.mesh = load(asset_directory + "/worn.tres")
	mesh.skin = skin
	mesh.skeleton = NodePath("..")
	skeleton.add_child(mesh)
	legacy_skin = LegacySkin.new()
	legacy_skin.setup(skeleton, mesh)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.root_node = NodePath("..")
	animation_player.add_animation_library("", load(asset_directory + "/animations.tres"))
	animation_player.play("idle")

func perform_action() -> void:
	if animation_player.has_animation("action"):
		action_time = animation_player.get_animation("action").length
		animation_player.play("action")

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not skeleton:
		return
	rotation.y = actor.skeleton.rotation.y
	action_time = maxf(0.0, action_time - delta)
	var desired = "idle"
	if action_time > 0.0:
		desired = "action"
	elif actor.current_state == actor.WolfState.JUMP:
		desired = "jump"
	elif actor.current_state == actor.WolfState.FALL:
		desired = "fall"
	elif actor.current_state == actor.WolfState.SNEAK:
		desired = "sneak" if animation_player.has_animation("sneak") else "walk"
	elif Vector2(actor.velocity.x, actor.velocity.z).length() > 0.1:
		desired = "walk"
	if animation_player.has_animation(desired) and animation_player.current_animation != desired:
		skeleton.clear_bones_global_pose_override()
		animation_player.play(desired)
	legacy_skin.update_pose()
