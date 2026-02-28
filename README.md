# Maser Buoy

Headless ROS 2 Jazzy hub for Raspberry Pi 5: WiFi access point (hostapd), local `.buoy` DNS, and a web command center. No desktop or display on the Pi—all UIs are web-based from devices on the WiFi. Devices connect to the hub’s WiFi and run ROS 2 nodes that discover each other via DDS with minimal configuration.

## Features

- **WiFi AP** – Native hostapd + dnsmasq so devices connect to one SSID and get DHCP/DNS from the Pi
- **Local DNS** – `maser.buoy`, `hub.buoy`, and `hostname.buoy` for connected devices. After joining WiFi, open **http://maser.buoy:8080** for the command center.
- **ROS 2 Jazzy** – Runs in Docker with **host networking** so the hub and WiFi clients share the same DDS multicast domain
- **Command center** – Web dashboard (ROS topic graph link, connected devices list). Optional **captive portal** (Nodogsplash): when enabled, new WiFi clients are redirected here on first browse; set `captive_portal_enable: false` in `ansible/group_vars/all.yml` to skip.
- **Single image** – Flash one image to each Pi; first boot runs Ansible to configure the hub

## Quick links

- **[User guide: connecting and interacting with ROS devices](docs/ros-hub.md)** – For users of the hub: connect to WiFi, run ROS 2 nodes, use rosbridge (Python, JavaScript, TypeScript examples)
- **[Image build: flash and first boot](image/README.md)** – Build the image (with network once); first boot on the Pi runs offline. Use the **headless** (Lite/server) base OS.
- **[Build image with QEMU](image/BUILD-QEMU.md)** – Build the image on a PC (Linux, macOS, or Windows via WSL2) using QEMU emulation—no Raspberry Pi required. **Easiest with Docker:** run `./image/build-with-docker.sh` (see [image/README.md](image/README.md)).

## Running the playbook manually

On a Raspberry Pi 5 with Raspberry Pi OS 64-bit (Trixie, Lite/server, headless):

```bash
git clone https://github.com/your-org/maser_buoy.git
cd maser_buoy/ansible
ansible-playbook -i localhost, -c local playbook.yml
```

Or use **ansible-pull** (e.g. from a first-boot script):

```bash
ansible-pull -U https://github.com/your-org/maser_buoy.git -C main -i localhost, -d /tmp/maser_buoy ansible/playbook.yml
```

## Variables

Edit `ansible/group_vars/all.yml` to set hostname, WiFi SSID/passphrase, ROS domain ID, and ports. Key variables: `maser_buoy_hostname`, `wifi_ssid`, `wifi_passphrase`, `ros_domain_id`, `ros_bridge_port`, `command_center_port`.

**Offline first boot:** Default is `offline_first_boot: true` so the playbook does not require internet when it runs on first boot (e.g. in the field). Build the image once with network and `offline_first_boot: false` so Docker, hostapd, images, and pnpm deps are installed; then image the SD and set `offline_first_boot: true` again. See [image/README.md](image/README.md).

## License

Use and modify as needed for your project.
