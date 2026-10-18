shader_type spatial;
// LAB ONLY. The native DAV166 tile is opaque; test removing its green fill
// without changing the source pixels or alpha-blending intersecting sheets.
render_mode depth_draw_opaque, cull_disabled, unshaded, fog_disabled;
#include "../legacy_color.gdshaderinc"
void fragment() {
	vec4 leaf = sample_page(UV);
	if (leaf.g > leaf.r * 1.08 && leaf.g > leaf.b * 1.8) discard;
	ALBEDO = legacy_output(leaf.rgb * COLOR.rgb * vertex_color_scale);
}
