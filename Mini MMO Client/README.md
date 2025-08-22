# Mini MMO Client

A top-down 2D MMO RPG client built with Godot 4.4.

## Features

### Phase 0.1 - Minimal World & Movement ✅
- **Player Movement**: WASD/Arrow key controls with smooth movement
- **Client Prediction**: Toggle-able client-side prediction system
- **Debug Overlay**: Real-time display of FPS, position, and network metrics
- **Camera System**: Smooth camera following with zoom controls
- **Input System**: Professional input handling with configurable key bindings

## Controls

- **WASD / Arrow Keys**: Move player character
- **F1**: Toggle debug overlay visibility
- **F2**: Toggle client prediction on/off
- **F3**: Toggle fullscreen mode
- **ESC**: Pause/Resume game

## Project Structure

```
Mini MMO Client/
├── project.godot              # Godot project configuration
├── scenes/
│   ├── Main.tscn             # Main game scene
│   └── UI/                   # UI scenes (future)
├── scripts/
│   ├── Main.gd               # Main game controller
│   ├── Player.gd             # Player movement and prediction
│   ├── DebugOverlay.gd       # Debug information display
│   └── WorldBackground.gd    # World background system
└── assets/
    ├── sprites/
    │   └── player_placeholder.svg  # 64x64 player sprite
    └── tilesets/             # Future tileset assets
```

## Technical Details

### Client Prediction System
The player movement includes a client-side prediction system that:
- Stores input sequences for server reconciliation
- Applies movement locally for immediate feedback
- Supports toggling between predicted and direct movement
- Prepared for future server synchronization

### Debug Overlay
Displays real-time information:
- FPS counter
- Player position and velocity
- Network metrics (RTT, sequence numbers, server tick)
- Prediction system status
- Packet loss and bandwidth (future)

### Performance Targets
- 60 FPS client rendering
- 50-120ms network RTT budget
- 20 kbps bandwidth per player (future networking)
- Client-side prediction for responsive movement

## Development Status

✅ **Phase 0.1 Complete**: Minimal World & Movement
- Basic Godot scene structure
- WASD movement controls
- Client prediction framework
- Debug overlay with metrics
- Professional code structure

🔄 **Next Phase**: Login UI & Protocol
- User authentication interface
- Binary protocol implementation
- Server communication framework

## Getting Started

1. Open the project in Godot 4.4
2. Run the project (F5)
3. Use WASD to move around
4. Press F1 to see debug information
5. Press F2 to toggle prediction modes

## Architecture Notes

This client is designed to work with a C++ Boost.Asio server using:
- Binary protocol for efficient networking
- Snapshot + delta compression
- Authoritative server with client prediction
- ECS-based server architecture
- QUIC transport protocol (future)
