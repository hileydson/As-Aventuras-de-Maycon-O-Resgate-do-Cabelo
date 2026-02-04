extends AnimationPlayer

@onready var maycon: CharacterBody2D = $"../Maycon"
@onready var maycon_batalha: AnimatedSprite2D = $"../maycon_batalha"
@onready var maycon_batalha_default: AnimatedSprite2D = $"../maycon_batalha_default"
@onready var passos_areia: AudioStreamPlayer = $"../PassosAreia"
@onready var battle_song: AudioStreamPlayer2D = $"../Battle_Song"
@onready var victory_sound: AudioStreamPlayer2D = $"../victory_sound"
@onready var destroy: GPUParticles2D = $"../../inimigo_node/destroy"
@onready var camera_maycon: Camera2D = $"../Camera2D"
@onready var inimigo_batalha: AnimatedSprite2D = $"../../inimigo_node/inimigo_batalha"
@onready var inimigos_place: Node2D = $"../../Inimigos"
@onready var marker_2d: Marker2D = $"../../Inimigos/Marker2D"

@onready var battle: Node2D = $"../.."
@onready var pause: Control = $"../../../Pause"

@onready var batalha_moves: AnimationPlayer = $"../batalha_moves"
@onready var peido: AudioStreamPlayer = $"../Peido"

@onready var attack_power_1: Sprite2D = $"../Attack_power_1"
@onready var attack_power_2: Sprite2D = $"../Attack_power_2"
@onready var attack_power_3: Sprite2D = $"../Attack_power_3"

@onready var attack_power_time: Sprite2D = $"../Attack_power_time"
@onready var attack_power_x: Sprite2D = $"../Attack_power_X"
@onready var timer_power: Timer = $"../Timer_power"
@onready var timer_power_label: Label = $"../timer_power_label"
@onready var ds_pain: AudioStreamPlayer = $"../DsPain"
@onready var victory_label: Label = $"../victory_label"
@onready var you_died_label: Label = $"../you_died_label"
@onready var fade: Node2D = $"../../fade"

@onready var destroy_maycon: GPUParticles2D = $"../Maycon/destroy_maycon"
@onready var inicio_batalha: AnimatedSprite2D = $"../../inicio_batalha"
@onready var explosao: AudioStreamPlayer = $"../Explosao"
@onready var battleground: Sprite2D = $"../Battleground"
@onready var erro_sound: AudioStreamPlayer = $"../ErroSound"

@onready var text_about_itens: Label = $"../explicacao_batalha/text_about_itens"
@onready var bloco_visao: ColorRect = $"../explicacao_batalha/bloco_visao"
@onready var bloco_visao_2: ColorRect = $"../explicacao_batalha/bloco_visao2"
@onready var bloco_visao_3: ColorRect = $"../explicacao_batalha/bloco_visao3"
@onready var fade_interno_explicacao: Node2D = $"../explicacao_batalha/fade_interno_explicacao"
@onready var fire_effects: Node2D = $"../fire_effects"
@onready var no_fire_effects: Node2D = $"../no_fire_effects"
@onready var sound_seco_capsule: AudioStreamPlayer = $"../sound_seco_capsule"

var inimigos = {
	# ENEMIES
	"1" = preload("res://scenes/inimigos/inimigo_camilita.tscn"),
	"2" = preload("res://scenes/inimigos/inimigo_bomba_pretti.tscn"),
	"3" = preload("res://scenes/inimigos/inimigo_fofo.tscn"),
	"4" = preload("res://scenes/inimigos/inimigo_xuruzika.tscn"),
	"5" = preload("res://scenes/inimigos/inimigo_manga.tscn"),
	
	# BOSSES
	"1001" = preload("res://scenes/inimigos/inimigo_boss_seco.tscn")
}

signal player_clicou

var current_enemy = null

var power_limit_reached:bool = false
var power_limit:int = 3
var power_count:int = 0

var battle_finished:bool = false
var enemy_hurt:bool = false
var enemy_attacking:bool = false

var first_battle_explain_shown:bool = false

var died:bool = false

var boss_song:bool = false

var mapas_backgrounds = {
	"1" = preload("res://assets/novas_imagens/cenarios/in_use/battle/battle_fase_1_in_fire.png"),
	"2" = preload("res://assets/novas_imagens/cenarios/in_use/battle/battle_fase_1_no_fire.png"),
	"3" = preload("res://assets/novas_imagens/cenarios/in_use/battle/battle_fase_1_happy_ending.png")
}

func change_enemy_hurt(boolean:bool)->void:
	enemy_hurt = boolean

func maycon_died()->void:
	$"../../../maycon_itens".get_node("canvas").visible = false
	GameSongs.stop(1)
	destroy_maycon.visible = true
	battle_song.stop()
	you_died_label.visible = true
	maycon.get_node("AnimatedSprite2D").stop()
	#get_node("Cenario de batalha").get_tree().paused
	
	if battle_finished==false:
		ds_pain.play()
		#victory_sound.play()
		battle_finished = true
	
	await get_tree().create_timer(4.0).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout
	victory_label.visible = false
	you_died_label.visible = false
	await get_tree().create_timer(1.0).timeout
	Global.battle_started = false
	$"../../../maycon_itens".get_node("canvas").visible = true
	GameSongs.process_mode = Node.PROCESS_MODE_INHERIT
	#TODO: para a demo, apenas volta para a fase 1, mas para uma versao final seria 
	# melhor analisar qual a ultima fase salva e ir por lah
	Global.reset_died_stage1()

func victory()->void:
	$"../../../maycon_itens".get_node("canvas").visible = false
	battle_finished = true
	destroy.visible = true
	battle_song.stop()
	victory_label.visible = true
	
	ds_pain.play()
	
	if !boss_song :
		victory_sound.play()
	
	await self.player_clicou
	fade.get_node("Transition").play("fade_out")
	#current_enemy.queue_free()
	await get_tree().create_timer(3.0).timeout
	Global.back_to_main_camera = true
	Global.battle_started = false
	get_tree().paused = false
	victory_label.visible = false
	you_died_label.visible = false
	victory_sound.stop()
	destroy.visible = false
	GameSongs.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(0.6).timeout	
	$"../../../maycon_itens".get_node("canvas").visible = true
	
	
func add_enemy()->void:
	
	if Global.battle_next_enemy == "1001": #boss seco
		boss_song = true
	else:
		boss_song = false
		
	current_enemy = inimigos[Global.battle_next_enemy].instantiate()
	add_child(current_enemy)
	current_enemy.global_position = inimigo_batalha.global_position
	
func reset_maycon_batalha()->void:
	power_count = 0
	battle_finished = false
	enemy_hurt = false
	enemy_attacking = false
	
	#reset do maycon defense tb
	maycon.defense_limit_reached = false
	maycon.defense_count = 0
	#maycon.hp_limit_reached = false
	#maycon.hp_count = 0 
	
func play_inicio()->void:
	#visibilidade do sangue continuo
	$"../hp_1".visible = Global.maycon_hp_count<=2
	$"../hp_2".visible = Global.maycon_hp_count<=1
	$"../hp_3".visible = Global.maycon_hp_count<=0
	
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	fade.get_node("Transition").play("fade_in")
	camera_maycon.make_current()
	
	explosao.play()
	inicio_batalha.play("inicio")
	maycon_batalha.play("float")
	maycon_batalha_default.play("idle")
	
	batalha_moves.play("move_to_middle")
	
	if boss_song :
		sound_seco_capsule.play()
	else:
		battle_song.play()
	
	reset_maycon_batalha()
	
	current_enemy.resetEnemy()

func show_first_battle() -> void:	
	first_battle_explain_shown = true
	await get_tree().create_timer(4.0).timeout
	#fade_interno_explicacao.get_node("Transition").play("fade_in")
	
	if Global.default_language == Global.language_pt_br:
		text_about_itens.text = "Voçê terá 3 ataques(soco ou chute) e 
									6 defesas(pulo).
									
									Após usar os 3 ataques terá que aguardar
									um instante até poder atacar novamente.
									
									Após usar as 6 defesas também terá que 
									aguardar um instante.
									\n\n\n\n\n
									Voçê terá 3 vidas, caso morra, terá que
									voltar ao início do Stage"
	else:
		text_about_itens.text = "You will have 3 attacks (punch or kick) 
									and 6 defenses (jump).

									After using the 3 attacks you will have 
									to wait a moment before you can attack again.

									After using the 6 defenses you will also 
									have to wait a moment.
									\n\n\n\n\n
									You will have 3 lives, if you die, you will 
									have to return to the beginning of the Stage."
		
	$"../explicacao_batalha".visible = true
	maycon.process_mode = Node.PROCESS_MODE_DISABLED
	
	
	await get_tree().create_timer(3.0).timeout
	$"../explicacao_batalha/ok_buttons".visible = true
	await self.player_clicou
	Global.game_events["first_battle"]=false
	await get_tree().create_timer(0.5).timeout
	maycon.process_mode = Node.PROCESS_MODE_INHERIT
	$"../explicacao_batalha".visible = false
	
	for objetos_na_batalha in batalha_moves.get_children(false):
		objetos_na_batalha.process_mode = Node.PROCESS_MODE_INHERIT


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	#carrega mapa correto
	battleground.texture = mapas_backgrounds[Global.battle_background]
	# se for cenario de fogo dai mostra os fire effects
	if Global.battle_background == "1":
		no_fire_effects.visible = false
		fire_effects.visible = true
	else:
		fire_effects.visible = false
		no_fire_effects.visible = true
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		
	if Input.is_action_just_pressed("ui_accept"):
		emit_signal("player_clicou")
		
	
	if Global.battle_started && Global.game_events["first_battle"] && first_battle_explain_shown==false:
		show_first_battle()
	
	control_attack_power()	
	

	# TEMP PARA ANALISAR TODAS AS FASES
	#return
	
	
	# PLOTAR INIMIGO EM BATALHA
	if Global.battle_next_enemy != "0":
		Global.battle_started = true
		add_enemy()
		Global.battle_next_enemy = "0"
		$"../../../maycon_itens".get_node("canvas").visible = false
		GameSongs.process_mode = Node.PROCESS_MODE_DISABLED
		BattleShatteredScreenEffect.get_node("canvas_layer_frozen_effect").get_node("intro_batalha_frozen_effect").start_effect(2)
		await get_tree().create_timer(0.8).timeout
		BattleShatteredScreenEffect.get_node("canvas_layer_frozen_effect").get_node("intro_batalha_frozen_effect").stop_effect()
		play_inicio()
		$"../../../maycon_itens".get_node("canvas").visible = true
		
		
		
	elif Global.battle_next_boss != 0:
		Global.battle_started = true
		add_enemy()
		$"../../../maycon_itens".get_node("canvas").visible = false
		GameSongs.process_mode = Node.PROCESS_MODE_DISABLED
		BattleShatteredScreenEffect.get_node("canvas_layer_frozen_effect").get_node("intro_batalha_frozen_effect").start_effect(2)
		await get_tree().create_timer(0.8).timeout
		BattleShatteredScreenEffect.get_node("canvas_layer_frozen_effect").get_node("intro_batalha_frozen_effect").stop_effect()
		play_inicio()
		Global.battle_next_boss = 0
		$"../../../maycon_itens".get_node("canvas").visible = true
		
	if Global.battle_started == false:
		return
		
	if died:
		maycon_died()
	
	if !batalha_moves.is_playing():
		maycon_batalha_default.play("idle")
		
		
	if enemy_attacking == true:
		return
		
	if battle_finished==false:
		if Input.is_action_pressed("key_q") && Global.game_events["first_battle"]==false && !batalha_moves.is_playing() && maycon.get_node("AnimatedSprite2D").animation == "idle_right":
			if power_limit_reached:
				erro_sound.play()
			else:
				batalha_moves.play("punch")
				power_count = power_count+1
			
		if Input.is_action_pressed("key_w") && Global.game_events["first_battle"]==false && !batalha_moves.is_playing() && maycon.get_node("AnimatedSprite2D").animation == "idle_right":
			if power_limit_reached:
				erro_sound.play()
			else:
				batalha_moves.play("kick")
				power_count = power_count+1



func control_attack_power() -> void:
	if timer_power.time_left!=0.0 && timer_power.time_left<2.0:
		timer_power_label.visible = false
		power_limit_reached = false
		power_count = 0
		timer_power.stop()
	elif timer_power.time_left!=0.0:
		timer_power_label.visible = true
		timer_power_label.text = str("%02d" % timer_power.time_left)
	
	#controls the power
	if(power_count == power_limit):
		power_limit_reached = true
		attack_power_time.visible = true
		attack_power_x.visible = true
		if timer_power.time_left == 0.0:
			timer_power.start()
	else:
		power_limit_reached = false
		attack_power_time.visible = false
		attack_power_x.visible = false
		
	if power_count == 0:
		attack_power_1.visible = true
		attack_power_2.visible = true
		attack_power_3.visible = true		
	if power_count == 1:
		attack_power_1.visible = true
		attack_power_2.visible = true
		attack_power_3.visible = false
	if power_count == 2:
		attack_power_1.visible = true
		attack_power_2.visible = false
		attack_power_3.visible = false		
	if power_count == 3:
		attack_power_1.visible = false
		attack_power_2.visible = false
		attack_power_3.visible = false		
