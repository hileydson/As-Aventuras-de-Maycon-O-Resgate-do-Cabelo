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

var damage_limit_to_drop_hp:int = 1
var damage_taken:int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if inimigos.damage_count_drop_hp == damage_limit_to_drop_hp:
		inimigos.reset_damage()
		damage_taken = damage_taken+1
	
	if damage_taken == 1:
		hp_1.visible = true
		hp_2.visible = true
		hp_3.visible = true
		hp_4.visible = true
		hp_5.visible = false
		passos_areia.play()
		#batalha_moves.victory()
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
		batalha_moves.victory()
		
