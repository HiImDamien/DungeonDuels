extends Node

## Persists across scene changes (autoload). Owns the game-music AudioStreamPlayer
## so the track continues seamlessly from the dungeon phase into the final battle.
## Call play_game_music() when entering the game, stop_music() when leaving to menu.

const GAME_MUSIC := preload("res://assets/music/HoliznaCC0 - Mutant Club.mp3")

var _player: AudioStreamPlayer

func _ready() -> void:
	# Keep the music going while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = GAME_MUSIC
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_player.play)  # loop on end

func play_game_music() -> void:
	if _player.playing:
		return  # Already playing — don't restart mid-track on rematch
	_player.play()

func stop_music() -> void:
	_player.stop()
