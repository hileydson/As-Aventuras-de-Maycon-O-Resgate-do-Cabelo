extends Area3D

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")
const POST_BOSS_FADE_DURATION:float = 4.0

@onready var barra_vida: ProgressBar = $"../../CanvasLayer/ProgressBar"
@onready var growl_fino: AudioStreamPlayer = $"../../Growl_fino"
@onready var seco_died: Label = $"../../seco_died"
@onready var blackout: ColorRect = $"../../ColorRect"
@onready var canvas_layer: CanvasLayer = $"../../CanvasLayer"
@onready var final_msg: Label = $"../../ColorRect/final_msg"
@onready var final_msg_2: Label = $"../../ColorRect/final_msg2"

var hp:int = 100
var victory_sequence_started:bool = false

func receber_dano(dano:int)->void:
	var dano_aplicado: int = dano * 2 if Global.is_easy_mode() else dano
	hp -= dano_aplicado
	#hp -= 90 # TESTE
	
	# 0.2 de velocidade (bem lento) por 0.3 segundos reais
	efeito_camera_lenta(0.2, 0.3)
	
	# Garante que a vida não fique negativa
	hp = clamp(hp, 0, 100)
	
	# Atualiza o visual da barra
	atualizar_barra()
	
	if hp <= 0:
		morrer()
	
	
func efeito_camera_lenta(intensidade: float, duracao: float):
	# intensidade 0.1 é muito lento, 0.5 é metade da velocidade
	Engine.time_scale = intensidade
	
	# Criamos um timer que IGNORE a escala de tempo, 
	# senão ele também demoraria para acabar.
	await get_tree().create_timer(duracao, true, false, true).timeout
	
	# Volta para a velocidade normal
	Engine.time_scale = 1.0
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemy_hitbox")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func atualizar_barra():
	growl_fino.play()
	# O Tween faz a barra descer suavemente em vez de um corte seco
	var tween = create_tween()
	tween.tween_property(barra_vida, "value", hp, 0.2)

func morrer():
	if victory_sequence_started:
		return
	victory_sequence_started = true
	remove_from_group("enemy_hitbox")
	_setup_victory_old_film()
	
	if Global.is_two_player_active:
		for p in get_tree().get_nodes_in_group("player"):
			p.find_child("hud_canvas").visible = false
			
		get_tree().get_first_node_in_group("two_layers_fps_mode").find_child("SubViewportContainer2").visible = false
	
	seco_died.text = tr("BATTLE_OLINDAO_DODGED")
	seco_died.visible = true
	final_msg.text = " " + tr("BATTLE_OLINDAO_FLED")
	final_msg_2.text = "  " + tr("BATTLE_SAFADAMENTE")
			
	$"../../..".process_mode = Node.PROCESS_MODE_DISABLED
	$"../../../../maycon_3d".process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
	canvas_layer.visible = false
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_node("hud_canvas"):
		player.get_node("hud_canvas").visible = false
	
	# Oculta "OLINDÃO DESVIOU!" e escurece a tela para fundo todo preto
	seco_died.visible = false
	blackout.color = Color(0, 0, 0, 0)
	blackout.visible = true
	var bg_tween := create_tween()
	bg_tween.tween_property(blackout, "color:a", 1.0, 0.7)
	await bg_tween.finished
	blackout.color = Color.BLACK
	
	# Exibe as próximas frases sobre o fundo totalmente preto
	final_msg.visible = true
	await get_tree().create_timer(4.0).timeout 
	final_msg_2.visible = true
	await get_tree().create_timer(4.0).timeout 
	await _play_long_fade_out()
	
	Global.game_events["seco_first_scene_castle"]=true
	Global.cena_first_seco_boss = true
	Global.save_progress("castelo_1")
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn") 

func _setup_victory_old_film() -> void:
	var scene_root := get_tree().current_scene
	var film_layer := CanvasLayer.new()
	film_layer.name = "VictoryOldFilmFilter"
	film_layer.layer = 10
	scene_root.add_child(film_layer)

	var film_rect := ColorRect.new()
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = OLD_FILM_SHADER
	material.set_shader_parameter("sepia_amount", 0.16)
	material.set_shader_parameter("grain_amount", 0.025)
	material.set_shader_parameter("grain_speed", 20.0)
	material.set_shader_parameter("vignette_intensity", 0.28)
	material.set_shader_parameter("vignette_radius", 1.08)
	material.set_shader_parameter("flicker_intensity", 0.012)
	material.set_shader_parameter("scratch_intensity", 0.10)
	material.set_shader_parameter("dust_intensity", 0.12)
	material.set_shader_parameter("jitter_amount", 0.00012)
	film_rect.material = material
	film_layer.add_child(film_rect)

	var text_layer := CanvasLayer.new()
	text_layer.name = "VictoryText"
	text_layer.layer = 20
	scene_root.add_child(text_layer)
	
	if is_instance_valid(blackout):
		blackout.reparent(text_layer)
		blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
		blackout.offset_left = 0
		blackout.offset_top = 0
		blackout.offset_right = 0
		blackout.offset_bottom = 0
		blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blackout.color = Color.BLACK
		blackout.visible = false
		blackout.z_index = 0
		
	seco_died.reparent(text_layer)
	seco_died.z_index = 1
	final_msg.reparent(text_layer)
	final_msg.z_index = 1
	final_msg_2.reparent(text_layer)
	final_msg_2.z_index = 1

func _play_long_fade_out() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "PostBossLongFadeOut"
	fade_layer.layer = 100
	get_tree().current_scene.add_child(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var fade_tween := get_tree().create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, POST_BOSS_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished
