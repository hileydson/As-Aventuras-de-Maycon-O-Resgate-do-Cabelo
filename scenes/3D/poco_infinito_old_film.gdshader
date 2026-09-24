shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Controles visuais do filme antigo
uniform float sepia_amount : hint_range(0.0, 1.0) = 0.42;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.075;
uniform float grain_speed : hint_range(1.0, 60.0) = 24.0;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.95;
uniform float flicker_intensity : hint_range(0.0, 0.2) = 0.04;
uniform float scratch_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float dust_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float jitter_amount : hint_range(0.0, 0.01) = 0.0006;

// Função hash pseudo-aleatória de alta distribuição
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float frame_step = floor(TIME * grain_speed);
	
	// Micro-trepidação vertical da fita de projeção mecânica (jitter)
	vec2 uv = SCREEN_UV;
	float jitter = (hash(vec2(frame_step, 19.87)) - 0.5) * 2.0 * jitter_amount;
	uv.y = clamp(uv.y + jitter, 0.0, 1.0);
	
	// Cor base renderizada na tela
	vec4 base_color = texture(screen_texture, uv);
	vec3 color = base_color.rgb;
	
	// Tremulação de luz do projetor vintage (Flicker)
	float flicker_sine = sin(TIME * 29.4) * cos(TIME * 15.3);
	float flicker_noise = (hash(vec2(frame_step, 42.1)) - 0.5);
	float flicker = 1.0 + (flicker_sine * 0.5 + flicker_noise * 0.5) * flicker_intensity;
	color *= flicker;
	
	// Riscos e arranhões verticais na fita (Vertical film scratches)
	float scratch_period = floor(TIME * 12.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float scratch_x = hash(vec2(scratch_period + fi * 23.1, fi * 11.7));
		float scratch_width = 0.0012 + hash(vec2(scratch_period, fi * 3.1)) * 0.0008;
		float dist_x = abs(uv.x - scratch_x);
		if (dist_x < scratch_width) {
			float scratch_fade = 1.0 - (dist_x / scratch_width);
			float vertical_noise = hash(vec2(floor(uv.y * 120.0), scratch_period + fi));
			if (vertical_noise > 0.28) {
				float scratch_sign = hash(vec2(fi, scratch_period)) > 0.45 ? 0.3 : -0.22;
				color += vec3(scratch_sign * scratch_intensity * scratch_fade);
			}
		}
	}
	
	// Pontos e fiapos de poeira esporádicos (Dust specks)
	float dust_chance = hash(vec2(frame_step, 77.3));
	if (dust_chance > 0.82) {
		vec2 dust_pos = vec2(hash(vec2(frame_step, 101.1)), hash(vec2(frame_step, 202.2)));
		float dust_dist = length(uv - dust_pos);
		if (dust_dist < 0.0032) {
			color *= (1.0 - dust_intensity * 0.85);
		}
	}
	
	// Grão de filme procedural analógico (Film grain)
	vec2 grain_uv = uv * 1200.0 + vec2(frame_step * 17.3, frame_step * 61.9);
	float grain = (hash(grain_uv) - 0.5) * 2.0;
	color += grain * grain_amount;
	
	// Tonalidade sépia/vintage cinematográfica
	vec3 sepia_tint = vec3(
		dot(color, vec3(0.393, 0.769, 0.189)),
		dot(color, vec3(0.349, 0.686, 0.168)),
		dot(color, vec3(0.272, 0.534, 0.131))
	);
	// Leve realce de contraste retrô
	sepia_tint = clamp(sepia_tint * 1.05 - vec3(0.025), 0.0, 1.0);
	color = mix(color, sepia_tint, sepia_amount);
	
	// Vinheta suave nas bordas e cantos (Vignette)
	vec2 center_offset = uv - vec2(0.5);
	float dist_from_center = length(center_offset);
	float vignette = smoothstep(vignette_radius, vignette_radius * 0.45, dist_from_center);
	color = mix(color * (1.0 - vignette_intensity), color, vignette);
	
	COLOR = vec4(clamp(color, 0.0, 1.0), base_color.a);
}
