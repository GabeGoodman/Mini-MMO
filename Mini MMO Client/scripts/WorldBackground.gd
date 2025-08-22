class_name WorldBackground
extends TileMap

## Simple world background for Mini MMO client
## Creates a basic grid pattern for visual reference

func _ready() -> void:
	# Create a simple procedural background
	create_background_pattern()

func create_background_pattern() -> void:
	# Create a simple checkerboard pattern for visual reference
	var tile_size = 64
	var world_size = 32  # 32x32 tiles = 2048x2048 world
	
	# This is a placeholder - in a real implementation, you'd use proper TileMap resources
	# For now, we'll just draw a simple grid pattern using a ColorRect
	var background = ColorRect.new()
	background.color = Color(0.1, 0.3, 0.1, 1.0)  # Dark green
	background.size = Vector2(world_size * tile_size, world_size * tile_size)
	background.position = Vector2(-world_size * tile_size / 2, -world_size * tile_size / 2)
	
	# Add to parent
	get_parent().add_child(background)
	get_parent().move_child(background, 0)  # Move to back
	
	# Add some visual grid lines
	create_grid_lines(background, tile_size, world_size)
