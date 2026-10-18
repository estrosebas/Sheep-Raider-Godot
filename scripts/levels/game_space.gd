extends RefCounted
class_name GameSpace

# Original viewer: toGL = [x, -y, -z]. JSON/OBJ exports already negate Y.
const EXPORT_TO_GODOT = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)

static func from_export(value: Vector3) -> Vector3:
	return EXPORT_TO_GODOT * value

static func original_point(value: Vector3) -> Vector3:
	return Vector3(value.x, -value.y, -value.z) * 0.01

static func exported_pose(value: Transform3D) -> Transform3D:
	return Transform3D(EXPORT_TO_GODOT * value.basis, from_export(value.origin))

static func mesh_from_export(source: ArrayMesh) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in range(vertices.size()):
			vertices[vertex] = from_export(vertices[vertex])
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for normal in range(normals.size()):
				normals[normal] = from_export(normals[normal])
			arrays[Mesh.ARRAY_NORMAL] = normals
		if arrays[Mesh.ARRAY_TANGENT] != null:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for index in range(0,tangents.size(),4):
				tangents[index+2] = -tangents[index+2]
				tangents[index+3] = -tangents[index+3]
			arrays[Mesh.ARRAY_TANGENT] = tangents
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for vertex in range(vertices.size()):
				indices.append(vertex)
		# Reflection reverses winding. Restore it for culling and collision normals.
		for triangle in range(0, indices.size(), 3):
			var swap = indices[triangle+1]
			indices[triangle+1] = indices[triangle+2]
			indices[triangle+2] = swap
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		mesh.surface_set_name(surface, source.surface_get_name(surface))
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh
