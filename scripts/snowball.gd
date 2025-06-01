extends Area2D

@export var speed = 400.0
var direction = Vector2.RIGHT  # Default direction
var thrower = null  # Reference to who threw this snowball
var lifetime = 5.0  # Maximum lifetime in seconds
var time_alive = 0.0

func _ready():
	# Connect the body_entered signal to our collision handler
	body_entered.connect(_on_body_entered)
	# Also connect area_entered signal to detect invisible areas
	area_entered.connect(_on_area_entered)
	print("DEBUG: Snowball collision signals connected")

func _physics_process(delta):
	time_alive += delta
	position += direction * speed * delta

	# Debug: Print position when snowball crosses center threshold
	if (abs(position.x - 251) < 5):
		print("DEBUG: Snowball near center threshold - Position: ", position, " Direction: ", direction, " Time alive: ", time_alive)

	# Destroy after maximum lifetime (increased to 8 seconds for testing)
	if time_alive > 8.0:
		print("DEBUG: Snowball destroyed - lifetime exceeded at position: ", position)
		queue_free()
		return

	# Temporarily remove all boundary checks to test - let physical collisions handle destruction

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()

func set_thrower(thrower_node):
	thrower = thrower_node

func _on_body_entered(body):
	print("DEBUG: Snowball collision detected with: ", body.name, " at position: ", position, " Groups: ", body.get_groups())
	
	# Don't damage the thrower (prevent self-damage)
	if body == thrower:
		print("DEBUG: Snowball hit thrower, ignoring collision")
		return
	
	# Handle collision with player - deal temperature damage
	if body.is_in_group("player") and body.has_method("take_damage"):
		print("Snowball hit player!")
		
		# Play snowball hit sound effect
		AudioManager.play_snowball_hit()
		
		body.take_damage(25.0)  # Standard warmth damage
		queue_free()  # Destroy snowball after hitting player
	
	# Handle collision with enemy AI
	elif body.is_in_group("enemies") and body.has_method("take_damage"):
		print("Snowball hit enemy!")
		
		# Play snowball hit sound effect
		AudioManager.play_snowball_hit()
		
		body.take_damage(25.0)  # Standard damage to enemies too
		queue_free()  # Destroy snowball after hitting enemy
	
	# Handle collision with walls/static bodies
	elif body is StaticBody2D:
		print("DEBUG: Snowball hit wall at position: ", position, " - Body name: ", body.name)
		queue_free()  # Destroy snowball when hitting walls
	
	else:
		print("DEBUG: Body not a valid target: ", body.name, " - ignoring collision")

func _on_area_entered(area):
	print("DEBUG: Snowball entered area: ", area.name, " at position: ", position)
	# Don't automatically destroy on area entry - let's see what areas exist first
