shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

varying float shore;
varying vec3 world_position;

void vertex() {
	float wave = sin(VERTEX.x * 0.42 + TIME * 0.9) * 0.085 + sin(VERTEX.z * 0.8 - TIME * 1.25) * 0.055 + sin(VERTEX.x * 1.4 + VERTEX.z * 0.38 + TIME * 1.65) * 0.025;
	VERTEX.y += wave;
	shore = 1.0 - smoothstep(-3.0, 0.0, VERTEX.z);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ripple = sin(world_position.x * 1.9 + TIME * 1.6) * sin(world_position.z * 2.1 - TIME * 1.2);
	float fine = sin(world_position.x * 5.2 + world_position.z * 1.7 + TIME * 2.3);
	float foam = smoothstep(0.65, 0.93, ripple * 0.5 + fine * 0.18 + 0.42) * shore;
	float moon_path = exp(-abs(world_position.x - 2.0) * 0.055) * (0.55 + 0.45 * ripple);
	ALBEDO = mix(vec3(0.012, 0.105, 0.145), vec3(0.13, 0.36, 0.43), moon_path * 0.7 + ripple * 0.08);
	ALBEDO = mix(ALBEDO, vec3(0.48, 0.78, 0.79), foam * 0.62);
	ROUGHNESS = 0.18;
	METALLIC = 0.22;
	SPECULAR = 0.9;
	EMISSION = vec3(0.05, 0.20, 0.26) * moon_path * 0.45 + vec3(0.10, 0.22, 0.23) * foam;
	NORMAL_MAP = vec3(0.5 + ripple * 0.12, 0.5 + fine * 0.08, 1.0);
}
