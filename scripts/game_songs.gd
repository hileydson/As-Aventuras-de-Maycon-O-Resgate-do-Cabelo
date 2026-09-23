extends Node2D

@onready var song_fase_1: AudioStreamPlayer = $FireCracling
@onready var song_fase_1_fire_cracling: AudioStreamPlayer = $SongFase1

func stop(n:int) -> void:
	if n==1:
		song_fase_1.stop()
		song_fase_1_fire_cracling.stop()
	if n==1001:
		song_fase_1.stop()
	if n==1002:
		song_fase_1_fire_cracling.stop()	
		
func play_song(n:int) -> void:
	if n==1:
		song_fase_1.play()
		song_fase_1_fire_cracling.play()
	if n==1001:
		song_fase_1.play()
	if n==1002:
		song_fase_1_fire_cracling.play()

func set_song_pitch(pitch: float) -> void:
	if is_instance_valid(song_fase_1):
		song_fase_1.pitch_scale = pitch
	if is_instance_valid(song_fase_1_fire_cracling):
		song_fase_1_fire_cracling.pitch_scale = pitch

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
