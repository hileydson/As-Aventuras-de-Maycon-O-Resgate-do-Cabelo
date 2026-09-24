shader_type spatial;
render_mode cull_disabled, diffuse_burley;

void fragment() {
	float grain = fract(sin(dot(floor(UV * 580.0), vec2(12.9898, 78.233))) * 43758.5453);
	float ripples = sin(UV.y * 63.0 + sin(UV.x * 27.0) * 0.7) * 0.009;
	float wet = smoothstep(0.0, 0.11, UV.y);
	ALBEDO = mix(vec3(0.045, 0.12, 0.135), vec3(0.18, 0.22, 0.21), wet) + vec3(grain * 0.012 + ripples);
	ROUGHNESS = mix(0.4, 0.92, wet);
}
