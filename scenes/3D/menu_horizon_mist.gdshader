shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 drift = UV * vec2(7.0, 2.8) + vec2(TIME * 0.012, 0.0);
	float cloud = noise(drift) * 0.7 + noise(drift * 2.4) * 0.3;
	float edge = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.48, 0.96, UV.y));
	ALBEDO = vec3(0.13, 0.35, 0.40);
	ALPHA = smoothstep(0.30, 0.68, cloud) * edge * 0.08;
}
