shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float pulse = 0.7;

void fragment() {
	float r = length(UV - vec2(0.5));
	float glow = exp(-r * r * 22.0) * 0.26 * pulse + exp(-r * r * 110.0) * 0.22;
	ALBEDO = vec3(0.31, 0.73, 0.88);
	ALPHA = glow * (1.0 - smoothstep(0.38, 0.5, r));
}
