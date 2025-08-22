class_name Player
extends Node2D

## Player controller for Mini MMO client
## Handles movement input, client-side prediction, and network synchronization

@export var move_speed: float = 200.0
@export var enable_prediction: bool = true

var velocity: Vector2 = Vector2.ZERO
var server_position: Vector2 = Vector2.ZERO
var server_velocity: Vector2 = Vector2.ZERO
var input_sequence: int = 0
var pending_inputs: Array[Dictionary] = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Set initial position
	position = Vector2(400, 300)
	server_position = position

func _process(delta: float) -> void:
	handle_input(delta)
	
	if enable_prediction:
		apply_client_prediction(delta)
	else:
		apply_direct_movement(delta)

func handle_input(delta: float) -> void:
	var input_vector = Vector2.ZERO
	
	# WASD movement input
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	
	# Normalize diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	velocity = input_vector * move_speed
	
	# Store input for server reconciliation
	if input_vector.length() > 0 or velocity.length() > 0:
		input_sequence += 1
		var input_data = {
			"sequence": input_sequence,
			"input": input_vector,
			"timestamp": Time.get_time_dict_from_system(),
			"delta": delta
		}
		pending_inputs.append(input_data)
		
		# Send to server (placeholder - will be implemented with networking)
		send_input_to_server(input_data)

func apply_client_prediction(delta: float) -> void:
	# Apply movement locally for immediate feedback
	position += velocity * delta
	
	# Update sprite direction based on movement
	update_sprite_direction()

func apply_direct_movement(delta: float) -> void:
	# Move directly without prediction (useful for testing)
	position += velocity * delta
	update_sprite_direction()

func update_sprite_direction() -> void:
	if velocity.length() > 0:
		# Rotate sprite to face movement direction
		sprite.rotation = velocity.angle() + PI/2

func send_input_to_server(input_data: Dictionary) -> void:
	# Placeholder for network implementation
	# This will send the input to the server for authoritative processing
	pass

func receive_server_snapshot(server_data: Dictionary) -> void:
	# Placeholder for server reconciliation
	# This will handle server position updates and input reconciliation
	server_position = Vector2(server_data.get("x", position.x), server_data.get("y", position.y))
	server_velocity = Vector2(server_data.get("vel_x", 0), server_data.get("vel_y", 0))
	
	# Remove acknowledged inputs
	var ack_sequence = server_data.get("ack_sequence", 0)
	pending_inputs = pending_inputs.filter(func(input): return input.sequence > ack_sequence)
	
	if enable_prediction:
		reconcile_with_server(server_data)

func reconcile_with_server(server_data: Dictionary) -> void:
	# Server reconciliation logic
	var position_error = (server_position - position).length()
	
	# If error is significant, snap to server position and replay inputs
	if position_error > 5.0:  # 5 pixel threshold
		position = server_position
		
		# Replay pending inputs
		for input_data in pending_inputs:
			var input_vector = input_data.input
			var delta = input_data.delta
			position += input_vector * move_speed * delta

func toggle_prediction() -> void:
	enable_prediction = !enable_prediction
	print("Client prediction: ", "enabled" if enable_prediction else "disabled")
