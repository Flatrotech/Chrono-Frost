extends Area2D

@export var speed = 400.0
var direction = Vector2.RIGHT  # Default direction

func _physics_process(delta):
	position += direction * speed * delta

	# Check if the snowball is outside the screen
	var viewport_rect = get_viewport_rect()
	if !viewport_rect.has_point(position):
		queue_free()  # Destroy the snowball

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()

func _on_body_entered(body):
	# Handle collision with other bodies (e.g., enemies) here
	# For now, just destroy the snowball
	queue_free()
