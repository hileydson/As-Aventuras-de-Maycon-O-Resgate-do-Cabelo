shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 direction = normalize(blur_direction + vec2(0.00001));
	vec2 reach = direction * blur_strength * 0.026;
	vec3 color = texture(screen_texture, SCREEN_UV).rgb * 0.22;
	color += texture(screen_texture, SCREEN_UV - reach).rgb * 0.11;
	color += texture(screen_texture, SCREEN_UV - reach * 0.7).rgb * 0.13;
	color += texture(screen_texture, SCREEN_UV - reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.7).rgb * 0.13;
	color += texture(screen_texture, SCREEN_UV + reach).rgb * 0.11;
	COLOR = vec4(color, 1.0);
}
