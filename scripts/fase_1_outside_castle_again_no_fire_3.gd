extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var fase_1_before_castle: Sprite2D = $"."
@onready var mk_dudun: AudioStreamPlayer = $MkDudun
@onready var fade: Node2D = $"../fade"
@onready var apresentacao_pra_cidade: Node2D = $"../apresentacao_pra_cidade"
@onready var camera_apresentacao: Camera2D = $"../apresentacao_pra_cidade/camera_apresentacao"
@onready var balao_marker: Marker2D = $"../cigarro/balao"
@onready var maycon_itens: Node2D = $"../maycon_itens"
@onready var color_rect: ColorRect = $"../apresentacao_pra_cidade/ColorRect"
@onready var city: Label = $"../PlacaCidade/city"

var balao_

var next_scene = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_progress(get_tree().current_scene.name)
	
	if Global.default_language == Global.language_pt_br:
		city.text = "Cidade"
		
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "2"
	
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout

func _process(delta: float) -> void:
	if next_scene:
		next_scene = false
		get_tree().change_scene_to_file("res://scenes/3D/last_fight_before_end.tscn")

func _on_next_scene_body_entered(body: Node2D) -> void:
	maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.4).timeout 
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	camera_apresentacao.make_current()
	apresentacao_pra_cidade.visible = true
	#maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
	maycon_fase.queue_free()
	await get_tree().create_timer(2.0).timeout 
	
	#CHAMA BALAOZINHO
	balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
	balao_marker.add_child(balao_)
	
	if Global.default_language == Global.language_pt_br:
		balao_.falas = ["...", "Como seu melhor amigo do coração!", "Venho te ajudar!", "Sei que está nessa busca pelo Cabelo!", "Confio em você Maycon!", "O Olindão largou ele em algum lugar da cidade", "Tome cuidado com a gasolina!", "Sei que na cidade tem um posto!", "Caso esteja com pouca gasolina vá lá!", "É logo ao sair da ponto!", "Boa sorte amigo!!"]
	else:
		balao_.falas = ["...", "As your best friend!", "I'm here to help you!", "I know you're on this quest for Cabelo!", "I trust you, Maycon!", "Olindão left him somewhere in the city", "Be careful with the gas!", "I know there's a gas station in town!", "If you're low on gas, go there!", "It's right after you leave the bus stop!", "Good luck, my friend!!"]
	
	
	
	#PEGAR O SINAL FINAL DE CONVERSA E FADEOUT
	balao_.conversa_terminou.connect(terminou_ultimo_dialogo)
	

func terminou_ultimo_dialogo()->void:
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	next_scene = true
	
	
func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_2.tscn")
