extends Node

# Game Manager script to handle global game flow
# This script manages transitions between game states

func _ready():
	# Connect to tree events if needed
	pass

func _input(event):
	# Handle ESC key to return to menu
	if event.is_action_pressed("ui_cancel"):
		return_to_menu()

func return_to_menu():
	# Return to the main menu
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func restart_game():
	# Restart the current game scene
	get_tree().reload_current_scene()

func quit_game():
	# Quit the entire game
	get_tree().quit()
