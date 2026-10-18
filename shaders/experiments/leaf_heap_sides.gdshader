shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, unshaded, fog_disabled;
#include "../legacy_color.gdshaderinc"
uniform bool remove_green = false;
void fragment() {
	// New side geometry tiles only DAV166, never neighboring atlas rectangles.
	vec2 tile_uv = vec2(.75,.25) + (vec2(.5) + fract(UV)*63.0)/256.0;
	vec4 leaf = sample_page(tile_uv);
	if (remove_green && leaf.g > leaf.r * 1.08 && leaf.g > leaf.b * 1.8) discard;
	ALBEDO = legacy_output(leaf.rgb * COLOR.rgb * vertex_color_scale);
}
