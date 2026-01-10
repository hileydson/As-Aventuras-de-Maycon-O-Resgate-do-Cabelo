shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable; // Textura de ruído para a distorção
uniform float strength : hint_range(0.0, 0.1) = 0.01; // Força da distorção
uniform float speed : hint_range(0.0, 1.0) = 0.05;   // Velocidade do movimento

void fragment() {
    // Cria um movimento baseado no tempo para o ruído
    vec2 noise_uv = UV + TIME * speed;
    
    // Pega o valor do ruído (textura que vamos colocar)
    vec4 noise_color = texture(noise_texture, noise_uv);
    
    // Distorce a coordenada da tela com base no ruído
    vec2 distortion = (noise_color.rg - 0.5) * strength;
    
    // Aplica a distorção à textura de fundo (o que o jogador vê)
    vec4 screen_color = texture(screen_texture, SCREEN_UV + distortion);
    
    // Opcional: Adiciona um leve tom alaranjado/quente
    vec4 heat_tint = vec4(1.0, 0.5, 0.0, 0.1); // Laranja suave
    COLOR = mix(screen_color, heat_tint, 0.1); 
}