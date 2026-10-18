@tool
extends Skeleton3D

# Use the runtime's original WAR skinning in the editor as well. Ordinary
# Godot skinning cannot reproduce the independent scale of these mesh parts.
var preview_skin: LegacySkinRenderer

func _ready() -> void:
	if Engine.is_editor_hint(): call_deferred("_setup_preview")

func _setup_preview() -> void:
	if not Engine.is_editor_hint() or preview_skin: return
	var mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh or not mesh.mesh: return
	for bone in range(get_bone_count()):
		set_bone_pose_position(bone,get_bone_rest(bone).origin)
	preview_skin = LegacySkinRenderer.new()
	preview_skin.setup(self,mesh)
	var animation = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation and animation.has_animation("idle"):
		animation.play("idle")
		animation.seek(0,true)
		animation.advance(0)
		animation.pause()
	preview_skin.update_pose()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and preview_skin: preview_skin.update_pose()
