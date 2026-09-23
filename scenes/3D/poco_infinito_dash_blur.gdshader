shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 blur_direction = vec2(1.0, 0.0);
uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float blur_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 direction = normalize(blur_direction + vec2(0.00001));
	vec2 reach = direction * blur_strength * 0.031;
	vec3 sharp = texture(screen_texture, SCREEN_UV).rgb;
	vec3 color = sharp * 0.28;
	color += texture(screen_texture, SCREEN_UV - reach).rgb * 0.09;
	color += texture(screen_texture, SCREEN_UV - reach * 0.7).rgb * 0.12;
	color += texture(screen_texture, SCREEN_UV - reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.35).rgb * 0.15;
	color += texture(screen_texture, SCREEN_UV + reach * 0.7).rgb * 0.12;
	color += texture(screen_texture, SCREEN_UV + reach).rgb * 0.09;
	float near_body = 1.0 - smoothstep(0.07, 0.43, distance(SCREEN_UV, blur_center));
	float amount = blur_strength * (0.16 + near_body * 0.69);
	COLOR = vec4(mix(sharp, color, amount), 1.0);
}
