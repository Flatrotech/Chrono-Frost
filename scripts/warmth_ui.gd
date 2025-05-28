extends Control

# References to UI elements
@onready var player_warmth_bar = $PlayerWarmthBar
@onready var player_warmth_label = $PlayerWarmthLabel
@onready var enemy_warmth_bar = $EnemyWarmthBar
@onready var enemy_warmth_label = $EnemyWarmthLabel
@onready var game_status_label = $GameStatusLabel

# References to game objects
var player = null
var enemy = null

func _ready():
	# Find player and enemy in the scene
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if players.size() > 0:
		player = players[0]
	
	if enemies.size() > 0:
		enemy = enemies[0]
	
	# Initialize UI
	update_ui()

func _process(_delta):
	update_ui()

func update_ui():
	# Update player warmth
	if player and player.has_method("get_warmth_percentage"):
		var warmth_pct = player.get_warmth_percentage()
		player_warmth_bar.value = warmth_pct * 100
		player_warmth_label.text = "Player Warmth: " + str(int(warmth_pct * 100)) + "%"
		
		# Change color based on warmth level
		if warmth_pct > 0.6:
			player_warmth_bar.modulate = Color.GREEN
		elif warmth_pct > 0.3:
			player_warmth_bar.modulate = Color.YELLOW
		else:
			player_warmth_bar.modulate = Color.RED
	
	# Update enemy warmth
	if enemy and enemy.has_method("get_warmth_percentage"):
		var warmth_pct = enemy.get_warmth_percentage()
		enemy_warmth_bar.value = warmth_pct * 100
		enemy_warmth_label.text = "Enemy Warmth: " + str(int(warmth_pct * 100)) + "%"
		
		# Change color based on warmth level
		if warmth_pct > 0.6:
			enemy_warmth_bar.modulate = Color.GREEN
		elif warmth_pct > 0.3:
			enemy_warmth_bar.modulate = Color.YELLOW
		else:
			enemy_warmth_bar.modulate = Color.RED
	
	# Update game status
	if player and player.is_frozen:
		game_status_label.text = "FROZEN! Enemy Wins!"
		game_status_label.modulate = Color.RED
	elif enemy and enemy.is_frozen:
		game_status_label.text = "VICTORY! Enemy Frozen!"
		game_status_label.modulate = Color.GREEN
	else:
		game_status_label.text = "Fight!"
		game_status_label.modulate = Color.WHITE
