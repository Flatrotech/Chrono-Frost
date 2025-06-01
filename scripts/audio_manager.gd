extends Node

# Audio Manager for Chrono-Frost
# Handles background music and sound effects

# Audio Players
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var ui_sfx_player: AudioStreamPlayer = $UISFXPlayer

# Music tracks
var music_tracks = {}
var current_music_track = ""
var music_fade_tween: Tween

# SFX clips
var sfx_clips = {}

# Volume settings (0.0 to 1.0)
@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8
@export var ui_sfx_volume: float = 0.6

# Music settings
@export var crossfade_duration: float = 1.0
@export var music_enabled: bool = true
@export var sfx_enabled: bool = true

func _ready():
	# Create audio players if they don't exist
	if not has_node("MusicPlayer"):
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.bus = "Music"
		add_child(music_player)
	
	if not has_node("SFXPlayer"):
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer"
		sfx_player.bus = "SFX"
		add_child(sfx_player)
	
	if not has_node("UISFXPlayer"):
		ui_sfx_player = AudioStreamPlayer.new()
		ui_sfx_player.name = "UISFXPlayer"
		ui_sfx_player.bus = "UI"
		add_child(ui_sfx_player)
	
	# Set initial volumes
	update_volumes()
	
	# Load audio resources
	load_music_tracks()
	load_sfx_clips()
	
	print("AudioManager initialized")

func load_music_tracks():
	# Add music tracks here as you create them
	# Format: music_tracks["track_name"] = preload("res://assets/audio/music/track_name.ogg")
	
	# Load actual music files
	music_tracks["menu"] = preload("res://assets/audio/music/menu_theme.ogg")
	music_tracks["game"] = preload("res://assets/audio/music/battle_theme.ogg")
	# music_tracks["victory"] = preload("res://assets/audio/music/victory_theme.ogg")  # Add when available
	
	print("Music tracks loaded: ", music_tracks.size(), " tracks")

func load_sfx_clips():
	# Add sound effects here as you create them
	# Format: sfx_clips["sfx_name"] = preload("res://assets/audio/sfx/sfx_name.wav")
	
	# Placeholder entries for common game sounds
	# sfx_clips["snowball_throw"] = preload("res://assets/audio/sfx/snowball_throw.wav")
	# sfx_clips["snowball_hit"] = preload("res://assets/audio/sfx/snowball_hit.wav")
	# sfx_clips["player_hit"] = preload("res://assets/audio/sfx/player_hit.wav")
	# sfx_clips["enemy_hit"] = preload("res://assets/audio/sfx/enemy_hit.wav")
	# sfx_clips["freeze"] = preload("res://assets/audio/sfx/freeze.wav")
	# sfx_clips["footstep"] = preload("res://assets/audio/sfx/footstep.wav")
	
	print("SFX clips loaded: ", sfx_clips.size(), " clips")

func play_music(track_name: String, fade_in: bool = true):
	if not music_enabled:
		return
	
	if not music_tracks.has(track_name):
		print("Warning: Music track '", track_name, "' not found")
		return
	
	# Don't restart the same track
	if current_music_track == track_name and music_player.playing:
		return
	
	current_music_track = track_name
	var track = music_tracks[track_name]
	
	if track == null:
		print("Error: Music track '", track_name, "' is null")
		return
		
	if fade_in and music_player.playing:
		# Crossfade to new track
		crossfade_to_track(track)
	else:
		# Direct switch
		music_player.stream = track
		music_player.volume_db = linear_to_db(music_volume * master_volume)
		music_player.play()
	
	print("Playing music: ", track_name)

func crossfade_to_track(new_track: AudioStream):
	if music_fade_tween:
		music_fade_tween.kill()
	
	music_fade_tween = create_tween()
	music_fade_tween.set_parallel(true)
	
	# Fade out current track
	music_fade_tween.tween_method(set_music_volume_db, music_player.volume_db, -80.0, crossfade_duration / 2)
	
	# Switch track and fade in
	music_fade_tween.tween_callback(switch_track.bind(new_track)).set_delay(crossfade_duration / 2)
	music_fade_tween.tween_method(set_music_volume_db, -80.0, linear_to_db(music_volume * master_volume), crossfade_duration / 2).set_delay(crossfade_duration / 2)

func switch_track(new_track: AudioStream):
	music_player.stream = new_track
	music_player.play()

func set_music_volume_db(volume_db: float):
	music_player.volume_db = volume_db

func stop_music(fade_out: bool = true):
	if fade_out and music_player.playing:
		if music_fade_tween:
			music_fade_tween.kill()
		
		music_fade_tween = create_tween()
		music_fade_tween.tween_method(set_music_volume_db, music_player.volume_db, -80.0, crossfade_duration)
		music_fade_tween.tween_callback(music_player.stop)
	else:
		music_player.stop()
	
	current_music_track = ""
	print("Music stopped")

func play_sfx(sfx_name: String, volume_override: float = -1.0):
	if not sfx_enabled:
		return
	
	if not sfx_clips.has(sfx_name):
		print("Warning: SFX '", sfx_name, "' not found - playing placeholder beep")
		# For now, just print debug message when SFX is missing
		# In the future, you could play a generic beep sound
		return
	
	var clip = sfx_clips[sfx_name]
	sfx_player.stream = clip
	
	var volume = volume_override if volume_override >= 0.0 else sfx_volume
	sfx_player.volume_db = linear_to_db(volume * master_volume)
	sfx_player.play()
	
	print("Playing SFX: ", sfx_name)

func play_ui_sfx(sfx_name: String, volume_override: float = -1.0):
	if not sfx_enabled:
		return
	
	if not sfx_clips.has(sfx_name):
		print("Warning: UI SFX '", sfx_name, "' not found")
		return
	
	var clip = sfx_clips[sfx_name]
	ui_sfx_player.stream = clip
	
	var volume = volume_override if volume_override >= 0.0 else ui_sfx_volume
	ui_sfx_player.volume_db = linear_to_db(volume * master_volume)
	ui_sfx_player.play()
	
	print("Playing UI SFX: ", sfx_name)

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	update_volumes()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)

func set_ui_sfx_volume(volume: float):
	ui_sfx_volume = clamp(volume, 0.0, 1.0)

func update_volumes():
	if music_player and music_player.playing:
		music_player.volume_db = linear_to_db(music_volume * master_volume)

func toggle_music():
	music_enabled = !music_enabled
	if not music_enabled:
		stop_music()

func toggle_sfx():
	sfx_enabled = !sfx_enabled

# Convenience methods for common game events
func play_snowball_throw():
	play_sfx("snowball_throw")

func play_snowball_hit():
	play_sfx("snowball_hit")

func play_player_hit():
	play_sfx("player_hit")

func play_enemy_hit():
	play_sfx("enemy_hit")

func play_freeze_sound():
	play_sfx("freeze")

func play_footstep():
	play_sfx("footstep", 0.3)  # Quieter footsteps

# Save/Load settings (for persistent audio preferences)
func save_audio_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_sfx_volume", ui_sfx_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.save("user://audio_settings.cfg")

func load_audio_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.7)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		ui_sfx_volume = config.get_value("audio", "ui_sfx_volume", 0.6)
		music_enabled = config.get_value("audio", "music_enabled", true)
		sfx_enabled = config.get_value("audio", "sfx_enabled", true)
		update_volumes()
