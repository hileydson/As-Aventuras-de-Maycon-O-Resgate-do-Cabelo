shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D portrait : source_color, filter_linear_mipmap;
uniform float reveal = 0.0;

void fragment() {
	vec2 sample_uv = vec2(mix(0.67, 0.98, UV.x), mix(0.22, 0.63, UV.y));
	vec3 face = texture(portrait, sample_uv).rgb;
	float oval = 1.0 - smoothstep(0.31, 0.49, length((UV - vec2(0.5)) * vec2(1.05, 1.35)));
	float cloud = sin(UV.y * 18.0 + UV.x * 8.0 + TIME * 0.13) * 0.07;
	ALBEDO = mix(face, vec3(0.45, 0.76, 0.82), 0.38);
	ALPHA = oval * (0.29 + cloud) * reveal;
}
