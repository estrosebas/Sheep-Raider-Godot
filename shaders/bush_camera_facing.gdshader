shader_type spatial;
// ARCHIVED billboard experiment: rotates foliage after skinning. Discarded
// because the requested fix was rear-layer occlusion, not camera-facing art.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, fog_disabled;
#include "legacy_color.gdshaderinc"
uniform bool use_legacy_skin = false;
uniform mat4 legacy_joint_palette[32];
void vertex() {
	vec3 point = VERTEX;
	if (use_legacy_skin) point = (legacy_joint_palette[int(CUSTOM0.x)]*vec4(point,1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX*vec4(point,1.0)).xyz;
	vec3 toward_camera = INV_VIEW_MATRIX[3].xyz-origin;
	float camera_yaw = atan(toward_camera.x,toward_camera.z);
	float actor_yaw = atan(MODEL_MATRIX[2].x,MODEL_MATRIX[2].z);
	float angle = camera_yaw-actor_yaw;
	vec3 offset = world-origin;
	float c = cos(angle), s = sin(angle);
	offset.xz = mat2(vec2(c,-s),vec2(s,c))*offset.xz;
	POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(origin+offset,1.0);
}
void fragment() {
	vec4 t = sample_page(UV);
	if (!use_linear_filter && t.a < 0.03) discard;
	ALBEDO = legacy_output(t.rgb*COLOR.rgb*vertex_color_scale);
	ALPHA = t.a;
}
