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

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float position_on_segment = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return length(point - start - segment * position_on_segment);
}

vec3 fire_comet(vec2 uv, float phase, float period, float height, float direction_sign) {
	float cycle = fract(TIME / period + phase);
	float head_active = smoothstep(0.0, 0.012, cycle) * (1.0 - smoothstep(0.17, 0.20, cycle));
	float trail_life = smoothstep(0.0, 0.015, cycle) * (1.0 - smoothstep(0.19, 0.43, cycle));
	float progress = clamp(cycle / 0.18, 0.0, 1.0);
	float start_x = mix(1.16, -0.16, step(0.0, direction_sign));
	vec2 direction = normalize(vec2(direction_sign, -0.13));
	vec2 start_position = vec2(start_x, height);
	vec2 comet_position = vec2(start_x + direction_sign * progress * 1.32, height - progress * 0.10);
	vec2 difference = uv - comet_position;
	float projected = dot(difference, direction);
	float behind = 1.0 - step(0.0, projected);
	float trail_length = max(-projected, 0.0);
	float trail_width = abs(dot(difference, vec2(-direction.y, direction.x)));
	float head = smoothstep(0.015, 0.0015, length(difference));
	float aura = smoothstep(0.035, 0.004, length(difference));
	float moving_trail = exp(-trail_width * 105.0) * exp(-trail_length * 4.5) * behind;
	float moving_core = exp(-trail_width * 285.0) * exp(-trail_length * 8.0) * behind;
	float scar_distance = segment_distance(uv, start_position, comet_position);
	float scar_noise = 0.62 + noise(uv * vec2(95.0, 38.0) + vec2(TIME * 0.18, -TIME * 0.07)) * 0.72;
	float sky_scar = exp(-scar_distance * 43.0) * scar_noise;
	float scar_core = exp(-scar_distance * 135.0) * scar_noise;
	vec3 result = vec3(1.0, 0.08, 0.004) * aura * 0.82 * head_active;
	result += vec3(1.0, 0.78, 0.24) * head * 1.65 * head_active;
	result += vec3(1.0, 0.10, 0.004) * moving_trail * 1.05 * head_active;
	result += vec3(1.0, 0.52, 0.04) * moving_core * 0.72 * head_active;
	result += vec3(0.78, 0.025, 0.002) * sky_scar * 0.9 * trail_life;
	result += vec3(1.0, 0.27, 0.008) * scar_core * 0.8 * trail_life;
	return result;
}

vec3 fire_bird(vec2 uv, float phase, float period, vec2 start, vec2 end, float size) {
	float cycle = fract(TIME / period + phase);
	float active = smoothstep(0.0, 0.035, cycle) * (1.0 - smoothstep(0.64, 0.69, cycle));
	float progress = clamp(cycle / 0.66, 0.0, 1.0);
	vec2 bird_position = mix(start, end, progress);
	vec2 direction = normalize(end - start);
	vec2 side = vec2(-direction.y, direction.x);
	vec2 difference = uv - bird_position;
	vec2 local = vec2(dot(difference, direction), dot(difference, side)) / size;
	float wing_height = 0.48 + sin(TIME * 1.9 + phase * 31.0) * 0.30;
	float wing_1 = segment_distance(local, vec2(0.12, 0.0), vec2(-0.92, wing_height));
	float wing_2 = segment_distance(local, vec2(0.12, 0.0), vec2(-0.92, -wing_height));
	float body = segment_distance(local, vec2(-0.42, 0.0), vec2(0.52, 0.0));
	float bird_shape = smoothstep(0.19, 0.035, min(body, min(wing_1, wing_2)));
	float bird_core = smoothstep(0.085, 0.018, min(body, min(wing_1, wing_2)));
	float projected = dot(difference, direction);
	float behind = 1.0 - step(0.0, projected);
	float trail_length = max(-projected, 0.0);
	float trail_width = abs(dot(difference, side));
	float trail = exp(-trail_width / (size * 0.36)) * exp(-trail_length / (size * 4.8)) * behind;
	vec3 result = vec3(1.0, 0.10, 0.005) * (bird_shape + trail * 0.48);
	result += vec3(1.0, 0.72, 0.12) * bird_core * 1.2;
	return result * active;
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(vec3(0.018, 0.012, 0.028), vec3(0.12, 0.025, 0.03), uv.y);

	float haze = fbm(vec2(uv.x * 3.0, uv.y * 6.0 + TIME * 0.012));
	color += vec3(0.055, 0.012, 0.008) * smoothstep(0.24, 0.78, haze) * (1.0 - uv.y) * 0.55;

	float far_mountains = 0.48 + sin(uv.x * 9.0) * 0.045 + sin(uv.x * 21.0 + 1.8) * 0.025;
	float near_mountains = 0.59 + sin(uv.x * 5.3 + 0.8) * 0.075 + sin(uv.x * 15.0) * 0.035;
	float far_mask = smoothstep(far_mountains - 0.012, far_mountains + 0.012, uv.y);
	float near_mask = smoothstep(near_mountains - 0.012, near_mountains + 0.012, uv.y);
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

	color += fire_comet(uv, 0.82, 38.0, 0.18, 1.0);
	color += fire_comet(uv, 0.36, 61.0, 0.34, -1.0);
	color += fire_bird(uv, 0.16, 21.0, vec2(-0.08, 0.40), vec2(1.08, 0.27), 0.020);
	color += fire_bird(uv, 0.48, 27.0, vec2(0.72, 1.08), vec2(0.56, -0.08), 0.018);
	color += fire_bird(uv, 0.79, 31.0, vec2(1.08, 0.24), vec2(-0.08, 0.42), 0.016);
	COLOR = vec4(color, 1.0);
}
