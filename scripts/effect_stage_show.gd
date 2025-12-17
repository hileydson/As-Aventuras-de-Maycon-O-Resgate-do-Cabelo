extends AnimatedSprite2D

@onready var intro_batalha_frozen_effect: AnimatedSprite2D = $"."

func _ready():
	ajustar_a_tela()
	# Conecta o sinal para garantir que redimensione se a janela do jogo mudar de tamanho
	get_tree().root.size_changed.connect(ajustar_a_tela)
	intro_batalha_frozen_effect.play("default")

func ajustar_a_tela():
	# 1. Pega o tamanho da tela (Viewport)
	var tamanho_tela = get_viewport_rect().size
	
	# 2. Pega o tamanho original da imagem do frame atual
	# (Se não tiver animação rodando, pega do frame 0 da animação 'default')
	var textura_atual = sprite_frames.get_frame_texture(animation, frame)
	if not textura_atual:
		return # Evita erro se não tiver sprite carregado
		
	var tamanho_sprite = textura_atual.get_size()
	
	# 3. Calcula quanto precisa aumentar para cobrir X e Y
	var escala_x = tamanho_tela.x / tamanho_sprite.x
	var escala_y = tamanho_tela.y / tamanho_sprite.y
	
	# 4. Aplica a escala
	# DICA: Use 'max' se quiser que cubra TUDO sem distorcer (cortando sobras)
	# DICA: Crie um Vector2(escala_x, escala_y) se quiser esticar (distorcer) para caber exato
	
	# Opção A: Esticar (Pode ficar "gordo" ou "magro")
	scale = Vector2(escala_x, escala_y)
	
	# 5. Centraliza o sprite na tela (O CanvasLayer começa no 0,0)
	global_position = tamanho_tela / 2
