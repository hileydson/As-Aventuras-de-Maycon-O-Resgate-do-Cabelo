extends CanvasLayer

#@onready var color_rect_efeito: ColorRect = $BackBufferCopy/ColorRect # Ajuste o caminho conforme sua cena
@onready var particulas_vidro: GPUParticles2D = $ParticulasVidro # Nova referência
@onready var color_rect_efeito: ColorRect = $ColorRect

var duration: float = 2.5

func _ready() -> void:
	get_tree().paused = false
	color_rect_efeito.visible = false
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	color_rect_efeito.visible = true
	
	# --- DISPARAR AS PARTÍCULAS ---
	if particulas_vidro:
		particulas_vidro.restart()
		particulas_vidro.emitting = true
	# ------------------------------
	
	var material_shader = color_rect_efeito.material as ShaderMaterial
	if material_shader:
		material_shader.set_shader_parameter("progress", 1.0)
		
		var tween = create_tween()
		tween.tween_method(
			set_shader_progress,
			1.0,
			0.0,
			duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# Espera a animação acabar para deletar tudo
		tween.tween_callback(queue_free)

func set_shader_progress(valor_atual: float):
	color_rect_efeito.material.set_shader_parameter("progress", valor_atual)
