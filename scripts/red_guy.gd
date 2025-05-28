extends CharacterBody2D

# Movement properties (similar to player)
@export var grid_size = 8
@export var move_speed = 1.2  # Slightly slower and smoother movement
@export var detection_radius = 300  # Much larger detection range
@export var attack_range = 150  # Increased attack range
@export var retreat_distance = 80  # Increased retreat distance

# Arena boundary constraints
@export var arena_bounds = Rect2(10, 10, 485, 235)  # Arena boundaries (with some padding)
@export var center_line_x = 252  # X coordinate of center line - enemy cannot cross this
@export var enemy_side_min_x = 270  # Minimum X position for enemy (right side of arena) - more reasonable buffer

# Combat properties
@export var snowball_scene : PackedScene
@export var throw_offset = Vector2(-20, 0)  # Enemy faces left, so negative offset
@export var throw_cooldown = 0.8  # Slightly slower than player
var throw_timer = 0.0

# Temperature/Health System
@export var max_warmth = 100.0  # Maximum warmth (health)
@export var warmth_loss_per_hit = 25.0  # Warmth lost when hit by snowball
@export var warmth_regen_rate = 3.0  # Slightly slower regen than player
@export var warmth_regen_delay = 4.0  # Longer delay than player
var current_warmth = 100.0  # Current warmth level
var last_damage_time = 0.0  # Time since last damage
var is_frozen = false  # Whether enemy is defeated (frozen)

# AI State system
enum AIState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETREAT,
	DODGE
}

var current_state = AIState.IDLE
var state_timer = 0.0

# State variables
var target_pos = Vector2()
var moving = false
var move_dir = Vector2()
var player = null  # Reference to player

# AI behavior variables
var last_player_pos = Vector2()
var patrol_points = []
var current_patrol_index = 0
var dodge_direction = Vector2()
var dodge_timer = 0.0
var reaction_delay = 0.3  # Time before reacting to player actions
var reaction_timer = 0.0

@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	# Initialize position and animation
	position = position.snapped(Vector2(grid_size, grid_size))
	target_pos = position
	animated_sprite_2d.play("default")
	
	print("DEBUG: Red Guy _ready() called")
	
	# Initialize temperature system
	current_warmth = max_warmth
	is_frozen = false
	last_damage_time = 0.0
	
	# Add to enemies group so snowballs can damage us
	add_to_group("enemies")
	print("DEBUG: Red Guy added to enemies group")
	
	# Try to find the player in the scene
	player = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
	
	if player:
		print("DEBUG: Red Guy found player: ", player.name)
	else:
		print("DEBUG: Red Guy - NO PLAYER FOUND!")
	
	# Set up patrol points around the starting position
	setup_patrol_points()
	
	# Start in patrol mode for more predictable initial behavior
	if player:
		print("AI: Player found! Starting in PATROL mode for initial movement")
		change_state(AIState.PATROL)
	else:
		print("AI: No player found, starting in PATROL mode")
		change_state(AIState.PATROL)

func setup_patrol_points():
	# Create a simple patrol pattern on the enemy side of the arena
	# Ensure all patrol points are on the enemy side and within bounds
	var safe_x_min = max(enemy_side_min_x, arena_bounds.position.x)
	var safe_x_max = arena_bounds.position.x + arena_bounds.size.x - 20  # Some padding from edge
	var safe_y_min = arena_bounds.position.y + 20  # Some padding from edge
	var safe_y_max = arena_bounds.position.y + arena_bounds.size.y - 20
	
	print("AI: Setting up patrol points:")
	print("AI: safe_x_min=", safe_x_min, " safe_x_max=", safe_x_max)
	print("AI: safe_y_min=", safe_y_min, " safe_y_max=", safe_y_max)
	
	patrol_points = [
		Vector2(safe_x_min, safe_y_min),  # Top-left of enemy side
		Vector2(safe_x_max, safe_y_min),  # Top-right
		Vector2(safe_x_max, safe_y_max),  # Bottom-right
		Vector2(safe_x_min, safe_y_max)   # Bottom-left of enemy side
	]
	
	# Snap all patrol points to grid
	for i in range(patrol_points.size()):
		patrol_points[i] = patrol_points[i].snapped(Vector2(grid_size, grid_size))
		print("AI: Patrol point ", i, ": ", patrol_points[i])

func _physics_process(delta):
	# Update timers
	if throw_timer > 0:
		throw_timer -= delta
	if reaction_timer > 0:
		reaction_timer -= delta
	if dodge_timer > 0:
		dodge_timer -= delta
	state_timer += delta
	last_damage_time += delta
	
	# Update temperature system
	update_temperature_system(delta)
	
	# Don't process AI if frozen
	if is_frozen:
		animated_sprite_2d.play("default")
		return
	
	# AI decision making
	update_ai_state()
	execute_current_state(delta)
	
	# Handle movement
	handle_movement(delta)

func update_ai_state():
	if not player:
		return
	
	var distance_to_player = position.distance_to(player.position)
	var can_see_player = can_see_target(player.position)
	
	# Reduced debug output to prevent jitter
	if state_timer > 1.0:  # Only print state updates every second
		print("AI: Distance: ", int(distance_to_player), " Can see: ", can_see_player, " State: ", AIState.keys()[current_state])
	
	# State transitions based on distance and conditions
	match current_state:
		AIState.IDLE, AIState.PATROL:
			if can_see_player and distance_to_player <= detection_radius:
				change_state(AIState.CHASE)
			elif distance_to_player <= attack_range:
				# Even if we can't see the player, if they're close enough, go to attack mode
				change_state(AIState.ATTACK)
		
		AIState.CHASE:
			if distance_to_player <= attack_range:
				change_state(AIState.ATTACK)
			elif distance_to_player > detection_radius * 1.5:  # More lenient before giving up chase
				change_state(AIState.PATROL)
			elif distance_to_player < retreat_distance:
				change_state(AIState.RETREAT)
		
		AIState.ATTACK:
			if distance_to_player > attack_range * 1.5:  # More lenient before switching to chase
				change_state(AIState.CHASE)
			elif distance_to_player < retreat_distance:
				change_state(AIState.RETREAT)
			# Occasionally dodge if player is aiming at us
			elif should_dodge() and dodge_timer <= 0:
				change_state(AIState.DODGE)
		
		AIState.RETREAT:
			if distance_to_player > retreat_distance * 1.5:
				change_state(AIState.ATTACK)  # Go directly to attack instead of chase
		
		AIState.DODGE:
			if dodge_timer <= 0:
				change_state(AIState.ATTACK)

func change_state(new_state: AIState):
	var old_state_name = AIState.keys()[current_state]
	var new_state_name = AIState.keys()[new_state]
	print("AI: State change: ", old_state_name, " -> ", new_state_name)
	
	current_state = new_state
	state_timer = 0.0
	
	match new_state:
		AIState.DODGE:
			dodge_timer = 1.0
			# Pick a valid dodge direction that stays within bounds
			dodge_direction = get_valid_dodge_direction()
			print("AI: Dodge direction selected: ", dodge_direction)

func execute_current_state(_delta):
	if not player:
		return
	
	match current_state:
		AIState.IDLE:
			# Just wait
			if state_timer > 2.0:
				change_state(AIState.PATROL)
		
		AIState.PATROL:
			patrol_behavior()
		
		AIState.CHASE:
			chase_behavior()
		
		AIState.ATTACK:
			attack_behavior()
		
		AIState.RETREAT:
			retreat_behavior()
		
		AIState.DODGE:
			dodge_behavior()

func patrol_behavior():
	if not moving:
		var target_patrol = patrol_points[current_patrol_index]
		if position.distance_to(target_patrol) < grid_size:
			# Reached patrol point, go to next one
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			target_patrol = patrol_points[current_patrol_index]
		
		move_towards_position(target_patrol)

func chase_behavior():
	if not moving and player:
		print("AI: Chase behavior - trying to find valid chase position")
		# Instead of moving directly toward player, find the best valid position
		# that gets us closer while respecting boundaries
		var best_position = find_valid_chase_position(player.position)
		print("AI: Best chase position found: ", best_position)
		if best_position != Vector2.ZERO:
			move_towards_position(best_position)
		else:
			print("AI: No valid chase position found, checking alternatives")
			# If we can't chase, try to attack if in range, otherwise patrol
			var distance_to_player = position.distance_to(player.position)
			if distance_to_player <= attack_range and throw_timer <= 0:
				print("AI: Switching to attack mode, distance: ", distance_to_player)
				change_state(AIState.ATTACK)
			else:
				print("AI: Can't attack either, distance too far: ", distance_to_player)
				# Force some movement even if not optimal
				print("AI: Forcing random movement to unstick")
				var random_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
				for direction in random_directions:
					var test_pos = position + direction * grid_size
					if is_valid_position(test_pos):
						move_towards_position(test_pos)
						break
				# If still stuck, switch to patrol
				if not moving:
					print("AI: Stuck in chase, switching to patrol to unstick")
					change_state(AIState.PATROL)

func attack_behavior():
	if player and throw_timer <= 0:
		# Try to throw snowball at player - be more aggressive
		var distance_to_player = position.distance_to(player.position)
		if distance_to_player <= attack_range:
			print("AI: Attempting to attack player at distance: ", distance_to_player)
			# Temporarily disable line of sight requirement for testing
			# if can_see_target(player.position):
			print("AI: Throwing snowball (line of sight check disabled for testing)!")
			throw_snowball_at_target(player.position)
			throw_timer = throw_cooldown
			# else:
			#	print("AI: No line of sight to player")
		else:
			print("AI: Player too far for attack: ", distance_to_player, " > ", attack_range)
	elif throw_timer > 0:
		if state_timer > 1.0:  # Reduce debug spam
			print("AI: Attack on cooldown: ", throw_timer)
	
	# Reduced movement frequency to reduce jitter
	if not moving and randf() < 0.1 and state_timer > 0.5:  # Much less frequent movement
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * grid_size
		var new_pos = position + offset
		if is_valid_position(new_pos):
			move_towards_position(new_pos)

func retreat_behavior():
	if not moving and player:
		# Move away from player
		var away_direction = (position - player.position).normalized()
		var retreat_target = position + away_direction * grid_size * 3
		move_towards_position(retreat_target)

func dodge_behavior():
	if not moving:
		var dodge_target = position + dodge_direction * grid_size * 2
		move_towards_position(dodge_target)

func should_dodge():
	# Simple heuristic: dodge if player is facing us and close enough
	if not player:
		return false
	
	var _player_to_enemy = (position - player.position).normalized()
	# This is a simplified check - in a real game you'd check player's aim direction
	return randf() < 0.2 and position.distance_to(player.position) < attack_range

func can_see_target(target_position: Vector2) -> bool:
	# Simplified line of sight - just check if not blocked by static bodies (walls)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(position, target_position)
	
	# Exclude ourselves and the player from the collision check - fix the RID error
	var exclude_array = []
	exclude_array.append(get_rid())
	if player:
		exclude_array.append(player.get_rid())
	query.exclude = exclude_array
	
	var result = space_state.intersect_ray(query)
	
	# Reduced debug output to prevent jitter - only log occasionally
	if state_timer > 2.0:
		print("AI: Line of sight check - Empty result: ", result.is_empty())
		if not result.is_empty():
			print("AI: Hit collider: ", result.collider)
	
	# If no collision, we can see the target
	return result.is_empty()

func move_towards_position(target: Vector2):
	if not moving:
		var direction = (target - position).normalized()
		
		# Snap to grid directions for clean movement
		if abs(direction.x) > abs(direction.y):
			move_dir = Vector2(sign(direction.x), 0)
		else:
			move_dir = Vector2(0, sign(direction.y))
		
		var potential_target = position + move_dir * grid_size
		
		# Check boundary constraints before moving
		var valid_pos = is_valid_position(potential_target)
		
		# Simplified collision check - be more permissive for now
		var no_collision = true  # Temporarily disable collision checks to test movement
		
		if valid_pos and no_collision:
			target_pos = potential_target
			moving = true
			# Reduced debug output - only log occasionally
			if state_timer > 1.0:
				print("AI: Moving to: ", target_pos)
		else:
			# Only log when movement is blocked
			if state_timer > 1.0:
				print("AI: Movement blocked! Valid: ", valid_pos)

func is_valid_position(pos: Vector2) -> bool:
	# Check if position is within arena bounds
	if not arena_bounds.has_point(pos):
		print("AI: Position ", pos, " rejected - outside arena bounds")
		return false
	
	# Check if position respects center line (enemy must stay on right side)
	if pos.x < enemy_side_min_x:
		print("AI: Position ", pos, " rejected - crossing center line (x=", pos.x, " < ", enemy_side_min_x, ")")
		return false
	
	return true

func get_valid_dodge_direction() -> Vector2:
	# Get all possible dodge directions
	var dodge_options = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var valid_directions = []
	
	# Filter directions that would keep us within bounds
	for direction in dodge_options:
		var test_pos = position + direction * grid_size * 2
		if is_valid_position(test_pos):
			valid_directions.append(direction)
	
	# If no valid directions, stay in place
	if valid_directions.is_empty():
		return Vector2.ZERO
	
	# Return a random valid direction
	return valid_directions[randi() % valid_directions.size()]

func find_valid_chase_position(target_position: Vector2) -> Vector2:
	# Find the best valid position to move toward while chasing
	var current_distance = position.distance_to(target_position)
	var best_position = Vector2.ZERO
	var best_distance = current_distance
	
	# Try all cardinal directions
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for direction in directions:
		var test_pos = position + direction * grid_size
		if is_valid_position(test_pos):
			var new_distance = test_pos.distance_to(target_position)
			# Choose the position that gets us closer to the target
			if new_distance < best_distance:
				best_position = test_pos
				best_distance = new_distance
	
	return best_position

func handle_movement(_delta):
	if moving:
		animated_sprite_2d.play("walk")
		
		var distance_vec = target_pos - position
		var distance_length = distance_vec.length()
		
		if distance_length <= 0.5:
			position = target_pos
			moving = false
		else:
			var move_step = move_dir * move_speed
			position += move_step
			
			var new_dist = (target_pos - position).length()
			if new_dist < distance_length / 2:
				position = target_pos
				moving = false
	else:
		animated_sprite_2d.play("default")

func throw_snowball_at_target(target_position: Vector2):
	print("AI: throw_snowball_at_target called")
	if snowball_scene:
		print("AI: snowball_scene exists, creating snowball")
		var snowball_instance = snowball_scene.instantiate()
		get_parent().add_child(snowball_instance)
		
		snowball_instance.position = position + throw_offset
		print("AI: Snowball created at position: ", snowball_instance.position)
		
		# Set the thrower to prevent self-damage
		snowball_instance.set_thrower(self)
		
		# Calculate direction to target with slight prediction
		var target_direction = (target_position - position).normalized()
		
		# Add slight prediction if player is moving
		if player and player.has_method("get_velocity") and player.velocity.length() > 0:
			var predicted_pos = target_position + player.velocity * 0.3
			target_direction = (predicted_pos - position).normalized()
		
		snowball_instance.set_direction(target_direction)
		print("AI: Snowball thrown in direction: ", target_direction)
	else:
		print("AI: ERROR - snowball_scene is null!")

func would_collide(pos):
	# Use a more reliable collision check
	var motion = pos - position
	var collision = test_move(transform, motion)
	print("AI: Collision check - Motion: ", motion, " Would collide: ", collision)
	
	# For now, let's be more permissive to prevent getting stuck
	# Only block if there's a static body collision (walls)
	if collision:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(position, pos)
		query.exclude = [get_rid()]
		if player:
			query.exclude.append(player.get_rid())
		
		var result = space_state.intersect_ray(query)
		if not result.is_empty() and result.collider is StaticBody2D:
			print("AI: Blocked by wall: ", result.collider)
			return true
	
	return false

# Temperature/Health System functions
func update_temperature_system(delta):
	# Handle warmth regeneration (only if not frozen and enough time has passed)
	if not is_frozen and last_damage_time >= warmth_regen_delay:
		current_warmth = min(current_warmth + warmth_regen_rate * delta, max_warmth)
	
	# Check if enemy is frozen
	if current_warmth <= 0 and not is_frozen:
		freeze_enemy()

func take_damage(damage_amount: float):
	if is_frozen:
		return  # Can't take damage when already frozen
	
	current_warmth = max(current_warmth - damage_amount, 0)
	last_damage_time = 0.0  # Reset damage timer
	
	print("Enemy hit! Warmth: ", current_warmth, "/", max_warmth)
	
	# Add visual/audio feedback here
	# TODO: Add damage feedback effects

func freeze_enemy():
	is_frozen = true
	print("Enemy is frozen! Player wins!")
	animated_sprite_2d.play("default")
	
	# TODO: Add freeze visual effects, victory screen, etc.
	# For now, just disable AI

func get_warmth_percentage() -> float:
	return current_warmth / max_warmth

# Function to respawn enemy (for game restart)
func respawn():
	current_warmth = max_warmth
	is_frozen = false
	last_damage_time = 0.0
	change_state(AIState.PATROL)
	print("Enemy respawned!")

func _input(event):
	# Debug controls for testing enemy temperature system
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_5:
				# Test enemy damage
				take_damage(25.0)
				print("DEBUG: Enemy took 25 damage! Current warmth: ", current_warmth)
			KEY_6:
				# Test enemy healing
				current_warmth = min(current_warmth + 25.0, max_warmth)
				print("DEBUG: Enemy healed 25 warmth! Current warmth: ", current_warmth)
			KEY_7:
				# Test instant freeze
				current_warmth = 0
				print("DEBUG: Enemy instantly frozen!")
			KEY_8:
				# Test respawn
				respawn()
				print("DEBUG: Enemy respawned!")

# Debug function to visualize AI state
func _draw():
	if Engine.is_editor_hint():
		return
	
	# Draw detection radius
	draw_circle(Vector2.ZERO, detection_radius, Color.RED, false, 2.0)
	draw_circle(Vector2.ZERO, attack_range, Color.ORANGE, false, 2.0)
	
	# Draw arena boundaries and center line (relative to enemy position)
	var enemy_to_arena = arena_bounds.position - global_position
	draw_rect(Rect2(enemy_to_arena, arena_bounds.size), Color.BLUE, false, 1.0)
	
	# Draw center line restriction
	var center_line_pos = Vector2(center_line_x - global_position.x, enemy_to_arena.y)
	draw_line(center_line_pos, center_line_pos + Vector2(0, arena_bounds.size.y), Color.YELLOW, 2.0)
	
	# Draw enemy side minimum boundary
	var enemy_min_pos = Vector2(enemy_side_min_x - global_position.x, enemy_to_arena.y)
	draw_line(enemy_min_pos, enemy_min_pos + Vector2(0, arena_bounds.size.y), Color.GREEN, 2.0)
	
	# Draw current state
	var _state_text = AIState.keys()[current_state]
	# Note: You'd need to implement text drawing or use a Label node for this
