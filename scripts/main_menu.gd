extends VBoxContainer

@onready var new_game: Button = $"New Game"
@onready var exit: Button = $Exit
@onready var cabelo_sound: AudioStreamPlayer2D = $"../cabelo_sound"
@onready var maycon_looking: AnimatedSprite2D = $"../mayconLooking"
@onready var menu_song: AudioStreamPlayer2D = $"../menu_song"
@onready var transition: AnimationPlayer = $"../Transition"
@onready var jamelao_song: AudioStreamPlayer = $"../JamelaoSong"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cabelo_sound.play()
	
	if Global.default_language == Global.language_en:
		new_game.text = "New Game"
		exit.name = "Exit"
	
	maycon_looking.play("idle")
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_menu_ready() -> void:
	jamelao_song.play()
	#menu_song.play()


func _on_new_game_pressed() -> void:
	transition.play("fade_out")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_transition_animation_finished(anim_name: StringName) -> void:
	get_tree().change_scene_to_file("res://scenes/intro_game.tscn")
