// Adaptado do blur de dash do poço infinito deste projeto, sem o peso central:
// o motion blur da cutscene precisa de um rastro uniforme em toda a tela.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;
uniform float blur_reach = 0.045;
uniform float blur_mix : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 direction = normalize(blur_direction + vec2(0.00001));
	vec2 reach = direction * blur_strength * blur_reach;
	vec3 sharp = texture(screen_texture, SCREEN_UV).rgb;
	vec3 color = sharp * 0.28;
	color += texture(screen_texture, SCREEN_UV - reach).rgb * 0.09;
	color += texture(screen_texture, SCREEN_UV - reach * 0.7).rgb * 0.12;
	color += texture(screen_texture, SCREEN_UV - reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.7).rgb * 0.12;
	color += texture(screen_texture, SCREEN_UV + reach).rgb * 0.09;
	COLOR = vec4(mix(sharp, color, clamp(blur_strength * 1.7, 0.0, blur_mix)), 1.0);
}
