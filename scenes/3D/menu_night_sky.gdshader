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
	color += vec3(0.035, 0.105, 0.135) * smoothstep(0.55, 0.80, cloud) * (0.4 + haze);
	float star = step(0.995, hash(floor(d * 420.0)));
	color += vec3(0.42, 0.72, 0.81) * star * smoothstep(-0.04, 0.3, d.y);
	COLOR = color;
}
