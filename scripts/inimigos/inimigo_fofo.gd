extends AnimatedSprite2D

@onready var hp_1: Sprite2D = $hps/hp_1
@onready var hp_2: Sprite2D = $hps/hp_2
@onready var hp_3: Sprite2D = $hps/hp_3
@onready var hp_4: Sprite2D = $hps/hp_4
@onready var hp_5: Sprite2D = $hps/hp_5

@onready var ds_pain: AudioStreamPlayer = $"../../../Cenario de batalha/DsPain"
@onready var passos_areia: AudioStreamPlayer = $"../../../Cenario de batalha/PassosAreia"
@onready var inimigos: Node = $"../.."

@onready var batalha_moves: AnimationPlayer = $"../../../Cenario de batalha/batalha_moves"
@onready var me: AnimatedSprite2D = $"."
@onready var maycon: CharacterBody2D = $"../../../Cenario de batalha/Maycon"
@onready var timer_enemy_attack: Timer = $Timer_enemy_attack
@onready var inimigo_1_animation_attack: AnimationPlayer = $inimigo_1_animation_attack

var id_unico:String

var count_play_inicio = 0
var em_batalha = false
var damage_limit_to_drop_hp:int = 1
var damage_taken:int = 0
var dead:bool = false
	
var ref_inimigos: Node		
	
func resetEnemy() -> void:
	count_play_inicio = 0
	damage_taken = 0 #TODO: COLOCAR 4 PARA TESTAR RAPIDO E VOLTAR PARA 0 PARA O PADRAO
	dead = false
	me.play("idle")

		
func _ready() -> void:
	ref_inimigos = get_tree().root.find_child("inimigo_node", true, false)
	
	id_unico = get_tree().current_scene.name + "_" + str(get_path())
	if Global.inimigos_mortos.has(id_unico):
		queue_free()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
	
	em_batalha = (batalha_moves != null) && !dead
	
	if em_batalha == false:
		return
	elif count_play_inicio == 0:
		if Global.battle_started == true:
			timer_enemy_attack.start()
			count_play_inicio = count_play_inicio+1
		
	if batalha_moves.enemy_hurt == true:
		me.play("pain")
	elif me.animation_finished && !me.is_playing():
		me.play("idle")

	if ref_inimigos == null:
		ref_inimigos = get_tree().root.find_child("inimigo_node", true, false)
	elif ref_inimigos.damage_count_drop_hp == damage_limit_to_drop_hp:
		ref_inimigos.reset_damage()
		damage_taken = damage_taken+1
	
	# Simplifiquei a lógica de visibilidade (opcional, mas fica mais limpo)
	hp_1.visible = damage_taken < 5
	hp_2.visible = damage_taken < 4
	hp_3.visible = damage_taken < 3
	hp_4.visible = damage_taken < 2
	hp_5.visible = damage_taken < 1

	if damage_taken >= 5:
		me.stop()
		batalha_moves.victory()
		dead=true
		timer_enemy_attack.stop()
	
	
func _on_timer_enemy_attack_timeout() -> void:
	if batalha_moves == null:
		return
	
	if inimigo_1_animation_attack.is_playing():
		return
		
	if maycon.visible == true && !batalha_moves.battle_finished:
		# gera ataques aleatorios
		var resultado = randi_range(0, 100) / 2.0
		if  resultado == floor(resultado):
			inimigo_1_animation_attack.play("power_attack")
		else:
			inimigo_1_animation_attack.play("power_attack_2")
			
		
		batalha_moves.enemy_attacking = true
		
		
func set_enemy_attacking() -> void:
	batalha_moves.enemy_attacking = false		
func set_enemy_not_attacking() -> void:
	batalha_moves.enemy_attacking = false

func _on_animation_finished() -> void:
	batalha_moves.enemy_attacking = false


func _on_to_battle_body_entered(body: Node2D) -> void:
	Global.battle_next_enemy = "3"
	Global.inimigos_mortos[id_unico] = true
	queue_free()
	
	
