extends Node2D

@onready var old_song_backup: AudioStreamPlayer = $old_song_backup


func stop(n:int) -> void:
	if n==1:
		old_song_backup.stop()
		
func play_song(n:int) -> void:
	if n==1:
		old_song_backup.play()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
