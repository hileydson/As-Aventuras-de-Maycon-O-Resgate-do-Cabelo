shader_type sky;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float clouds(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float drift = TIME * 0.013;
	float mist = clouds(direction * 3.5 + vec3(drift, -drift * 0.4, 0.0));
	float tendrils = smoothstep(0.52, 0.73, clouds(direction * 11.0 + vec3(0.0, drift, drift)));
	float horizon = 1.0 - smoothstep(-0.08, 0.5, abs(direction.y));
	vec3 color = mix(vec3(0.006, 0.004, 0.018), vec3(0.035, 0.009, 0.032), mist);
	color += vec3(0.105, 0.014, 0.042) * tendrils * (0.45 + horizon * 0.55);
	color += vec3(0.09, 0.018, 0.013) * horizon * mist * mist;
	float star = step(0.997, hash(floor(direction * 420.0)));
	color += vec3(0.19, 0.12, 0.15) * star * smoothstep(0.08, 0.55, direction.y);
	COLOR = color;
}
