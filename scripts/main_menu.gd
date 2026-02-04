extends VBoxContainer

@onready var fade: Node2D = $"../../auto_fade_in"

@onready var new_game: Button = $"New Game"
@onready var exit: Button = $Exit
@onready var cabelo_sound: AudioStreamPlayer2D = $"../cabelo_sound"
@onready var maycon_looking: AnimatedSprite2D = $"../mayconLooking"
@onready var menu_song: AudioStreamPlayer2D = $"../menu_song"
@onready var jamelao_song: AudioStreamPlayer = $"../JamelaoSong"
@onready var v_box_container: VBoxContainer = $"."
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var continue_: Button = $Continue_
@onready var as_aventuras_de_maycon: Label = $"../as_aventuras_de_maycon"
@onready var o_resgate_do_cabelo: Label = $"../o_resgate_do_cabelo"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if Global.default_language == Global.language_en:
		as_aventuras_de_maycon.text = "The Legend of Maycon"
		o_resgate_do_cabelo.text = "The Cabelo's Rescue"
	
	continue_.disabled = !Global.check_load()
	
	animation_player.play("intro")
	new_game.grab_focus()
	cabelo_sound.play()
	
	if Global.default_language == Global.language_en:
		new_game.text = "New Game"
		continue_.text = "Continue"
		exit.text = "Exit"
	
	maycon_looking.play("idle")
	
	get_viewport().gui_disable_input = true
	await get_tree().create_timer(3.0).timeout 
	get_viewport().gui_disable_input = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_menu_ready() -> void:
	jamelao_song.play()
	#menu_song.play()


func _on_new_game_pressed() -> void:
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/intro_game.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_continue__pressed() -> void:
	Global.load_progress()
