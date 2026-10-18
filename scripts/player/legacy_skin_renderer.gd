extends RefCounted
class_name LegacySkinRenderer

const Rules = preload("res://scripts/player/ralph_run_rules.gd")
const Space = preload("res://scripts/levels/game_space.gd")
var skeleton: Skeleton3D
var inverse_rests: Array[Transform3D] = []
var materials: Array[ShaderMaterial] = []
var last_matrices: Array[Transform3D] = []

func setup(node: Skeleton3D, instance: MeshInstance3D) -> void:
	skeleton = node
	var global_rests: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()):
		var parent = skeleton.get_bone_parent(bone)
		var rest = skeleton.get_bone_rest(bone)
		if parent >= 0:
			rest = global_rests[parent] * rest
		global_rests.append(rest)
		inverse_rests.append(rest.affine_inverse())
	var source: ArrayMesh = instance.mesh
	var mesh = ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(surface)
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var custom = PackedFloat32Array()
		for vertex in range(arrays[Mesh.ARRAY_VERTEX].size()):
			# WAR parts have exactly one joint per vertex.
			assert(is_equal_approx(weights[vertex*4], 1.0))
			custom.append_array(PackedFloat32Array([float(bones[vertex*4]), 0, 0, 0]))
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var material: ShaderMaterial = source.surface_get_material(surface).duplicate()
		material.set_shader_parameter("use_legacy_skin", true)
		materials.append(material)
		mesh.surface_set_name(surface, source.surface_get_name(surface))
		mesh.surface_set_material(surface, material)
	instance.mesh = mesh
	instance.skin = null
	instance.skeleton = NodePath("")
	instance.custom_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	update_pose()

func update_pose() -> void:
	var parents: Array[int] = []
	var rests: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	var positions: Array[Vector3] = []
	var scales: Array[Vector3] = []
	for bone in range(skeleton.get_bone_count()):
		parents.append(skeleton.get_bone_parent(bone))
		rests.append(skeleton.get_bone_rest(bone).origin)
		rotations.append(skeleton.get_bone_pose_rotation(bone))
		positions.append(skeleton.get_bone_pose_position(bone))
		scales.append(skeleton.get_bone_pose_scale(bone))
	last_matrices = Rules.reaction_pose_transforms(parents, rests, rotations, positions, scales)
	# Poses/bind vertices retain original exported coordinates internally.
	# Convert the evaluated result once, including hand attachment positions.
	for bone in range(last_matrices.size()):
		last_matrices[bone] = Space.exported_pose(last_matrices[bone])
	var palette: Array[Transform3D] = []
	for bone in range(last_matrices.size()):
		palette.append(last_matrices[bone] * inverse_rests[bone])
	while palette.size() < 32:
		palette.append(Transform3D.IDENTITY)
	for material in materials:
		material.set_shader_parameter("legacy_joint_palette", palette)
