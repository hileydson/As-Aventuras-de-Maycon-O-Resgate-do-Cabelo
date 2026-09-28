shader_type canvas_item;
render_mode unshaded;

uniform vec2 sun_position = vec2(0.375, 0.495);
uniform vec3 sky_top_color : source_color = vec3(0.24, 0.54, 0.90);
uniform vec3 sky_horizon_color : source_color = vec3(0.72, 0.87, 0.99);
uniform vec3 sun_core_color : source_color = vec3(1.0, 0.99, 0.95);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.92, 0.68);
uniform vec3 sun_flare_color : source_color = vec3(1.0, 0.84, 0.52);

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

void fragment() {
	vec2 uv = UV;
	
	// 1. Sky base gradient (clear azure blue to luminous pale horizon)
	float vertical_gradient = smoothstep(0.20, 0.72, uv.y);
	vec3 sky = mix(sky_top_color, sky_horizon_color, vertical_gradient);
	
	// Soft atmospheric haze near horizon
	float horizon_haze = smoothstep(0.55, 0.85, uv.y) * 0.25;
	sky = mix(sky, vec3(0.88, 0.93, 1.0), horizon_haze);
	
	// 2. The Sun
	vec2 sun_diff = uv - sun_position;
	vec2 sun_coord = vec2(sun_diff.x * 5.2, sun_diff.y);
	float sun_dist = length(sun_coord);
	
	// Sun Disc
	float sun_disc = 1.0 - smoothstep(0.024, 0.040, sun_dist);
	
	// Inner Corona Glow
	float inner_corona = exp(-sun_dist * 18.0) * 1.3;
	
	// Wide Atmospheric Glow
	float wide_glow = exp(-sun_dist * 4.5) * 0.65;
	
	// Solar Rays
	float angle = atan(sun_coord.y, sun_coord.x);
	float ray_1 = pow(abs(cos(angle * 4.0 + TIME * 0.05)), 10.0) * exp(-sun_dist * 3.5);
	float ray_2 = pow(abs(cos(angle * 7.0 - TIME * 0.04)), 14.0) * exp(-sun_dist * 5.2);
	float ray_3 = pow(abs(cos(angle * 12.0 + TIME * 0.07)), 16.0) * exp(-sun_dist * 6.5);
	float sun_rays = (ray_1 * 0.5 + ray_2 * 0.35 + ray_3 * 0.25) * 0.7;
	
	// Anamorphic horizontal streak
	float anamorphic_streak = exp(-abs(sun_coord.y) * 50.0) * exp(-abs(sun_coord.x) * 2.5) * 0.35;
	
	// Volumetric God Rays angled downward
	vec2 ray_dir = normalize(vec2(0.55, 0.83));
	float ray_proj = dot(sun_diff, ray_dir);
	float ray_perp = dot(sun_diff, vec2(-ray_dir.y, ray_dir.x));
	float god_ray_noise = fbm(vec2(ray_perp * 35.0 - TIME * 0.02, ray_proj * 4.0));
	float god_rays = smoothstep(0.42, 0.75, god_ray_noise) * exp(-abs(sun_dist) * 1.8) * smoothstep(0.0, 0.15, ray_proj) * 0.22;
	
	// Combine sun light
	vec3 sun_total = sun_core_color * sun_disc * 2.2
		+ sun_glow_color * (inner_corona + wide_glow)
		+ sun_flare_color * (sun_rays + anamorphic_streak + god_rays);
		
	sky += sun_total;
	
	// 3. Daytime clouds drifting
	float cloud_time = TIME * 0.003;
	vec2 cloud_uv = vec2(uv.x * 4.0 + cloud_time, uv.y * 1.8);
	float cloud_n1 = fbm(cloud_uv * 3.0);
	float cloud_n2 = fbm(cloud_uv * 6.0 + vec2(1.7, 3.2));
	float cloud_density = smoothstep(0.48, 0.78, cloud_n1 + cloud_n2 * 0.35);
	float cloud_sky_mask = smoothstep(0.18, 0.32, uv.y) * (1.0 - smoothstep(0.55, 0.72, uv.y));
	cloud_density *= cloud_sky_mask * 0.55;
	
	float cloud_sun_illum = clamp(1.0 - sun_dist * 1.5, 0.0, 1.0);
	vec3 cloud_color = mix(vec3(0.96, 0.97, 1.0), vec3(1.0, 0.98, 0.92), cloud_sun_illum * 0.6);
	sky = mix(sky, cloud_color, cloud_density);
	
	COLOR = vec4(clamp(sky, 0.0, 1.0), 1.0);
}
