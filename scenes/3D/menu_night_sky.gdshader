shader_type sky;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y), mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float haze = 1.0 - smoothstep(-0.12, 0.55, abs(d.y));
	float cloud = noise(d * 5.0 + vec3(TIME * 0.008, 0.0, 0.0)) * 0.6 + noise(d * 12.0 - vec3(TIME * 0.015, 0.0, 0.0)) * 0.4;
	vec3 color = mix(vec3(0.005, 0.017, 0.043), vec3(0.016, 0.100, 0.132), haze);
	color += vec3(0.045, 0.11, 0.14) * smoothstep(0.38, 0.72, cloud) * (0.4 + haze);
	vec2 star_uv = vec2(atan(d.z, d.x) / 6.283185 + 0.5, asin(clamp(d.y, -1.0, 1.0)) / 3.141593 + 0.5);
	vec2 star_position = star_uv * vec2(500.0, 220.0);
	vec2 star_cell = floor(star_position);
	vec2 star_center = vec2(hash(vec3(star_cell, 21.0)), hash(vec3(star_cell, 47.0)));
	float star = step(0.991, hash(vec3(star_cell, 73.0))) * (1.0 - smoothstep(0.02, 0.15, length(fract(star_position) - star_center)));
	color += vec3(0.70, 0.87, 0.92) * star * smoothstep(-0.02, 0.10, d.y);
	COLOR = color;
}
