shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;
#include "legacy_color.gdshaderinc"
void vertex() {
	// WorldObj_DrawSky removes camera translation. Keep rotation and source size.
	vec4 view_position = VIEW_MATRIX * vec4(VERTEX, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(view_position.xyz, 1.0);
	// Draw behind world geometry, without writing depth or introducing parallax.
	// Godot uses reversed Z: far is -1 in Compatibility, 0 in Forward+/Mobile.
	// +1 is the NEAR plane in Compatibility and would cover the entire map.
	POSITION.z = (CLIP_SPACE_FAR + 0.000001) * POSITION.w;
}
void fragment() {
	ALBEDO = legacy_output(COLOR.rgb);
}
