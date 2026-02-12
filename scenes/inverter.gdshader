shader_type canvas_item;

void fragment() {
    // 1. Pega a cor original do pixel e o alpha original
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 2. Calcula a inversão
    vec3 inverted_rgb = 1.0 - tex_color.rgb;
    
    // 3. SUAVIZAÇÃO: Em vez de usar a inversão pura (que pode estourar o branco),
    // misturamos 70% da inversão com 30% da cor original.
    // Isso evita o efeito "negativo total" muito agressivo.
    vec3 final_rgb = mix(tex_color.rgb, inverted_rgb, 0.7);
    
    // 4. RESULTADO FINAL:
    // Mantemos o RGB calculado acima.
    // Multiplicamos o Alpha original por 0.5 (50% de transparência).
    COLOR = vec4(final_rgb, tex_color.a * 0.5);
}