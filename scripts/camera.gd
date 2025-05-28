extends Camera2D

@export var world_size = Vector2(1024, 768)  

func _ready():
	update_zoom()
	
	get_viewport().size_changed.connect(update_zoom)

func update_zoom():
	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / world_size.x
	var zoom_y = viewport_size.y / world_size.y
	var calculated_zoom = min(zoom_x, zoom_y)

	calculated_zoom = max(calculated_zoom, 0.1) # Minimum zoom to prevent it from becoming too small

	self.zoom = Vector2(calculated_zoom, calculated_zoom)
