# Install Buoy on Linux

Install Buoy on an existing Debian, Ubuntu, Fedora, or RHEL-based system. No image flashing required.

## Supported distributions

- **Debian** (Bookworm, Trixie)
- **Ubuntu** (22.04, 24.04, etc.)
- **Fedora** (40+)
- **RHEL, Rocky Linux, AlmaLinux**

## Prerequisites

- Root or sudo access
- Internet connection (for package installation)
- Docker will be installed by the playbook

## Quick install

Download the install script from a [release](https://github.com/wilfriedE/buoy/releases) (replace `v1.0.0` with your desired version):

```bash
curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash
```

This installs in headless mode (no WiFi AP). Access the web portal at `http://localhost` or `http://<your-machine-ip>`.

## Options

| Option | Description |
|--------|--------------|
| `--no-wifi` | Headless only. No hostapd. Default for the install script. |
| `--wifi` | Enable WiFi AP if you have a WiFi interface (e.g. `wlan0`). |

**With WiFi AP:**
```bash
curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash -s -- --wifi
```

Connect to the Buoy WiFi (default SSID: `Buoy`, password: `ChangeMe`) and open `http://buoy.buoy` or `http://10.3.141.1`.

## From a local clone

If you have already cloned the repo:

```bash
cd buoy
sudo ./install.sh --no-wifi   # headless
sudo ./install.sh --wifi      # with WiFi AP
```

## What gets installed

- **Docker** (Docker CE from Docker's official repo)
- **Ansible** (to run the playbook)
- **ROS 2** containers (rosbridge) via Docker Compose
- **Web portal** (Node.js web app on port 80)
- **WiFi AP** (hostapd + dnsmasq) – only when `--wifi` is used

## Accessing the web portal

| Mode | URL |
|------|-----|
| Headless (`--no-wifi`) | `http://localhost` or `http://<host-ip>` |
| With WiFi AP (`--wifi`) | `http://buoy.buoy` or `http://10.3.141.1` (from devices on the Buoy WiFi) |

## Rosbridge

WebSocket clients can connect to `ws://<host-ip>:9090` (or `ws://buoy.buoy:9090` or `ws://10.3.141.1:9090` when using WiFi AP).

## Customization

After install, edit `ansible/group_vars/all.yml` in `/opt/buoy` and re-run the playbook:

```bash
cd /opt/buoy/ansible
sudo ansible-playbook -i localhost, -c local playbook.yml -e "offline_first_boot=false" -e "wifi_ap_enable=true"
```

Key variables: `buoy_hostname`, `wifi_ssid`, `wifi_passphrase`, `ros_domain_id`, `command_center_port`.

## Troubleshooting

- **Docker fails on Fedora** – Ensure SELinux allows Docker. If needed: `sudo setenforce 0` (temporary) or configure SELinux for Docker.
- **No WiFi interface** – Use `--no-wifi`. The WiFi AP requires a wireless interface (e.g. `wlan0`).
- **Port 80 in use** – Change `command_center_port` in `ansible/group_vars/all.yml` before running the playbook.
