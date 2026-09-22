shader_type canvas_item;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 local = fract(value);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

float fbm(vec2 value) {
	float result = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		result += noise(value) * amplitude;
		value = value * 2.03 + 17.0;
		amplitude *= 0.5;
	}
	return result;
}

float ember(vec2 uv, float seed) {
	float lane = floor(uv.x * 42.0 + seed);
	float offset = hash(vec2(lane, seed));
	float progress = fract(TIME * (0.035 + hash(vec2(seed, lane)) * 0.03) + offset);
	float x = (lane + 0.5) / 42.0 + sin(progress * 8.0 + offset * 18.0) * 0.012;
	float y = 0.93 - progress * (0.42 + hash(vec2(lane, seed + 4.0)) * 0.42);
	float size = mix(0.0018, 0.0045, hash(vec2(lane, seed + 8.0))) * (1.0 - progress * 0.55);
	float distance_to_ember = length((uv - vec2(x, y)) * vec2(0.75, 1.0));
	return smoothstep(size, size * 0.22, distance_to_ember) * smoothstep(1.0, 0.15, progress);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(vec3(0.018, 0.012, 0.028), vec3(0.12, 0.025, 0.03), uv.y);

	float haze = fbm(vec2(uv.x * 3.0, uv.y * 6.0 + TIME * 0.012));
	color += vec3(0.055, 0.012, 0.008) * smoothstep(0.24, 0.78, haze) * (1.0 - uv.y) * 0.55;

	float cloud_far_noise = fbm(vec2(uv.x * 2.4 + TIME * 0.006, uv.y * 8.0));
	float cloud_near_noise = fbm(vec2(uv.x * 3.8 - TIME * 0.009, uv.y * 10.0 + 9.0));
	float cloud_fade = 1.0 - smoothstep(0.15, 0.48, uv.y);
	float cloud_far = smoothstep(0.43, 0.72, cloud_far_noise) * cloud_fade;
	float cloud_near = smoothstep(0.50, 0.76, cloud_near_noise) * cloud_fade;
	color = mix(color, vec3(0.085, 0.055, 0.075), cloud_far * 0.62);
	color = mix(color, vec3(0.035, 0.028, 0.045), cloud_near * 0.78);
	color += vec3(0.08, 0.018, 0.012) * cloud_far * smoothstep(0.48, 0.15, uv.y);

	float far_mountains = 0.48 + sin(uv.x * 9.0) * 0.045 + sin(uv.x * 21.0 + 1.8) * 0.025;
	float near_mountains = 0.59 + sin(uv.x * 5.3 + 0.8) * 0.075 + sin(uv.x * 15.0) * 0.035;
	float far_mask = smoothstep(far_mountains + 0.012, far_mountains - 0.012, uv.y);
	float near_mask = smoothstep(near_mountains + 0.012, near_mountains - 0.012, uv.y);
	color = mix(color, vec3(0.07, 0.02, 0.035), far_mask);
	color = mix(color, vec3(0.035, 0.012, 0.02), near_mask);

	float flame_noise = fbm(vec2(uv.x * 6.0, uv.y * 5.0 + TIME * 0.14));
	float flame_height = 0.60 + flame_noise * 0.30 + sin(uv.x * 28.0 + TIME * 0.32) * 0.055;
	float flame = smoothstep(flame_height + 0.08, flame_height - 0.08, uv.y);
	float core = smoothstep(flame_height + 0.18, flame_height - 0.13, uv.y) * smoothstep(0.36, 0.8, flame_noise);
	color = mix(color, vec3(0.48, 0.025, 0.004), flame * 0.78);
	color = mix(color, vec3(1.0, 0.18, 0.012), core * 0.85);
	color += vec3(1.0, 0.08, 0.006) * flame * (1.0 - uv.y) * 0.13;

	float sparks = ember(uv, 2.0) + ember(uv, 7.0) * 0.85 + ember(uv, 13.0) * 0.7;
	color += vec3(1.0, 0.25, 0.025) * sparks;
	COLOR = vec4(color, 1.0);
}
