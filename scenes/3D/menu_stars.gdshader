shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 1.4;
}
