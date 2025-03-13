extends Sprite2D

# Movement properties
@export var grid_size = 8  # Size of grid to snap to (typically match your tile size)
@export var move_speed = 2  # Pixels per frame when moving
@export var slow_down_distance = 2.0  # Start slowing down when this close to target

# snowball throwing exports
@export var snowball_scene : PackedScene
@export var throw_offset = Vector2(20,0)

# Movement state
var target_pos = Vector2()
var moving = false
var move_dir = Vector2()

func _ready():
	# Initialize target position to current position
	# Snap initial position to grid
	position = position.snapped(Vector2(grid_size, grid_size))
	target_pos = position

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_accept"):
			# Check if the player pressed the "throw" button
			print("Snowball thrown at position: ", position)
			throw_snowball()
			
	if not moving:
		# Check for new movement input when not already moving
		var input_dir = Vector2.ZERO

		# WASD movement
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_S):
			input_dir.y += 1
		if Input.is_key_pressed(KEY_W):
			input_dir.y -= 1
		
		# Also support arrow keys as fallback
		input_dir.x += Input.get_axis("ui_left", "ui_right")
		input_dir.y += Input.get_axis("ui_up", "ui_down")
		
		# Normalize diagonal movement
		if input_dir != Vector2.ZERO:
			input_dir = input_dir.normalized()
			move_dir = input_dir
			target_pos = position + move_dir * grid_size
			moving = true
	else:
		# Move toward target position
		var distance_vec = target_pos - position
		var distance_length = distance_vec.length()
		
		if distance_length <= 0.5:
			# We've reached or nearly reached the target position
			position = target_pos
			moving = false
		else:
			# Calculate speed based on distance to target
			var current_speed = move_speed
			if distance_length < slow_down_distance:
				# Gradually reduce speed as we approach the target
				current_speed = move_speed * (distance_length / slow_down_distance)
				current_speed = max(current_speed, 1.0)  # Don't go below minimum speed
			
			# Move toward target position with adjusted speed
			position += distance_vec.normalized() * current_speed * delta * 60
	
	# Optional: Add simple screen bounds
	var viewport_rect = get_viewport_rect().size
	position.x = clamp(position.x, 0, viewport_rect.x)
	position.y = clamp(position.y, 0, viewport_rect.y)
	
func throw_snowball():
	if snowball_scene:
		var snowball_instance = snowball_scene.instantiate()
		get_parent().add_child(snowball_instance)

		# Set snowball position and direction
		snowball_instance.position = position + throw_offset

		# Get the throw direction (example: throwing to the right)
		var throw_direction = Vector2(1, 0)

		#OR Get the throw direction (example: throwing towards mouse)
		#var throw_direction = (get_global_mouse_position() - global_position).normalized()

		snowball_instance.set_direction(throw_direction)
