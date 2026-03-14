# NetworkTables (FRC) – Buoy Bridge

This guide covers the **FRC NetworkTables bridge** for Buoy, which connects ROS 2 topics to FRC robots via NetworkTables (NT4). Use it to send Twist commands to RoboRIO and receive telemetry.

---

## Enable FRC

1. Open **Features** in the Buoy web portal.
2. Turn **FRC (NetworkTables)** **On**.
3. The bridge starts immediately. After a reboot, it will start automatically if FRC is enabled.

---

## Add Robots

1. Open **NetworkTables (FRC)** in the ROS menu.
2. Click **Add robot**.
3. Fill in:
   - **Label** – Display name (e.g. "Practice Bot")
   - **ID** – Team number or slug (e.g. `team1234`)
   - **Host** – Robot IP (e.g. `10.12.34.2` for team 1234)
   - **Port** – Default 5800 (NT4)
4. Click **Save**.

The bridge connects to each robot’s NetworkTables server. Robot and Buoy must be on the same network.

---

## Default Topic Mapping

Each robot gets a default mapping:

| Direction | ROS topic | NetworkTables |
|----------|-----------|---------------|
| ROS → NT | `/cmd_vel/frc_<id>` (Twist) | `/SmartDashboard/linearX`, `linearY`, `angularZ` |

Publish a `geometry_msgs/msg/Twist` to `/cmd_vel/frc_team1234` and the bridge writes `linearX`, `linearY`, `angularZ` to the robot’s SmartDashboard.

---

## FRC Robot Code Example

Read the NT values from your robot code:

```java
// Java (WPILib)
NetworkTable table = NetworkTables.getTable("SmartDashboard");
double linearX = table.getNumber("linearX", 0);
double linearY = table.getNumber("linearY", 0);
double angularZ = table.getNumber("angularZ", 0);
// Use in your drive
```

```python
# Python (RobotPy / pyntcore)
import ntcore
inst = ntcore.NetworkTableInstance.getDefault()
inst.startClient4("robot")
inst.setServerTeam(TEAM)  # or inst.setServer("10.12.34.2", 5800)
table = inst.getTable("SmartDashboard")
linear_x = table.getNumber("linearX", 0)
linear_y = table.getNumber("linearY", 0)
angular_z = table.getNumber("angularZ", 0)
```

---

## Network Requirements

- Robot (RoboRIO) and Buoy must be on the same network (field network or Buoy WiFi).
- Robot IP is typically `10.TE.AM.2` (team number in TEAM).
- NT4 uses port 5800 by default.

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| Bridge not running | Enable FRC in Features. |
| Status "Disconnected" | Robot and Buoy on same network? Correct IP? Robot powered and running? |
| Wrong IP | Use `10.TE.AM.2` for team TEAM. |
| No Twist received on robot | Ensure robot code reads from SmartDashboard. |
