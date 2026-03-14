#!/usr/bin/env python3
"""
NetworkTables (FRC) bridge – connects to robot NT servers and bridges ROS↔NT.
Reads config from $BUOY_ROOT/config/nt_bridge.json.
Exposes HTTP status on port 9091.
"""
import json
import os
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from std_msgs.msg import Float64

try:
    import ntcore
except ImportError:
    ntcore = None

BUOY_ROOT = os.environ.get("BUOY_ROOT", "/opt/buoy")
CONFIG_PATH = Path(BUOY_ROOT) / "config" / "nt_bridge.json"
STATUS_PORT = int(os.environ.get("NT_BRIDGE_STATUS_PORT", "9091"))
NT_DEFAULT_PORT = 5800


def load_config():
    """Load nt_bridge.json; return { robots: [] } on error or missing."""
    try:
        if CONFIG_PATH.exists():
            with open(CONFIG_PATH, "r") as f:
                data = json.load(f)
                return data if isinstance(data, dict) else {"robots": []}
    except (json.JSONDecodeError, OSError) as e:
        print(f"Config load error: {e}")
    return {"robots": []}


class StatusHandler(BaseHTTPRequestHandler):
    """Serves GET /status with robots connection status."""

    def do_GET(self):
        if self.path == "/status" or self.path == "/status/":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            body = json.dumps({"robots": getattr(self.server, "robots_status", [])})
            self.wfile.write(body.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


class RobotBridge:
    """Manages one robot: NT client + ROS subscriptions/publishers."""

    def __init__(self, node, robot_config):
        self.node = node
        self.id = robot_config.get("id", "unknown")
        self.label = robot_config.get("label", self.id)
        self.host = robot_config.get("host", "")
        self.port = int(robot_config.get("port", NT_DEFAULT_PORT))
        self.ros_prefix = robot_config.get("ros_prefix") or f"/frc/{self.id}"
        self.connected = False
        self._nt_instance = None
        self._nt_table = None
        self._ros_sub = None
        self._ros_pubs = {}  # nt_key -> publisher
        self._ros_to_nt = robot_config.get("ros_to_nt", [])
        self._nt_to_ros = robot_config.get("nt_to_ros", [])
        self._setup_default_twist_mapping()

    def _setup_default_twist_mapping(self):
        """Add default Twist mapping if not overridden."""
        has_twist = any(
            m.get("ros", "").endswith("/cmd_vel/frc_" + self.id)
            for m in self._ros_to_nt
        )
        if not has_twist:
            self._ros_to_nt.append({
                "ros": f"/cmd_vel/frc_{self.id}",
                "nt": "/SmartDashboard",
                "field": "twist",
            })


    def connect(self):
        """Connect NT client to robot."""
        if not ntcore:
            return False
        if not self.host:
            return False
        try:
            inst = ntcore.NetworkTableInstance.create()
            inst.startClient4("buoy-nt-bridge")
            inst.setServer(self.host, self.port)
            self._nt_instance = inst
            self._nt_table = inst.getTable("SmartDashboard")
            return True
        except Exception as e:
            self.node.get_logger().error(f"NT connect {self.id} failed: {e}")
            return False

    def disconnect(self):
        """Disconnect NT client."""
        self.connected = False
        if self._ros_sub:
            self._ros_sub.destroy()
            self._ros_sub = None
        for pub in self._ros_pubs.values():
            pub.destroy()
        self._ros_pubs.clear()
        if self._nt_instance:
            try:
                ntcore.NetworkTableInstance.destroy(self._nt_instance)
            except Exception:
                pass
            self._nt_instance = None
        self._nt_table = None

    def setup_ros(self):
        """Create ROS subscription for Twist and publishers for NT→ROS."""
        topic = f"/cmd_vel/frc_{self.id}"
        self._ros_sub = self.node.create_subscription(
            Twist, topic, self._on_twist, 10
        )
        for m in self._nt_to_ros:
            ros_topic = m.get("ros") or f"{self.ros_prefix}/{m.get('nt', '').split('/')[-1]}"
            pub = self.node.create_publisher(Float64, ros_topic, 10)
            self._ros_pubs[m.get("nt", "")] = pub

    def _on_twist(self, msg):
        """Publish Twist to NT SmartDashboard doubles."""
        if not self._nt_table:
            return
        try:
            self._nt_table.putNumber("linearX", float(msg.linear.x))
            self._nt_table.putNumber("linearY", float(msg.linear.y))
            self._nt_table.putNumber("angularZ", float(msg.angular.z))
        except Exception:
            pass

    def _nt_path_to_table_key(self, nt_path):
        """Convert /SmartDashboard/VisionX to (SmartDashboard, VisionX)."""
        parts = nt_path.strip("/").split("/")
        if len(parts) >= 2:
            return parts[0], "/".join(parts[1:])
        if len(parts) == 1 and parts[0]:
            return "SmartDashboard", parts[0]
        return "SmartDashboard", ""

    def spin_once(self):
        """Read NT→ROS and update connection status."""
        if not self._nt_instance:
            return
        self.connected = self._nt_instance.isConnected()
        if not self.connected:
            return
        for m in self._nt_to_ros:
            nt_path = m.get("nt", "")
            pub = self._ros_pubs.get(nt_path)
            if not pub:
                continue
            try:
                table_name, key = self._nt_path_to_table_key(nt_path)
                if not key:
                    continue
                tbl = self._nt_instance.getTable(table_name)
                val = tbl.getNumber(key, 0.0)
                pub.publish(Float64(data=float(val)))
            except Exception:
                pass


class NTBridgeNode(Node):
    """Main bridge node: manages robots, status server."""

    def __init__(self):
        super().__init__("nt_bridge")
        self.robots: list[RobotBridge] = []
        self._config_mtime = 0
        self._status_thread = None

    def get_robots_status(self):
        return [
            {"id": r.id, "label": r.label, "connected": r.connected}
            for r in self.robots
        ]

    def reload_config(self):
        """Load config and reconcile robot list."""
        mtime = CONFIG_PATH.stat().st_mtime if CONFIG_PATH.exists() else 0
        if mtime == self._config_mtime:
            return
        self._config_mtime = mtime
        cfg = load_config()
        robots_cfg = cfg.get("robots", [])
        if not robots_cfg:
            for r in self.robots:
                r.disconnect()
            self.robots.clear()
            self.get_logger().info("No robots in config")
            return
        ids = {r.get("id"): r for r in robots_cfg}
        for r in self.robots[:]:
            if r.id not in ids:
                r.disconnect()
                self.robots.remove(r)
        for rc in robots_cfg:
            rid = rc.get("id")
            existing = next((r for r in self.robots if r.id == rid), None)
            if existing:
                existing.host = rc.get("host", "")
                existing.port = int(rc.get("port", NT_DEFAULT_PORT))
                existing.label = rc.get("label", rid)
                existing.ros_prefix = rc.get("ros_prefix") or f"/frc/{rid}"
            else:
                rb = RobotBridge(self, rc)
                rb.setup_ros()
                self.robots.append(rb)
        for r in self.robots:
            if not r._nt_instance:
                r.connect()

    def run(self):
        """Start status server and main loop."""
        def status_getter():
            return self.get_robots_status()

        server = HTTPServer(("0.0.0.0", STATUS_PORT), StatusHandler)
        server.robots_status = []

        def update_loop():
            while True:
                server.robots_status = self.get_robots_status()
                time.sleep(0.5)

        t = threading.Thread(target=update_loop, daemon=True)
        t.start()
        st = threading.Thread(
            target=lambda: server.serve_forever(), daemon=True
        )
        st.start()
        self.get_logger().info(f"Status server on port {STATUS_PORT}")

        while rclpy.ok():
            self.reload_config()
            for r in self.robots:
                if not r._nt_instance and r.host:
                    r.connect()
                r.spin_once()
            rclpy.spin_once(self, timeout_sec=0.1)


def main():
    if not ntcore:
        print("pyntcore not installed; cannot run NT bridge")
        return 1
    rclpy.init()
    node = NTBridgeNode()
    try:
        node.run()
    except KeyboardInterrupt:
        pass
    finally:
        for r in node.robots:
            r.disconnect()
        node.destroy_node()
        rclpy.shutdown()
    return 0


if __name__ == "__main__":
    exit(main())
