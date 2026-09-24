shader_type canvas_item;

uniform float background_alpha : hint_range(0.0, 1.0) = 0.96;
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x), local.y);
}

void fragment() {
	vec2 uv = UV;
	float time = TIME * motion_amount;
	float horizon = exp(-pow((uv.y - 0.68) * 4.0, 2.0));
	float mist = noise(vec2(uv.x * 3.2 + time * 0.025, uv.y * 5.0 - time * 0.012));
	float moon_glow = exp(-distance(uv, vec2(0.72, 0.42)) * 4.6);
	float left_light = 1.0 - smoothstep(0.0, 0.76, uv.x);
	vec3 deep = vec3(0.008, 0.026, 0.043);
	vec3 teal = vec3(0.025, 0.145, 0.175);
	vec3 color = mix(deep, teal, horizon * (0.13 + mist * 0.13));
	color += vec3(0.07, 0.22, 0.25) * moon_glow * 0.18;
	color += vec3(0.025, 0.085, 0.095) * left_light * 0.24;
	float vignette = smoothstep(0.92, 0.30, distance(uv, vec2(0.5)));
	color *= 0.72 + vignette * 0.28;
	float grain = hash(floor(uv * vec2(960.0, 540.0)) + floor(time * 12.0)) - 0.5;
	color += grain * 0.012;
	COLOR = vec4(color, background_alpha);
}
