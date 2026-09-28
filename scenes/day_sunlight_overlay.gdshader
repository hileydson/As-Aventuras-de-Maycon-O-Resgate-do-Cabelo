shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 sun_origin = vec2(0.375, 0.495);
uniform vec3 sun_light_color : source_color = vec3(1.0, 0.93, 0.75);
uniform float sun_intensity : hint_range(0.0, 1.0) = 0.22;

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

void fragment() {
	vec2 uv = UV;
	
	vec2 diff = uv - sun_origin;
	vec2 scaled_diff = vec2(diff.x * 5.2, diff.y);
	float dist = length(scaled_diff);
	
	// Ambient warm sun glow fading downwards
	float ambient_sun = exp(-dist * 2.8) * 0.40;
	
	// Angled sunbeams hitting the scene
	vec2 beam_dir = normalize(vec2(0.55, 0.83));
	float beam_proj = dot(diff, beam_dir);
	float beam_perp = dot(diff, vec2(-beam_dir.y, beam_dir.x));
	
	float beam_n1 = noise(vec2(beam_perp * 28.0 - TIME * 0.015, beam_proj * 2.5));
	float beam_n2 = noise(vec2(beam_perp * 52.0 + TIME * 0.02, beam_proj * 5.0));
	float sunbeams = smoothstep(0.42, 0.76, beam_n1 * 0.7 + beam_n2 * 0.3) 
		* exp(-dist * 1.6) 
		* smoothstep(0.0, 0.12, beam_proj) * 0.35;
		
	// Gentle sunlight wash over the ground
	float ground_warmth = smoothstep(0.52, 0.88, uv.y) * 0.08;
	
	float total_light = (ambient_sun + sunbeams + ground_warmth) * sun_intensity;
	
	COLOR = vec4(sun_light_color * total_light, total_light);
}
