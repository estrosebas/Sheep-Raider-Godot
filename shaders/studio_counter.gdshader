shader_type spatial;
// Native counter hides unused seven-segment faces by turning them 180 degrees.
render_mode depth_draw_opaque, cull_back, unshaded, fog_disabled;
#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"
uniform bool is_textured = true;
void fragment() {
	vec3 c = COLOR.rgb * vertex_color_scale;
	if (is_textured) c *= sample_page(UV).rgb;
	ALBEDO = legacy_output(c);
}
