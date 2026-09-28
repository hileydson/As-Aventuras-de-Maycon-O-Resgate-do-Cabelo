shader_type canvas_item;
render_mode unshaded;

uniform vec3 bird_color : source_color = vec3(0.14, 0.20, 0.30);

float bird_shape(vec2 uv, float phase, float period, vec2 start, vec2 end, float size) {
	float cycle = fract(TIME / period + phase);
	vec2 current = mix(start, end, cycle);
	vec2 diff = uv - current;
	float horizontal_extent = size * 1.5;
	float vertical_extent = size * 0.9;
	if (abs(diff.x * 5.2) > horizontal_extent * 5.2 || abs(diff.y) > vertical_extent) {
		return 0.0;
	}
	// Flapping animation with gliding pauses
	float wing_time = TIME * 8.5 + phase * 6.28;
	float flap_cycle = sin(TIME * 1.2 + phase * 3.0);
	float flap_intensity = smoothstep(-0.2, 0.3, flap_cycle); // periodic gliding
	float wing_phase = sin(wing_time) * flap_intensity;
	
	float wing_offset = abs(diff.x * 5.2 / horizontal_extent);
	float wing_arch = (1.0 - wing_offset * wing_offset) * (0.35 + 0.35 * wing_phase);
	float wing_v = -abs(diff.x * 5.2) * (0.45 + 0.3 * wing_phase) + wing_arch * size * 0.4;
	float body_line = length(vec2(diff.x * 2.6, diff.y + size * 0.05)) - size * 0.12;
	float wing_line = abs(diff.y - wing_v) - size * 0.07 * (1.0 - wing_offset * 0.6);
	float silhouette = smoothstep(size * 0.06, 0.0, min(body_line, wing_line));
	return clamp(silhouette, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	
	float birds = 0.0;
	// Flock of birds flying across the sky above everything
	birds += bird_shape(uv, 0.08, 16.0, vec2(0.18, 0.43), vec2(0.58, 0.36), 0.013);
	birds += bird_shape(uv, 0.35, 19.0, vec2(0.12, 0.49), vec2(0.62, 0.42), 0.010);
	birds += bird_shape(uv, 0.62, 22.0, vec2(0.15, 0.46), vec2(0.55, 0.39), 0.011);
	birds += bird_shape(uv, 0.82, 14.0, vec2(0.55, 0.38), vec2(0.22, 0.47), 0.012);
	birds += bird_shape(uv, 0.95, 25.0, vec2(0.65, 0.44), vec2(0.18, 0.52), 0.009);
	
	float alpha = clamp(birds, 0.0, 1.0);
	COLOR = vec4(bird_color, alpha);
}
