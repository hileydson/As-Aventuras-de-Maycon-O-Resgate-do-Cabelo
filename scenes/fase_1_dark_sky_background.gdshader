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

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 segment = end - start;
	float position_on_segment = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return length(point - start - segment * position_on_segment);
}

float dark_comet(vec2 uv, float phase, float period, float height, float direction_sign) {
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
	float head = smoothstep(0.018, 0.002, length(difference));
	float moving_trail = exp(-trail_width * 110.0) * exp(-trail_length * 4.2) * behind;
	float moving_core = exp(-trail_width * 260.0) * exp(-trail_length * 7.5) * behind;
	float scar_distance = segment_distance(uv, start_position, comet_position);
	float scar_noise = 0.65 + noise(uv * vec2(80.0, 32.0) + vec2(TIME * 0.15, -TIME * 0.06)) * 0.7;
	float sky_scar = exp(-scar_distance * 45.0) * scar_noise;
	
	float comet_mask = head * 1.5 * head_active + moving_core * 0.9 * head_active + moving_trail * 0.6 * head_active + sky_scar * 0.75 * trail_life;
	return clamp(comet_mask, 0.0, 1.0);
}

float dark_vulture(vec2 uv, float phase, float period, vec2 start, vec2 end, float size) {
	float cycle = fract(TIME / period + phase);
	float active = smoothstep(0.0, 0.035, cycle) * (1.0 - smoothstep(0.64, 0.69, cycle));
	float progress = clamp(cycle / 0.66, 0.0, 1.0);
	vec2 bird_position = mix(start, end, progress);
	vec2 direction = normalize(end - start);
	vec2 side = vec2(-direction.y, direction.x);
	vec2 difference = uv - bird_position;
	vec2 local = vec2(dot(difference, direction), dot(difference, side)) / size;
	float wing_flap = 0.92 + sin(TIME * 4.8 + phase * 31.0) * 0.26;
	float body = length((local - vec2(0.02, 0.0)) / vec2(0.70, 0.24)) - 1.0;
	float head = length(local - vec2(0.68, 0.0)) - 0.24;
	float wing_1 = segment_distance(local, vec2(0.10, 0.05), vec2(-0.38, 1.62 * wing_flap));
	float wing_2 = segment_distance(local, vec2(0.02, 0.06), vec2(-0.73, 1.38 * wing_flap));
	float wing_3 = segment_distance(local, vec2(-0.06, 0.04), vec2(-0.98, 1.05 * wing_flap));
	float wing_4 = segment_distance(local, vec2(0.10, -0.05), vec2(-0.38, -1.62 * wing_flap));
	float wing_5 = segment_distance(local, vec2(0.02, -0.06), vec2(-0.73, -1.38 * wing_flap));
	float wing_6 = segment_distance(local, vec2(-0.06, -0.04), vec2(-0.98, -1.05 * wing_flap));
	float tail_1 = segment_distance(local, vec2(-0.38, 0.0), vec2(-1.82, 0.0));
	float tail_2 = segment_distance(local, vec2(-0.32, 0.07), vec2(-1.55, 0.52));
	float tail_3 = segment_distance(local, vec2(-0.32, -0.07), vec2(-1.55, -0.52));
	float bird_dist = min(body, head);
	bird_dist = min(bird_dist, min(wing_1, min(wing_2, wing_3)));
	bird_dist = min(bird_dist, min(wing_4, min(wing_5, wing_6)));
	bird_dist = min(bird_dist, min(tail_1, min(tail_2, tail_3)));
	
	float silhouette = 1.0 - smoothstep(0.02, 0.16, bird_dist);
	return silhouette * active;
}

void fragment() {
	vec2 uv = UV;
	vec3 sky_top = vec3(0.025, 0.045, 0.095);
	vec3 sky_bottom = vec3(0.075, 0.115, 0.175);
	vec3 color = mix(sky_top, sky_bottom, uv.y);

	float haze1 = fbm(vec2(uv.x * 2.8, uv.y * 5.0 + TIME * 0.010));
	color += vec3(0.022, 0.038, 0.058) * smoothstep(0.25, 0.75, haze1) * (1.0 - uv.y * 0.5);

	float haze2 = fbm(vec2(uv.x * 5.0 + 12.0, uv.y * 4.2 - TIME * 0.015));
	float storm_clouds = smoothstep(0.35, 0.85, haze2);
	color = mix(color, vec3(0.040, 0.065, 0.105), storm_clouds * 0.65);

	float horizon_band = smoothstep(0.55, 0.95, uv.y) * (1.0 - smoothstep(0.95, 1.05, uv.y));
	color = mix(color, vec3(0.055, 0.085, 0.135), horizon_band * 0.5);

	float comet = dark_comet(uv, 0.82, 38.0, 0.18, 1.0);
	comet += dark_comet(uv, 0.36, 61.0, 0.34, -1.0);
	color = mix(color, vec3(0.006, 0.010, 0.018), clamp(comet * 0.9, 0.0, 1.0));

	float vultures = dark_vulture(uv, 0.16, 21.0, vec2(-0.08, 0.40), vec2(1.08, 0.27), 0.0085);
	vultures += dark_vulture(uv, 0.48, 27.0, vec2(0.72, 1.08), vec2(0.56, -0.08), 0.0078);
	vultures += dark_vulture(uv, 0.79, 31.0, vec2(1.08, 0.24), vec2(-0.08, 0.42), 0.0072);
	vec3 vulture_color = vec3(0.008, 0.012, 0.018);
	color = mix(color, vulture_color, clamp(vultures, 0.0, 1.0));

	COLOR = vec4(color, 1.0);
}
