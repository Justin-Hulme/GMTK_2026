extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready():
	music_player.volume_db = -20
	music_player.play()

func play_music(stream: AudioStream):
	if music_player.stream != stream:
		music_player.stream = stream
		music_player.play()

func stop_music():
	music_player.stop()
