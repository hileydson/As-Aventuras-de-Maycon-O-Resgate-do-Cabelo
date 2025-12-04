extends Camera2D
@onready var maycon_batalha: AnimatedSprite2D = $"../maycon_batalha"
@onready var maycon_batalha_default: AnimatedSprite2D = $"../maycon_batalha_default"
@onready var passos_areia: AudioStreamPlayer = $"../PassosAreia"
@onready var battle_song: AudioStreamPlayer2D = $"../Battle_Song"

@onready var batalha_moves: AnimationPlayer = $"../batalha_moves"
@onready var peido: AudioStreamPlayer = $"../Peido"

@onready var attack_power_1: Sprite2D = $"../Attack_power_1"
@onready var attack_power_2: Sprite2D = $"../Attack_power_2"
@onready var attack_power_3: Sprite2D = $"../Attack_power_3"
@onready var defense_jump_1: Sprite2D = $"../Defense_Jump_1"
@onready var defense_jump_2: Sprite2D = $"../Defense_Jump_2"
@onready var defense_jump_3: Sprite2D = $"../Defense_Jump_3"
@onready var attack_power_time: Sprite2D = $"../Attack_power_time"
@onready var attack_power_x: Sprite2D = $"../Attack_power_X"
@onready var timer: Timer = $"../Timer"
@onready var timer_label: Label = $"../timer_label"

var power_limit_reached:bool = false
var power_limit:int = 3
var power_count:int = 0
var defense_count:int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	maycon_batalha.play("float")
	maycon_batalha_default.play("idle")
	battle_song.play()
	#passos_areia.play()
	#maycon_batalha.position = Vector2(-300, 86);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if timer.time_left!=0.0 && timer.time_left<2.0:
		timer_label.visible = false
		power_limit_reached = false
		power_count = 0
		timer.stop()
	elif timer.time_left!=0.0:
		timer_label.visible = true
		timer_label.text = str("%02d" % timer.time_left)
	
	#controls the power
	if(power_count == power_limit):
		power_limit_reached = true
		attack_power_time.visible = true
		attack_power_x.visible = true
		if timer.time_left == 0.0:
			timer.start()
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
		
	
	if !batalha_moves.is_playing():
		maycon_batalha_default.play("idle")
	
	if Input.is_action_pressed("key_q") && !batalha_moves.is_playing():
		if power_limit_reached:
			peido.play()
		else:
			batalha_moves.play("punch")
			power_count = power_count+1
		
	if Input.is_action_pressed("key_w") && !batalha_moves.is_playing():
		if power_limit_reached:
			peido.play()
		else:
			batalha_moves.play("kick")
			power_count = power_count+1
