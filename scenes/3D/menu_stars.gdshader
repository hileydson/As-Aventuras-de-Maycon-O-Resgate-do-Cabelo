shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

void fragment() {
	float radius = length(UV - vec2(0.5));
	ALBEDO = COLOR.rgb;
	ALPHA = (1.0 - smoothstep(0.08, 0.5, radius)) * COLOR.a;
}
