shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

varying float shore;
varying vec3 world_position;

void vertex() {
	float wave = sin(VERTEX.x * 0.42 + TIME * 0.9) * 0.045 + sin(VERTEX.z * 0.8 - TIME * 1.25) * 0.035 + sin(VERTEX.x * 1.4 + VERTEX.z * 0.38 + TIME * 1.65) * 0.018;
	VERTEX.y += wave;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = smoothstep(-4.0, 0.0, world_position.z);
}

void fragment() {
	float ripple = sin(world_position.x * 1.07 + world_position.z * 0.27 + sin(world_position.z * 0.21) * 0.8 + TIME * 1.1) * sin(world_position.z * 1.76 - world_position.x * 0.12 - TIME * 0.9);
	float fine = sin(world_position.x * 3.7 + world_position.z * 1.1 + TIME * 1.9);
	float foam = clamp(shore * (0.18 + 0.20 * sin(world_position.x * 0.48 + TIME * 1.1) + 0.08 * fine), 0.0, 1.0);
	float moon_path = exp(-abs(world_position.x - 2.0) * 0.048) * (0.35 + 0.25 * ripple);
	ALBEDO = mix(vec3(0.008, 0.052, 0.083), vec3(0.055, 0.17, 0.21), moon_path * 0.6 + ripple * 0.045);
	ALBEDO = mix(ALBEDO, vec3(0.27, 0.56, 0.58), foam * 0.38);
	ROUGHNESS = 0.48;
	METALLIC = 0.08;
	SPECULAR = 0.42;
	EMISSION = vec3(0.035, 0.12, 0.16) * moon_path * 0.32 + vec3(0.05, 0.14, 0.14) * foam;
	NORMAL_MAP = vec3(0.5 + ripple * 0.055, 0.5 + fine * 0.035, 1.0);
}
