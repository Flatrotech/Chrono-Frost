extends CharacterBody2D

# Movement properties (similar to player)
@export var grid_size = 8
@export var move_speed = 1.5  # Slightly slower than player
@export var detection_radius = 150  # How far enemy can see player

# State variables
var target_pos = Vector2()
var moving = false
var move_dir = Vector2()
var player = null  # Reference to player

@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	# Initialize position and animation
	position = position.snapped(Vector2(grid_size, grid_size))
	target_pos = position
	animated_sprite_2d.play("default")
	
	# Try to find the player in the scene
	player = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
