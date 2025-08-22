class_name DebugOverlay
extends Control

## Debug overlay for Mini MMO client
## Displays network metrics, performance data, and development information

@onready var debug_label: Label = $VBoxContainer/DebugLabel
@onready var fps_label: Label = $VBoxContainer/FPSLabel
@onready var position_label: Label = $VBoxContainer/PositionLabel
@onready var network_label: Label = $VBoxContainer/NetworkLabel

var player_reference: Player
var update_timer: float = 0.0
var update_interval: float = 0.1  # Update 10 times per second

# Network metrics (placeholders for now)
var rtt_ms: float = 0.0
var snapshot_sequence: int = 0
var server_tick: int = 0
var packet_loss: float = 0.0
var bandwidth_kbps: float = 0.0

func _ready() -> void:
	# Create UI elements if they don't exist
	if not has_node("VBoxContainer"):
		setup_ui()
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	
	# Position overlay in top-left corner
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 10)

func setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)
	
	# Debug info label
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.text = "DEBUG OVERLAY"
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(debug_label)
	
	# FPS label
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(fps_label)
	
	# Position label
	position_label = Label.new()
	position_label.name = "PositionLabel"
	position_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(position_label)
	
	# Network label
	network_label = Label.new()
	network_label.name = "NetworkLabel"
	network_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(network_label)
	
	# Style the overlay
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.YELLOW
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	add_theme_stylebox_override("panel", style_box)
	vbox.add_theme_constant_override("separation", 2)

func _process(delta: float) -> void:
	update_timer += delta
	
	if update_timer >= update_interval:
		update_debug_info()
		update_timer = 0.0
	
	# Handle debug input
	if Input.is_action_just_pressed("toggle_debug"):
		visible = !visible
	
	if Input.is_action_just_pressed("toggle_prediction") and player_reference:
		player_reference.toggle_prediction()

func update_debug_info() -> void:
	# FPS information
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Position information
	if player_reference:
		var pos = player_reference.position
		var vel = player_reference.velocity
		position_label.text = "Pos: (%.1f, %.1f) | Vel: (%.1f, %.1f)" % [pos.x, pos.y, vel.x, vel.y]
		
		var prediction_status = "ON" if player_reference.enable_prediction else "OFF"
		debug_label.text = "DEBUG OVERLAY | Prediction: %s" % prediction_status
	else:
		position_label.text = "Pos: No player found"
	
	# Network information (placeholder values for now)
	network_label.text = "RTT: %.1fms | Seq: %d | Tick: %d | Loss: %.1f%% | BW: %.1fkbps" % [
		rtt_ms, snapshot_sequence, server_tick, packet_loss, bandwidth_kbps
	]

func update_network_metrics(rtt: float, seq: int, tick: int, loss: float = 0.0, bw: float = 0.0) -> void:
	"""Update network metrics from the network manager"""
	rtt_ms = rtt
	snapshot_sequence = seq
	server_tick = tick
	packet_loss = loss
	bandwidth_kbps = bw

func _input(event: InputEvent) -> void:
	# Handle additional debug inputs
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				visible = !visible
			KEY_F2:
				if player_reference:
					player_reference.toggle_prediction()
