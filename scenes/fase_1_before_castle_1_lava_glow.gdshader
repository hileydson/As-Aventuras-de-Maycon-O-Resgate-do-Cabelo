shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D foreground_texture : filter_linear;

float lava_heat(vec2 uv) {
	vec4 sampled = texture(foreground_texture, uv);
	float red_heat = smoothstep(0.28, 0.88, sampled.r);
	float orange_heat = smoothstep(0.04, 0.62, sampled.g);
	float blue_rejection = smoothstep(0.12, 0.55, sampled.r - sampled.b);
	float lower_scene = smoothstep(0.69, 0.80, uv.y);
	return red_heat * orange_heat * blue_rejection * sampled.a * lower_scene;
}

void fragment() {
	vec2 uv = UV;
	float glow = lava_heat(uv) * 0.35;
	glow += lava_heat(uv + vec2(0.018, 0.0)) * 0.10;
	glow += lava_heat(uv - vec2(0.018, 0.0)) * 0.10;
	glow += lava_heat(uv + vec2(0.0, 0.025)) * 0.11;
	glow += lava_heat(uv - vec2(0.0, 0.025)) * 0.11;
	glow += lava_heat(uv + vec2(0.045, 0.018)) * 0.06;
	glow += lava_heat(uv + vec2(-0.045, 0.018)) * 0.06;
	glow += lava_heat(uv + vec2(0.045, -0.018)) * 0.06;
	glow += lava_heat(uv + vec2(-0.045, -0.018)) * 0.06;
	glow += lava_heat(uv + vec2(0.0, -0.070)) * 0.08;
	float pulse = 0.72 + sin(TIME * 0.83) * 0.16 + sin(TIME * 1.57 + uv.x * 9.0) * 0.10;
	float aura = clamp(glow * pulse, 0.0, 1.0);
	vec3 light_color = mix(vec3(0.68, 0.005, 0.002), vec3(1.0, 0.08, 0.006), aura);
	COLOR = vec4(light_color * aura, aura * 0.58);
}
