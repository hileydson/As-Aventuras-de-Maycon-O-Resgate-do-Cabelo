shader_type canvas_item;
render_mode unshaded;

uniform vec4 mountain_color : source_color = vec4(0.08, 0.02, 0.035, 1.0);
uniform vec4 rim_color : source_color = vec4(0.42, 0.055, 0.018, 1.0);
uniform float horizon : hint_range(0.2, 0.8) = 0.52;
uniform float mountain_height : hint_range(0.05, 0.4) = 0.22;
uniform float peak_count : hint_range(3.0, 20.0) = 9.0;
uniform float seed = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;

float random_value(float value) {
	return fract(sin(value * 127.1 + seed * 311.7) * 43758.5453);
}

float triangular_peak(float value) {
	return 1.0 - abs(fract(value) * 2.0 - 1.0);
}

float mountain_ridge(float x) {
	float main_position = x * peak_count + seed;
	float main_cell = floor(main_position);
	float main_peak = triangular_peak(main_position);
	float main_shape = mix(0.72, 1.85, random_value(main_cell + 4.0));
	float main_amplitude = mix(0.46, 1.0, random_value(main_cell + 1.0));
	float ridge = pow(main_peak, main_shape) * mountain_height * main_amplitude;

	float detail_position = x * peak_count * 2.7 + seed * 3.1;
	float detail_cell = floor(detail_position);
	float detail_peak = triangular_peak(detail_position);
	float detail_amplitude = mix(0.04, 0.19, random_value(detail_cell + 9.0));
	ridge += pow(detail_peak, 1.35) * mountain_height * detail_amplitude;

	float erosion = sin(x * 41.0 + seed * 2.3) * mountain_height * 0.025;
	return horizon - ridge - erosion;
}

void fragment() {
	vec2 uv = UV;
	float ridge = mountain_ridge(uv.x);
	float mountain = smoothstep(ridge - 0.008, ridge + 0.008, uv.y);
	float bottom_fade = 1.0 - smoothstep(0.78, 0.98, uv.y);
	float rim = 1.0 - smoothstep(0.004, 0.023, abs(uv.y - ridge));
	vec3 color = mountain_color.rgb + rim_color.rgb * rim * 0.34;
	float alpha = mountain * bottom_fade * opacity;
	COLOR = vec4(color, alpha);
}
