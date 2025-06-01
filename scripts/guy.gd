extends CharacterBody2D

# Movement properties
@export var grid_size = 8  # Size of grid to snap to (typically match your tile size)
@export var move_speed = 2  # Pixels per frame when moving
@export var slow_down_distance = 2.0  # Start slowing down when this close to target

# Temperature/Health System
@export var max_warmth = 100.0  # Maximum warmth (health)
@export var warmth_loss_per_hit = 25.0  # Warmth lost when hit by snowball
@export var warmth_regen_rate = 5.0  # Warmth gained per second when not taking damage
@export var warmth_regen_delay = 3.0  # Seconds to wait before regenerating warmth
var current_warmth = 100.0  # Current warmth level
var last_damage_time = 0.0  # Time when last damage was taken
var is_frozen = false  # Whether player is defeated (frozen)

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
var current_animation = "default"  # Track current animation to prevent spam

@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	# Add this player to the "player" group so enemies can find it
	add_to_group("player")
	print("DEBUG: Player added to 'player' group")
	
	# Make sure exported values have defaults if they are null in the scene
	if grid_size == null:
		grid_size = 8
	if move_speed == null:
		move_speed = 2
	if slow_down_distance == null:
		slow_down_distance = 2.0
	if max_warmth == null:
		max_warmth = 100.0
	if warmth_loss_per_hit == null:
		warmth_loss_per_hit = 25.0
	if warmth_regen_rate == null:
		warmth_regen_rate = 5.0
	if warmth_regen_delay == null:
		warmth_regen_delay = 3.0
	if throw_cooldown == null:
		throw_cooldown = 0.5
	
	# Initialize temperature system
	current_warmth = max_warmth
	is_frozen = false
	last_damage_time = 0.0
	print("DEBUG: Player temperature system initialized - Warmth: ", current_warmth)
	
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
	print("DEBUG: Player ready complete - Position: ", position)

func detect_mobile_device():
	# Standard OS detection
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS":
		return true
		
	# Web-specific detection for mobile browsers
	if OS.has_feature("web"):
		# Check if the viewport size suggests a mobile device (portrait mode or small screen)
		var screen_size = get_viewport_rect().size
		var _min_dimension = min(screen_size.x, screen_size.y)
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
	if throw_timer != null and throw_timer > 0:
		throw_timer -= delta
	
	# Update temperature system
	update_temperature_system(delta)
	
	# Don't process movement if frozen
	if is_frozen:
		# Use our animation system for consistency
		if current_animation != "default":
			print("DEBUG: Freezing - changing animation to default")
			animated_sprite_2d.play("default")
			current_animation = "default"
		return
	
	# Handle snowball throwing
	var mouse_pressed = Input.is_action_pressed("ui_select") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_pressed and not prev_mouse_pressed and throw_timer <= 0:
		print("DEBUG: Player throwing snowball!")
		throw_snowball()
		throw_timer = throw_cooldown
	prev_mouse_pressed = mouse_pressed

	# Movement logic - check for input first
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
	
	if not moving:
		# Only start new movement when not already moving
		if input_dir != Vector2.ZERO:
			move_dir = input_dir
			
			# Check for collision before setting target position
			var potential_target = position + move_dir * grid_size
			if not would_collide(potential_target):
				target_pos = potential_target
				moving = true
				
				# Play footstep sound when starting to move
				AudioManager.play_footstep()
	else:
		# Move toward target position
		var distance_vec = target_pos - position
		var distance_length = distance_vec.length()
		
		if distance_length <= 0.5:
			# We've reached the target position
			position = target_pos
			moving = false
			
			# Check if we should immediately start a new movement
			if input_dir != Vector2.ZERO:
				move_dir = input_dir
				var potential_target = position + move_dir * grid_size
				if not would_collide(potential_target):
					target_pos = potential_target
					moving = true
					
					# Play footstep sound when starting to move
					AudioManager.play_footstep()
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
				
				# Check if we should immediately start a new movement
				if input_dir != Vector2.ZERO:
					move_dir = input_dir
					var potential_target = position + move_dir * grid_size
					if not would_collide(potential_target):
						target_pos = potential_target
						moving = true
						
						# Play footstep sound when starting to move
						AudioManager.play_footstep()
	
	# Handle animation based on movement state (only change when necessary)
	var desired_animation = "walk" if moving else "default"
	if current_animation != desired_animation:
		print("DEBUG: Changing animation from '", current_animation, "' to '", desired_animation, "'")
		animated_sprite_2d.play(desired_animation)
		current_animation = desired_animation

# Temperature/Health System functions
func update_temperature_system(delta):
	# Update time tracking
	if last_damage_time != null:
		last_damage_time += delta
	
	# Handle warmth regeneration (only if not frozen and enough time has passed)
	if not is_frozen and warmth_regen_delay != null and last_damage_time != null and last_damage_time >= warmth_regen_delay:
		if current_warmth != null and warmth_regen_rate != null and max_warmth != null:
			current_warmth = min(current_warmth + warmth_regen_rate * delta, max_warmth)
	
	# Check if player is frozen
	if current_warmth != null and current_warmth <= 0 and not is_frozen:
		freeze_player()

func take_damage(damage_amount: float):
	if is_frozen:
		return  # Can't take damage when already frozen
	
	current_warmth = max(current_warmth - damage_amount, 0)
	last_damage_time = 0.0  # Reset damage timer
	
	print("Player hit! Warmth: ", current_warmth, "/", max_warmth)
	
	# Play player hit sound effect
	AudioManager.play_player_hit()
	
	# Add visual/audio feedback here (screen shake, sound effect, etc.)
	# TODO: Add damage feedback effects

func freeze_player():
	is_frozen = true
	print("Player is frozen! Game Over!")
	
	# Play freeze sound effect
	AudioManager.play_freeze_sound()
	
	# Use our animation system for consistency
	if current_animation != "default":
		animated_sprite_2d.play("default")
		current_animation = "default"
	
	# TODO: Add freeze visual effects, game over screen, etc.
	# For now, just disable movement

func get_warmth_percentage() -> float:
	# Handle the case where max_warmth is null or 0
	if max_warmth == null or max_warmth == 0:
		return 1.0  # Default to 100% if max_warmth is invalid
	return current_warmth / max_warmth

# Function to respawn/unfreeze player (for game restart)
func respawn():
	current_warmth = max_warmth
	is_frozen = false
	last_damage_time = 0.0
	print("Player respawned!")

func throw_snowball():
	if snowball_scene:
		# Play snowball throw sound effect
		AudioManager.play_snowball_throw()
		
		var snowball_instance = snowball_scene.instantiate()
		get_parent().add_child(snowball_instance)
		
		# Set snowball position
		snowball_instance.position = position + throw_offset
		
		# Set the thrower to prevent self-damage
		snowball_instance.set_thrower(self)
		
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
	
	# Check if target position is within reasonable arena bounds
	var arena_rect = Rect2(10, 10, 485, 235)  # Arena boundaries with padding
	if not arena_rect.has_point(pos):
		return true
	
	# Check center line constraint - player must stay on left side of arena
	var _center_line_x = 252  # X coordinate of center line (for reference)
	var player_side_max_x = 245  # Maximum X position for player (left side of arena)
	if pos.x > player_side_max_x:
		print("DEBUG: Player movement blocked - cannot cross center line (x=", pos.x, " > ", player_side_max_x, ")")
		return true
	
	# Use CharacterBody2D's test_move to check if this movement would cause a collision
	return test_move(transform, motion)

func _input(event):
	# Debug controls for testing temperature system
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Test player damage
				take_damage(25.0)
				print("DEBUG: Player took 25 damage! Current warmth: ", current_warmth)
			KEY_2:
				# Test player healing
				current_warmth = min(current_warmth + 25.0, max_warmth)
				print("DEBUG: Player healed 25 warmth! Current warmth: ", current_warmth)
			KEY_3:
				# Test instant freeze
				current_warmth = 0
				print("DEBUG: Player instantly frozen!")
			KEY_4:
				# Test respawn
				respawn()
				print("DEBUG: Player respawned!")
