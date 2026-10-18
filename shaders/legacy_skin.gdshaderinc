// The game's parts have independent scales; normal inherited skeleton scale
// deforms RUNF2's rotating feet. CUSTOM0.x contains the original joint index.
uniform bool use_legacy_skin = false;
uniform mat4 legacy_joint_palette[32];
// bipbip::Render translates the model in screen space into the painted tunnel.
// Only the independent race actor enables this; ordinary meshes use default false.
uniform bool tunnel_projection = false;
uniform vec3 tunnel_road_point;
uniform vec3 tunnel_wall_point;
uniform float tunnel_farthest_view_z = -1.0;

void vertex() {
	if (use_legacy_skin) {
		VERTEX = (legacy_joint_palette[int(CUSTOM0.x)] * vec4(VERTEX, 1.0)).xyz;
	}
	// Once POSITION is written, Godot uses it for every branch of this shader.
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	if (tunnel_projection) {
		vec4 road = PROJECTION_MATRIX * VIEW_MATRIX * vec4(tunnel_road_point,1.0);
		vec4 wall = PROJECTION_MATRIX * VIEW_MATRIX * vec4(tunnel_wall_point,1.0);
		vec4 farthest = PROJECTION_MATRIX * vec4(0.0,0.0,tunnel_farthest_view_z,1.0);
		vec4 clip = POSITION;
		clip.xy += (wall.xy/wall.w-road.xy/road.w)*clip.w;
		clip.z += (wall.z/wall.w-farthest.z/farthest.w)*clip.w;
		POSITION = clip;
	}
}
