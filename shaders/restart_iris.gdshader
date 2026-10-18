shader_type canvas_item;

uniform bool iris_enabled = false;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (iris_enabled) {
		// Pixel coordinates preserve a round aperture on any aspect ratio.
		vec2 half_screen = vec2(0.5) / SCREEN_PIXEL_SIZE;
		float radius = length(half_screen) * (1.0 - amount);
		float distance_from_center = length((SCREEN_UV - vec2(0.5)) / SCREEN_PIXEL_SIZE);
		float mask = smoothstep(radius - 0.5, radius + 0.5, distance_from_center);
		if (amount <= 0.0) mask = 0.0;
		if (amount >= 1.0) mask = 1.0;
		COLOR = vec4(0.0, 0.0, 0.0, mask);
	}
}
