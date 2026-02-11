extends CanvasLayer

@onready var label = $Panel/RichTextLabel
@onready var som_bip = $Panel/AudioStreamPlayer
@onready var timer: Timer = $Panel/Timer
@onready var panel: Panel = $Panel
@onready var balao: AnimatedSprite2D = $Panel/AnimatedSprite2D

var falas: Array = [] # Começa vazio para receber do outro script
var fala_atual: int = 0

var balao_sem_seta:bool = false

signal conversa_terminou

func _ready():
	# Conecta o sinal do timer via código por segurança, 
	# caso você tenha esquecido de conectar no Editor.
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	# Só exibe se já tiver falas (caso o add_child tenha vindo depois)
	if falas.size() > 0:
		exibir_fala()

func _process(_delta: float) -> void:
	
	if balao_sem_seta:
		balao.play("balao_sem_seta")
	else:
		balao.play("default")
	
	# Lógica de seguir o marcador
	var balao_marker = get_tree().get_first_node_in_group("balao_conversa")
	if is_instance_valid(balao_marker):
		var canvas_pos = balao_marker.get_global_transform_with_canvas().get_origin()
		# Centraliza o painel acima do marcador
		panel.global_position = canvas_pos - Vector2(panel.size.x / 2, panel.size.y + 50)

func _input(event):
	# Detecta clique ou botão A para pular a animação ou passar a fala
	if event.is_action_pressed("ui_accept") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed):
		handle_dialog_input()

func handle_dialog_input():
	if label.visible_ratio < 1.0:
		# Pula a animação e mostra a frase inteira
		label.visible_ratio = 1.0
		timer.stop()
	else:
		# Vai para a próxima
		proxima_fala()

func exibir_fala():
	if fala_atual < falas.size():
		label.text = falas[fala_atual]
		label.visible_characters = 0 # Começa com zero letras aparecendo
		timer.start(0.04) # Velocidade da digitação
	else:
		conversa_terminou.emit()
		queue_free()

func proxima_fala():
	fala_atual += 1
	exibir_fala()

func _on_timer_timeout():
	if label.visible_ratio < 1.0:
		label.visible_characters += 1
		# Toca o som apenas se ele não estiver tocando (evita sobreposição)
		#if not som_bip.playing:
		som_bip.play()
	else:
		timer.stop()
