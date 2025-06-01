extends Control

@export var scene : PackedScene

func _on_button_pressed():
	print("Start button pressed!")
	# Load the main game scene
	if scene:
		print("Loading scene from packed scene...")
		get_tree().change_scene_to_packed(scene)
	else:
		print("Loading scene from file path...")
		# Fallback to loading by path if scene is not set
		get_tree().change_scene_to_file("res://scenes/main_scene.tscn")

func _on_quit_button_pressed():
	print("Quit button pressed!")
	# Quit the game
	get_tree().quit()

func _ready():
	# Start the menu music when the menu loads
	AudioManager.play_music("menu")
	
	# Set the scene if not already set in the editor
	if not scene:
		scene = preload("res://scenes/main_scene.tscn")
