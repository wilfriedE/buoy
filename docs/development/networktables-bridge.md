# NetworkTables Bridge – Developer Guide

Architecture, config format, and how to extend the FRC NetworkTables bridge.

---

## Architecture

The bridge runs as a Docker container (`nt_bridge`) with:

- **pyntcore** – NT4 client (connects to robot as server)
- **rclpy** – ROS 2 Python client
- **HTTP status server** – Port 9091, `GET /status` returns `{ "robots": [{ "id", "label", "connected" }] }`

Each robot gets its own `NetworkTableInstance` (created via `ntcore.NetworkTableInstance.create()`). The bridge maintains multiple NT client connections and ROS subscriptions/publishers with robot-specific topic prefixes.

---

## Config Files

| Config | Path | Purpose |
|-------|------|---------|
| nt_bridge | `$BUOY_ROOT/config/nt_bridge.json` | Robot registry, topic mappings |
| features | `$BUOY_ROOT/config/features.json` | `{ "frc": true \| false }` |

### nt_bridge.json

```json
{
  "robots": [
    {
      "id": "team1234",
      "label": "Practice Bot",
      "host": "10.12.34.2",
      "port": 5800,
      "ros_prefix": "/frc/team1234",
      "ros_to_nt": [],
      "nt_to_ros": []
    }
  ]
}
```

- **id** – Unique slug; used in ROS topic names
- **label** – Display name in UI
- **host** / **port** – Robot NT server address
- **ros_prefix** – Optional; defaults to `/frc/<id>` for NT→ROS topics
- **ros_to_nt** / **nt_to_ros** – Per-robot mappings; omit for default Twist mapping

---

## Default Mapping

- **ROS** `/cmd_vel/frc_<id>` (Twist) → **NT** `/SmartDashboard/linearX`, `linearY`, `angularZ`
- Custom mappings can be added via `ros_to_nt` and `nt_to_ros` in config.

---

## Status Server

The bridge runs an HTTP server on port 9091. `GET /status` returns:

```json
{
  "robots": [
    { "id": "team1234", "label": "Practice Bot", "connected": true }
  ]
}
```

The command center proxies this at `/api/nt-bridge/status`.

---

## Adding New Message Mappings

1. Edit `docker/nt_bridge/bridge.py`.
2. In `RobotBridge`, add a new ROS subscription or publisher for the message type.
3. In `_on_*` or `spin_once`, map between ROS and NT (e.g. split a message into NT doubles or build a message from NT entries).
4. Optionally add config schema for `ros_to_nt` / `nt_to_ros` to support per-robot overrides.

---

## Testing Without a Robot

- Run `docker compose --profile frc up nt_bridge`; the bridge starts and exposes HTTP on 9091.
- `curl http://localhost:9091/status` returns `{ "robots": [] }` if no robots are configured.
- To test with a robot: use a real RoboRIO in test mode, or run a minimal NT server (e.g. pynetworktables as server) if available.
