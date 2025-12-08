shader_type canvas_item;

// A textura da tela do jogo
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
// A textura de ruído (os cacos) que criamos
uniform sampler2D shard_noise : repeat_enable;

// Controla o progresso da reconstrução (1.0 = quebrado, 0.0 = consertado)
uniform float progress : hint_range(0.0, 1.0) = 1.0;

// Quão forte é a distorção dos cacos
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.05;
// Espessura das linhas de rachadura
uniform float crack_thickness : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    // Pega o valor do ruído na posição atual da tela
    vec4 noise_val = texture(shard_noise, SCREEN_UV);
    
    // Calcula a direção da distorção usando os canais R e G do ruído
    // Subtraímos 0.5 para que a distorção vá para ambos os lados (esquerda/direita, cima/baixo)
    vec2 displacement_dir = noise_val.rg - vec2(0.5);
    
    // Calcula o quanto vamos distorcer agora, baseado no progresso
    float current_distortion = distortion_strength * progress;
    
    // Aplica a distorção nas coordenadas UV da tela
    vec2 distorted_uv = SCREEN_UV + displacement_dir * current_distortion;
    
    // Pega a cor da tela na posição distorcida
    vec4 screen_color = texture(SCREEN_TEXTURE, distorted_uv);
    
    // --- Efeito das linhas de rachadura (Opcional) ---
    // Usa o canal B (blue) do ruído cellular para achar as bordas
    float cracks = smoothstep(crack_thickness - 0.1, crack_thickness, noise_val.b);
    // Inverte para que as linhas sejam brancas e o resto transparente
    cracks = 1.0 - cracks;
    // Fade out das rachaduras baseado no progresso
    cracks = cracks * progress;
    vec4 crack_color = vec4(1.0, 1.0, 1.0, 1.0) * cracks;
    
    // Mistura a imagem do jogo com as linhas de rachadura
    COLOR = mix(screen_color, crack_color, cracks * 0.5);
}