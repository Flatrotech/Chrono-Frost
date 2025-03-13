extends Control

signal joystick_input(direction)
signal throw_button_pressed()  # New signal for throw action

@export var outer_radius = 80
@export var inner_radius = 40
@export var dead_zone = 0.2
@export var throw_button_radius = 50  # Size of the throw button

var touch_index_left = -1  # Track left side touch
var touch_index_right = -1  # Track right side touch
var touch_active = false
var touch_position = Vector2.ZERO
var joystick_center = Vector2.ZERO
var joystick_direction = Vector2.ZERO

# Add tracking for throw button position
var throw_button_position = Vector2.ZERO
var throw_button_active = false

func _ready():
	# Make control fill the entire screen
	var viewport_size = get_viewport_rect().size
	custom_minimum_size = viewport_size
	size = viewport_size
	
	# Initialize position at origin (fill entire screen)
	position = Vector2.ZERO
	modulate.a = 0.5  # Semi-transparent
	
	# Initialize throw button position
	throw_button_position = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.5)

func _input(event):
	var viewport_size = get_viewport_rect().size
	var screen_center_x = viewport_size.x / 2
	
	# Handle touch events
	if event is InputEventScreenTouch:
		# Check if touch is on left or right side of screen
		var is_left_side = event.position.x < screen_center_x
		
		# Left side - joystick
		if is_left_side:
			if event.pressed and touch_index_left == -1:
				# New touch on left side
				touch_index_left = event.index
				touch_active = true
				joystick_center = event.position
				touch_position = event.position
			elif !event.pressed and event.index == touch_index_left:
				# Left touch released
				touch_index_left = -1
				touch_active = false
				joystick_direction = Vector2.ZERO
				emit_signal("joystick_input", Vector2.ZERO)
		
		# Right side - throw button
		else:
			if event.pressed and touch_index_right == -1:
				# New touch on right side
				touch_index_right = event.index
				throw_button_active = true
				throw_button_position = event.position  # Set throw button position to touch point
				emit_signal("throw_button_pressed")  # Emit throw signal
			elif !event.pressed and event.index == touch_index_right:
				# Right touch released
				touch_index_right = -1
				throw_button_active = false
	
	# Handle drag events for joystick
	elif event is InputEventScreenDrag and event.index == touch_index_left:
		# Update touch position when dragging
		touch_position = event.position
		
		# Calculate joystick direction and distance
		joystick_direction = (touch_position - joystick_center).normalized()
		var distance = touch_position.distance_to(joystick_center)
		
		# Apply dead zone
		if distance < dead_zone * outer_radius:
			joystick_direction = Vector2.ZERO
		
		# Emit signal with direction
		emit_signal("joystick_input", joystick_direction)

func _draw():
	var viewport_size = get_viewport_rect().size
	var screen_center_x = viewport_size.x / 2
	
	# Draw divider line
	draw_line(Vector2(screen_center_x, 0), Vector2(screen_center_x, viewport_size.y), 
			Color(1, 1, 1, 0.3), 2)
	
	# Only draw joystick controls if active
	if touch_active:
		# Draw joystick outer circle
		draw_circle(joystick_center, outer_radius, Color(0.5, 0.5, 0.5, 0.3))
		
		# Draw joystick handle
		var handle_pos = joystick_center + joystick_direction * min(touch_position.distance_to(joystick_center), outer_radius - inner_radius/2)
		draw_circle(handle_pos, inner_radius, Color(0.8, 0.8, 0.8, 0.5))
	
	# Draw throw button indicator only when active
	if throw_button_active:
		draw_circle(throw_button_position, throw_button_radius, Color(0.9, 0.3, 0.3, 0.5))  # Red circle for throw button
		draw_string(get_theme_default_font(), throw_button_position - Vector2(25, 0), "THROW", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))

func _process(delta):
	queue_redraw()  # Continuously update the visual
