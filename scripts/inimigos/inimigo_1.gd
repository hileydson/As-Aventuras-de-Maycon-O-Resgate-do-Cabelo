extends AnimatedSprite2D

@onready var hp_1: Sprite2D = $hp_1
@onready var hp_2: Sprite2D = $hp_2
@onready var hp_3: Sprite2D = $hp_3
@onready var hp_4: Sprite2D = $hp_4
@onready var hp_5: Sprite2D = $hp_5
@onready var ds_pain: AudioStreamPlayer = $"../../../Cenario de batalha/DsPain"
@onready var passos_areia: AudioStreamPlayer = $"../../../Cenario de batalha/PassosAreia"

@onready var inimigos: Node2D = $"../.."
@onready var batalha_moves: AnimationPlayer = $"../../../Cenario de batalha/batalha_moves"
@onready var me: AnimatedSprite2D = $"."
@onready var maycon: CharacterBody2D = $"../../../Cenario de batalha/Maycon"
@onready var timer_enemy_attack: Timer = $Timer_enemy_attack
@onready var inimigo_1_animation_attack: AnimationPlayer = $inimigo_1_animation_attack

var damage_limit_to_drop_hp:int = 1
var damage_taken:int = 0
	
func _ready() -> void:
	add_child(timer_enemy_attack)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
	
	if batalha_moves.enemy_hurt == true:
		me.play("pain")
	elif me.animation_finished && !me.is_playing():
		me.play("idle")

	if inimigos.damage_count_drop_hp == damage_limit_to_drop_hp:
		inimigos.reset_damage()
		damage_taken = damage_taken+1
	
	if damage_taken == 1:
		hp_1.visible = true
		hp_2.visible = true
		hp_3.visible = true
		hp_4.visible = true
		hp_5.visible = false
	if damage_taken == 2:
		hp_1.visible = true
		hp_2.visible = true
		hp_3.visible = true
		hp_4.visible = false
		hp_5.visible = false
	if damage_taken == 3:
		hp_1.visible = true
		hp_2.visible = true
		hp_3.visible = false
		hp_4.visible = false
		hp_5.visible = false
	if damage_taken == 4:
		hp_1.visible = true
		hp_2.visible = false
		hp_3.visible = false
		hp_4.visible = false
		hp_5.visible = false
	if damage_taken == 5:
		hp_1.visible = false
		hp_2.visible = false
		hp_3.visible = false
		hp_4.visible = false
		hp_5.visible = false
		me.stop()
		batalha_moves.victory()
	
	
func _on_timer_enemy_attack_timeout() -> void:
	if maycon.visible == true && !batalha_moves.battle_finished:
		batalha_moves.enemy_attacking = true
		me.play("attack")
		inimigo_1_animation_attack.play("power_attack")


func _on_animation_finished() -> void:
	batalha_moves.enemy_attacking = false
