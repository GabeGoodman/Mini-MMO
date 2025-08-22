class_name Main
extends Node2D

## Main game scene controller for Mini MMO client
## Manages the game world, camera, and overall game state

@onready var camera: Camera2D = $Camera2D
@onready var player: Player = $Player
@onready var debug_overlay: DebugOverlay = $UI/DebugOverlay

var game_state: String = "playing"  # playing, paused, menu
var world_bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)

func _ready() -> void:
	# Initialize the game
	setup_input_map()
	setup_camera()
	setup_player()
	
	print("Mini MMO Client initialized")
	print("Controls: WASD to move, F1 to toggle debug, F2 to toggle prediction")

func setup_input_map() -> void:
	# Define input actions if they don't exist
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		var event = InputEventKey.new()
		event.keycode = KEY_A
		InputMap.action_add_event("move_left", event)
		# Also add arrow key
		event = InputEventKey.new()
		event.keycode = KEY_LEFT
		InputMap.action_add_event("move_left", event)
	
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		var event = InputEventKey.new()
		event.keycode = KEY_D
		InputMap.action_add_event("move_right", event)
		# Also add arrow key
		event = InputEventKey.new()
		event.keycode = KEY_RIGHT
		InputMap.action_add_event("move_right", event)
	
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
		var event = InputEventKey.new()
		event.keycode = KEY_W
		InputMap.action_add_event("move_up", event)
		# Also add arrow key
		event = InputEventKey.new()
		event.keycode = KEY_UP
		InputMap.action_add_event("move_up", event)
	
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		InputMap.action_add_event("move_down", event)
		# Also add arrow key
		event = InputEventKey.new()
		event.keycode = KEY_DOWN
		InputMap.action_add_event("move_down", event)
	
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var event = InputEventKey.new()
		event.keycode = KEY_F1
		InputMap.action_add_event("toggle_debug", event)
	
	if not InputMap.has_action("toggle_prediction"):
		InputMap.add_action("toggle_prediction")
		var event = InputEventKey.new()
		event.keycode = KEY_F2
		InputMap.action_add_event("toggle_prediction", event)

func setup_camera() -> void:
	if camera:
		# Set camera to follow player
		camera.enabled = true
		# Set reasonable zoom level
		camera.zoom = Vector2(1.0, 1.0)
		
		# Enable camera smoothing
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 10.0

func setup_player() -> void:
	if player:
		# Add player to a group for easy reference
		player.add_to_group("player")
		
		# Set initial spawn position
		player.position = Vector2(0, 0)

func _process(delta: float) -> void:
	# Update camera to follow player
	if player and camera:
		camera.global_position = player.global_position
	
	# Handle game state
	handle_game_input()
	
	# Keep player within world bounds
	enforce_world_bounds()

func handle_game_input() -> void:
	# Handle pause/menu toggles
	if Input.is_action_just_pressed("ui_cancel"):  # ESC key
		toggle_pause()

func enforce_world_bounds() -> void:
	if player:
		var player_pos = player.global_position
		var clamped_pos = Vector2(
			clamp(player_pos.x, world_bounds.position.x, world_bounds.position.x + world_bounds.size.x),
			clamp(player_pos.y, world_bounds.position.y, world_bounds.position.y + world_bounds.size.y)
		)
		
		if player_pos != clamped_pos:
			player.global_position = clamped_pos

func toggle_pause() -> void:
	if game_state == "playing":
		game_state = "paused"
		get_tree().paused = true
		print("Game paused")
	else:
		game_state = "playing"
		get_tree().paused = false
		print("Game resumed")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				toggle_pause()
			KEY_F3:
				# Toggle fullscreen
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
