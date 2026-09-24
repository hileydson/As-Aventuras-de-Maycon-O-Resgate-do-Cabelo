shader_type spatial;
render_mode unshaded;

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
	float highlands = noise(UV * 18.0);
	float seas = smoothstep(0.48, 0.72, noise(UV * 7.0 + vec2(2.7, 1.4)));
	vec3 moon = vec3(0.70, 0.86, 0.91) * (0.84 + highlands * 0.17 - seas * 0.19);
	ALBEDO = moon;
	EMISSION = moon * 1.8;
}
