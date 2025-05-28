extends CharacterBody2D

# Movement properties
@export var grid_size = 8  # Size of grid to snap to (typically match your tile size)
@export var move_speed = 2  # Pixels per frame when moving
@export var slow_down_distance = 2.0  # Start slowing down when this close to target

# snowball throwing exports
@export var snowball_scene : PackedScene
@export var throw_offset = Vector2(20,0)
@export var throw_cooldown = 0.5  # Time in seconds between throws
var throw_timer = 0.0  # Current cooldown timer

# Add at the top with other properties
@export var joystick_scene : PackedScene  # Reference to the virtual joystick scene
var is_mobile = false
var joystick_input = Vector2.ZERO
var virtual_joystick = null

# Add at the top with other properties
@export var debug_force_mobile = false  # Toggle in editor to force mobile mode

# Movement state
var target_pos = Vector2()
var moving = false
var move_dir = Vector2()
var prev_mouse_pressed = false  # Track previous mouse state

@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	# Improved mobile detection that works with web browsers
	animated_sprite_2d.play("default")
	is_mobile = detect_mobile_device() or debug_force_mobile
	if is_mobile:
		setup_mobile_controls()
	
	# Initialize target position to current position
	# Snap initial position to grid
	position = position.snapped(Vector2(grid_size, grid_size))
	target_pos = position
	throw_timer = 0.0  # Start with no cooldown

func detect_mobile_device():
	# Standard OS detection
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS":
		return true
		
	# Web-specific detection for mobile browsers
	if OS.has_feature("web"):
		# Check if the viewport size suggests a mobile device (portrait mode or small screen)
		var screen_size = get_viewport_rect().size
		var min_dimension = min(screen_size.x, screen_size.y)
		var max_dimension = max(screen_size.x, screen_size.y)
		
		# Portrait orientation or small screen suggests mobile
		if screen_size.y > screen_size.x or max_dimension < 900:
			return true
			
		# Try to use JavaScript to detect mobile browsers
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			# This checks for common mobile browser user agents
			var is_mobile_js = false
			var eval_result = js.eval("""
				(function() {
					return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
				})();
			""")
			if eval_result is String and eval_result.empty():
				print("JavaScript evaluation failed")
			else:
				is_mobile_js = eval_result
				
			if is_mobile_js:
				return true
				
	return false

func setup_mobile_controls():
	# Load and add the virtual joystick
	virtual_joystick = joystick_scene.instantiate()
	
	# Create a CanvasLayer to ensure it stays on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10  # High layer value to be on top
	canvas_layer.add_child(virtual_joystick)
	add_child(canvas_layer)
	
	# Connect joystick signals
	virtual_joystick.joystick_input.connect(self._on_joystick_input)
	virtual_joystick.throw_button_pressed.connect(self._on_throw_button_pressed)
	
	print("Mobile controls set up")

func _on_throw_button_pressed():
	if throw_timer <= 0:
		throw_snowball()
		throw_timer = throw_cooldown

func _on_joystick_input(direction):
	joystick_input = direction

func _physics_process(delta):
	# Update throw cooldown timer
	if throw_timer > 0:
		throw_timer -= delta

	# Handle standard PC controls
	if not is_mobile:
		handle_pc_input()
	else:
		handle_mobile_input(delta)
	
	# Movement logic stays the same
	if not moving:
		# Check for new movement input when not already moving
		animated_sprite_2d.play("default")
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
			
			# Check for collision before setting target position
			var potential_target = position + move_dir * grid_size
			if not would_collide(potential_target):
				target_pos = potential_target
				moving = true
	else:
		animated_sprite_2d.play("walk")

		# Move toward target position
		var distance_vec = target_pos - position
		var distance_length = distance_vec.length()
		
		if distance_length <= 0.5:
			# We've reached or nearly reached the target position
			position = target_pos
			moving = false
		else:
			 # Move at constant speed for snappy movement
			var move_step = move_dir * move_speed
			
			# Apply movement directly for snappier feel
			position += move_step
			
			# Optional: Check if we're about to overshoot the target
			var new_dist = (target_pos - position).length()
			if new_dist < distance_length / 2:
				# Getting close, snap to target
				position = target_pos
				moving = false

func handle_pc_input():
	# Check for mouse clicks (for throwing)
	var mouse_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_pressed and not prev_mouse_pressed and throw_timer <= 0:
		throw_snowball()
		throw_timer = throw_cooldown
	prev_mouse_pressed = mouse_pressed
	
	if not moving:
		# Get keyboard movement input
		var input_dir = Vector2.ZERO
		
		# WASD movement
		if Input.is_key_pressed(KEY_D): input_dir.x += 1
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_key_pressed(KEY_S): input_dir.y += 1
		if Input.is_key_pressed(KEY_W): input_dir.y -= 1
		
		# Arrow keys
		input_dir.x += Input.get_axis("ui_left", "ui_right")
		input_dir.y += Input.get_axis("ui_up", "ui_down")
		
		process_movement_input(input_dir)

func handle_mobile_input(_delta):
	# Use the joystick input for movement
	if not moving and joystick_input.length() > 0.5:  # Add a threshold to prevent small movements
		process_movement_input(joystick_input)
	
	# Handle taps for throwing (use a separate touch detection for throwing)
	if Input.is_action_just_pressed("ui_touch") and throw_timer <= 0:
		# Remove unused variable
		var world_touch_pos = get_global_mouse_position()
		
		# Use touch_index_left instead of touch_index
		if virtual_joystick and virtual_joystick.touch_index_left == -1:
			throw_snowball()
			throw_timer = throw_cooldown

func process_movement_input(input_dir):
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		move_dir = input_dir
		
		# Check for collision before setting target position
		var potential_target = position + move_dir * grid_size
		if not would_collide(potential_target):
			target_pos = potential_target
			moving = true

func throw_snowball():
	if snowball_scene:
		var snowball_instance = snowball_scene.instantiate()
		get_parent().add_child(snowball_instance)
		
		# Set snowball position
		snowball_instance.position = position + throw_offset
		
		# Get mouse position relative to player
		var mouse_pos = get_global_mouse_position()
		var player_to_mouse = mouse_pos - global_position
		
		# Calculate angle to mouse (in radians)
		var angle = player_to_mouse.angle()
		
		# Optional: Restrict to a 180-degree arc in front of player
		# Normalize angle to range of -PI to PI
		while angle > PI:
			angle -= 2 * PI
		while angle < -PI:
			angle += 2 * PI
			
		# Restrict to frontal arc (-PI/2 to PI/2 is front 180 degrees)
		angle = clamp(angle, -PI/2, PI/2)
		
		# Create direction vector from angle
		var throw_direction = Vector2(cos(angle), sin(angle))
		
		# Pass direction to snowball
		snowball_instance.set_direction(throw_direction)
		
		# Optional: Show debug info
		print("Throw angle: ", rad_to_deg(angle), " degrees")

# Fixed collision check using CharacterBody2D's built-in test_move method
func would_collide(pos):
	# Calculate the motion vector from current position to target position
	var motion = pos - position
	
	# Use CharacterBody2D's test_move to check if this movement would cause a collision
	return test_move(transform, motion)
