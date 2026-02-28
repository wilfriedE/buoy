# Buoy – User guide: connecting and interacting with ROS devices

This guide is for **users** who connect to a Buoy hub (WiFi and web dashboard) and want to run or interact with ROS 2 nodes and devices on the network.

---

## 1. Connect to the hub

1. **WiFi** – Join the hub's WiFi network (SSID and passphrase are set by the hub operator; often shown on the command center or device label).
2. **IP and DNS** – Your device will get an IP via DHCP. The hub is the DNS server. You can reach it by:
   - **Hostname:** `buoy.buoy` or `hub.buoy`
   - **IP:** usually `10.3.141.1` (confirm on the command center page)
3. **Command center** – Open a browser and go to `http://buoy.buoy:8080` (or the IP and port shown after connecting). You'll see the dashboard with connected devices and a link to the ROS topic graph.
4. **SSH** – To access the Raspberry Pi over SSH: `ssh maser@buoy.buoy` (or `ssh maser@10.3.141.1`). Default password: `ChangeMe`. Ask the hub operator for credentials if they were changed during setup.

---

## 2. Run ROS 2 nodes on your device

To have your device participate in the same ROS 2 network as the hub and other devices:

1. Use the **same ROS domain** as the hub. The default is `0`. Set before running your nodes:
   - **Linux/macOS:** `export ROS_DOMAIN_ID=0`
   - **Windows:** `set ROS_DOMAIN_ID=0`
2. Install ROS 2 Jazzy (or the same distro as the hub) on your machine, or use a container that matches.
3. Run your nodes (publishers, subscribers, etc.). They will discover the hub and other nodes automatically over the network; no registration step is required.

Example (Python, rclpy): see the code sections below. Run with the same domain, e.g. `ROS_DOMAIN_ID=0 python my_node.py`.

---

## 3. Interact from a browser or script (rosbridge)

The hub exposes **rosbridge** so you can publish/subscribe and call services from non-ROS programs (e.g. JavaScript in a browser or Node.js).

- **Rosbridge URL:** `ws://buoy.buoy:9090` (or `ws://10.3.141.1:9090` if the hostname does not resolve).
- Use a **roslib**-compatible client (e.g. `roslibjs` in the browser or `roslib` in Node).

You can:
- Subscribe to topics and react to messages (e.g. display in the UI).
- Publish messages to topics to drive robots or devices.
- Call services if the hub or other nodes expose them.

---

## 4. Code examples (Python, JavaScript, TypeScript)

**Assumptions:** You are on the hub's WiFi; ROS domain is `0`; rosbridge is at `ws://buoy.buoy:9090`.

### Python (rclpy) – subscribe to a topic

```python
import rclpy
from rclpy.node import Node
from std_msgs.msg import String

class Listener(Node):
    def __init__(self):
        super().__init__('listener')
        self.sub = self.create_subscription(String, 'chatter', self.callback, 10)
    def callback(self, msg):
        self.get_logger().info('Heard: "%s"' % msg.data)

def main():
    rclpy.init()
    rclpy.spin(Listener())
    rclpy.shutdown()

if __name__ == '__main__':
    main()
```

Run with the same domain as the hub: `ROS_DOMAIN_ID=0 python listener.py`.

### Python (rclpy) – publish

```python
import rclpy
from rclpy.node import Node
from std_msgs.msg import String

class Talker(Node):
    def __init__(self):
        super().__init__('talker')
        self.pub = self.create_publisher(String, 'chatter', 10)
        self.timer = self.create_timer(1.0, self.tick)
    def tick(self):
        self.pub.publish(String(data='Hello from Python'))

def main():
    rclpy.init()
    rclpy.spin(Talker())
    rclpy.shutdown()

if __name__ == '__main__':
    main()
```

Run with the same domain: `ROS_DOMAIN_ID=0 python talker.py`.

### JavaScript (Node, roslib) – subscribe via rosbridge

```javascript
const ROSLIB = require('roslib');
const ros = new ROSLIB.Ros({ url: 'ws://buoy.buoy:9090' });
ros.on('connection', () => {
  const listener = new ROSLIB.Topic({
    ros, name: '/chatter', messageType: 'std_msgs/msg/String'
  });
  listener.subscribe((msg) => console.log('Heard:', msg.data));
});
```

Install: `npm install roslib`.

### TypeScript (browser or Node, roslib) – publish via rosbridge

```typescript
import * as ROSLIB from 'roslib';
const ros = new ROSLIB.Ros({ url: 'ws://buoy.buoy:9090' });
ros.on('connection', () => {
  const pub = new ROSLIB.Topic({
    ros, name: '/chatter', messageType: 'std_msgs/msg/String'
  });
  pub.publish(new ROSLIB.Message({ data: 'Hello from TypeScript' }));
});
```

In the browser, use a bundler or load roslib from a CDN.

---

## 5. Listen and publish from the browser

From the command center, open **Listen & Publish** to subscribe to topics and publish messages. All devices on the buoy's WiFi share the same ROS network—messages you publish appear on other devices' listeners. Uses the `/chatter` topic by default (std_msgs/msg/String).

## 6. Viewing the ROS topic graph

From the command center page, open **Topic graph** to see an embedded viewer (open source: roslibjs + vis-network) that shows nodes, topics, and connections over rosbridge. No external tools required.

Alternatively, you can use **Foxglove Studio** at [studio.foxglove.dev](https://studio.foxglove.dev), connect to **Rosbridge** with URL `ws://buoy.buoy:9090`, and use the Topic Graph panel.

---

## 7. Local hostnames (.buoy)

Devices that get an IP from the hub's DHCP may be resolvable as `hostname.buoy` if the hub is configured that way. Ask your hub operator which names are available. The hub itself is `buoy.buoy` or `hub.buoy`.
