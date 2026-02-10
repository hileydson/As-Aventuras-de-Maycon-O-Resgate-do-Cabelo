extends CanvasLayer

@onready var label = $Panel/RichTextLabel
@onready var som_bip = $Panel/AudioStreamPlayer
@onready var timer: Timer = $Panel/Timer
@onready var panel: Panel = $Panel

var falas: Array = ["..."]
var fala_atual: int = 0
var terminando_frase: bool = false

func _ready():
	exibir_fala()

func _process(delta: float) -> void:
	if not som_bip.playing:
		som_bip.play()
	
	var balao_marker = get_tree().get_first_node_in_group("balao_conversa")
	if is_instance_valid(balao_marker):
		# Pega a posição global do marcador e converte para a posição da tela
		# (Levando em conta o zoom e o movimento da câmera)
		var canvas_pos = balao_marker.get_global_transform_with_canvas().get_origin()
		panel.global_position = canvas_pos - Vector2(panel.size.x / 2, panel.size.y + 10)
		
func _input(event):
	# Se você quer usar uma AÇÃO do Input Map (funciona para Teclado e Controle)
	if event.is_action_pressed("ui_accept"): 
		handle_dialog_input()

	# OU se você quer detectar o botão FÍSICO do controle diretamente (Device 0 = Player 1)
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A and event.pressed:
			handle_dialog_input()

func handle_dialog_input():
	if label.visible_ratio < 1.0:
		label.visible_ratio = 1.0
		timer.stop()
	else:
		proxima_fala()

func exibir_fala():
	if fala_atual < falas.size():
		label.text = falas[fala_atual]
		label.visible_ratio = 0.0 # Esconde o texto
		timer.start(0.05) # Velocidade das letras (menor = mais rápido)
	else:
		queue_free() # Fecha o balão quando acabarem as falas

func proxima_fala():
	fala_atual += 1
	exibir_fala()

func _on_timer_timeout():
	if label.visible_ratio < 1.0:
		label.visible_characters += 1
		som_bip.play() # Toca o barulhinho por letra
	else:
		timer.stop()
