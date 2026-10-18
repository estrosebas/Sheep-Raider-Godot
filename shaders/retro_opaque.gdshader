shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, unshaded, fog_disabled;

#include "legacy_color.gdshaderinc"
#include "legacy_skin.gdshaderinc"

uniform bool is_textured = true;

void fragment() {
	vec3 c = COLOR.rgb * vertex_color_scale;
	if (is_textured) {
		// DAV kind 4 ignores alpha, including ARGB1555 pixels.
		c *= sample_page(UV).rgb;
	}
	ALBEDO = legacy_output(c);
}
