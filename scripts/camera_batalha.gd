extends Camera2D

func tremer(intensidade: float, duracao: float):
	var tween = create_tween()
	# Faz o tremor acontecer várias vezes durante a duração definida
	for i in range(int(duracao * 15)):
		var deslocamento = Vector2(randf_range(-intensidade, intensidade), randf_range(-intensidade, intensidade))
		# Move a câmera para uma posição aleatória rapidamente
		tween.tween_property(self, "offset", deslocamento, duracao / 15)
	
	# No final, volta a câmera para o centro (0,0) suavemente
	tween.tween_property(self, "offset", Vector2.ZERO, 0.1)
