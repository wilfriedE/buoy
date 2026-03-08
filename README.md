<p align="center">
  <img src="assets/logo.svg" alt="Buoy" width="120" />
</p>

# Buoy

**Your ROS 2 hub that keeps the network afloat.**

Built for [MASER](https://www.maserdc.org/) and educational purposes. Headless ROS 2 Jazzy hub for Raspberry Pi 5: WiFi access point (hostapd), local `.buoy` DNS, and a web command center. No desktop or display on the Pi—all UIs are web-based from devices on the WiFi.

---

## Image your Raspberry Pi

The easiest way to get started is to use a pre-built image from the [GitHub Releases](https://github.com/wilfriedE/buoy/releases) page.

### What you need

- **Raspberry Pi 5** (Pi 4 and Pi 3 are also supported)
- **SD card** (16 GB minimum; 32 GB+ recommended for the LLM variant)
- **Raspberry Pi Imager** – [download from raspberrypi.com](https://www.raspberrypi.com/software/)

### Choose an image

| Image | Description |
|-------|-------------|
| **Buoy** (basic) | ROS 2 + rosbridge, WiFi AP, command center. |
| **Buoy LLM** | Same as basic, plus Ollama, Whisper, and an LLM ROS node. Requires 8 GB+ RAM. |

### Quick start (3 steps)

1. **Download the manifest** from the [Releases](https://github.com/wilfriedE/buoy/releases) page:
   - For basic: `buoy.rpi-imager-manifest`
   - For LLM: `buoy_llm.rpi-imager-manifest`

2. **Open Raspberry Pi Imager** → click the gear icon (⚙️) → **Content Repository** → **EDIT** → **Use custom file** → select the manifest you downloaded → **APPLY & RESTART**.

3. **Select "Buoy"** from the OS list, choose your SD card, and click **Write**.
   - **Important:** Do not configure WiFi in the Pi Imager settings. Buoy uses the Pi's WiFi as an access point; Pi Imager's WiFi option would conflict. Use Ethernet for initial setup if needed.

4. **Insert the SD card**, power on the Pi, and wait **10–20 minutes** for first boot (the system loads Docker images from the card; it may feel slow until that finishes).

5. **Connect to the Buoy WiFi** (default SSID: `Buoy`, password: `ChangeMe`) and open **http://buoy.buoy** in your browser for the command center.

### Optional: customize before flashing

With the manifest loaded, the settings gear lets you set hostname, SSH user, and password. **Do not configure WiFi**—Buoy uses wlan0 as an access point.

---

## Install on Linux (Debian, Ubuntu, Fedora)

Install Buoy on an existing Linux machine without flashing an image. Supported: Debian, Ubuntu, Fedora, RHEL, Rocky, Alma.

Download the install script from a [release](https://github.com/wilfriedE/buoy/releases) (replace `v1.0.0` with your desired version):

```bash
curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash
```

**Options:**
- `--no-wifi` – Headless only (no hostapd). Default. Access the command center at `http://localhost` or `http://<host-ip>`.
- `--wifi` – Enable WiFi AP if you have a WiFi interface (e.g. `wlan0`). Connect to the Buoy network and open `http://buoy.buoy`.

**With WiFi AP:**
```bash
curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash -s -- --wifi
```

**From a local clone:**
```bash
cd buoy
sudo ./install.sh --no-wifi   # or --wifi
```

See [docs/install-linux.md](docs/install-linux.md) for details.

---

## Features

- **WiFi AP** – Native hostapd + dnsmasq so devices connect to one SSID and get DHCP/DNS from the Pi
- **Local DNS** – `buoy.buoy`, `hub.buoy`, and `hostname.buoy` for connected devices. After joining WiFi, open **http://buoy.buoy** for the command center.
- **ROS 2 Jazzy** – Runs in Docker with **host networking** so the hub and WiFi clients share the same DDS multicast domain
- **Command center** – Web dashboard (ROS topic graph, connected devices, Sandbox). Optional **captive portal** (Nodogsplash): when enabled, new WiFi clients are redirected here on first browse.
- **Single image** – Flash one image to each Pi; first boot runs Ansible to configure the hub

---

## After flashing

- **Command center:** Connect to the Buoy WiFi and open **http://buoy.buoy**
- **SSH:** `ssh <user>@buoy.buoy` — user and password are set when building the image or via Pi Imager's settings gear. Pre-built images default to `maser` / `ChangeMe`.
- **Rosbridge:** `ws://buoy.buoy:9090` for WebSocket clients (Python, JavaScript, Foxglove Studio)

For more on connecting devices and using ROS, see the [User guide: connecting and interacting with ROS devices](docs/ros-hub.md). For the LLM variant, see [LLM variant (Ollama, Whisper, ROS node)](docs/llm-buoy.md).

---

## Developer guide

If you want to build the image yourself, contribute, or understand the project:

### Build the image

**Prerequisites:** [UV](https://docs.astral.sh/uv/) and [Docker Desktop](https://www.docker.com/products/docker-desktop/).

```bash
# Clone the repo
git clone https://github.com/wilfriedE/buoy.git
cd buoy

# Build (basic image)
uv run build

# Build both basic and LLM images
uv run build --both
```

Output: `build/buoy_build.img` and `build/buoy.rpi-imager-manifest`. See [image/README.md](image/README.md) for details and [image/BUILD-QEMU.md](image/BUILD-QEMU.md) for manual steps (Linux, macOS, WSL2).

### Run the playbook manually

On a Raspberry Pi 5 with Raspberry Pi OS 64-bit (Trixie, Lite):

```bash
git clone https://github.com/wilfriedE/buoy.git
cd buoy/ansible
ansible-playbook -i localhost, -c local playbook.yml
```

### Quick links

- **[Command center – local dev](command_center/README.md)** – Run the dashboard locally with live reload for UI work
- **[Changelog](CHANGELOG.md)** – Notable changes and migration notes
- **[Image build: flash and first boot](image/README.md)** – Build details, first boot, offline deployment
- **[Build image with QEMU](image/BUILD-QEMU.md)** – Manual build on Linux, macOS, or WSL2

### Variables

Edit `ansible/group_vars/all.yml` to set hostname, WiFi SSID/passphrase, ROS domain ID, and ports. Key variables: `buoy_hostname`, `wifi_ssid`, `wifi_passphrase`, `ros_domain_id`, `ros_bridge_port`, `command_center_port`.

**Before deploying:** Change `buoy_ssh_password` and `wifi_passphrase` in `ansible/group_vars/all.yml`. The defaults are placeholders only.

**Offline first boot:** Default is `offline_first_boot: true` so the playbook does not require internet when it runs on first boot. Build the image once with network and `offline_first_boot: false` so Docker, hostapd, images, and pnpm deps are installed; then image the SD and set `offline_first_boot: true` again. See [image/README.md](image/README.md).

---

## License

MIT License. See [LICENSE](LICENSE) for details.
