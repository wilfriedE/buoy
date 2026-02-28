<p align="center">
  <img src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDUxMiA1MTIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjwhLS0gU29mdCBCYWNrZ3JvdW5kIGZvciBBdmF0YXIvRmF2aWNvbiB1c2UgLS0+CjxjaXJjbGUgY3g9IjI1NiIgY3k9IjI1NiIgcj0iMjQwIiBmaWxsPSIjRjBGOUZGIi8+Cgo8IS0tIFdhdGVyIFN1cmZhY2UgUmlwcGxlIC0tPgoKPHBhdGggZD0iTTE2MCAzODBDMTYwIDM4MCAyMDAgMzY1IDI1NiAzNjVDMzEyIDM2NSAzNTIgMzgwIDM1MiAzODAiIHN0cm9rZT0iIzAwNzdCNiIgc3Ryb2tlLXdpZHRoPSIxNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+Cgo8IS0tIEJ1b3kgQmFzZSAoVGhlICJCbG9iIiBzaGFwZSBmb3IgY3V0ZW5lc3MpIC0tPgoKPHBhdGggZD0iTTE5MCAzMjBDMTkwIDI4MCAyMTAgMjYwIDI1NiAyNjBDMzAyIDI2MCAzMjIgMjgwIDMyMiAzMjBWMzgwQzMyMiA0MTAgMjkyLjM4NiA0MzAgMjU2IDQzMEMyMTkuNjE0IDQzMCAxOTAgNDEwIDE5MCAzODBWMzIwWiIgZmlsbD0iIzAwNzdCNiIvPgoKPCEtLSBGcmllbmRseSBXaGl0ZSBTdHJpcGUgLS0+Cgo8cGF0aCBkPSJNMTkwIDMxNUgzMjJWMzU1SDE5MFYzMTVaIiBmaWxsPSJ3aGl0ZSIvPgoKPCEtLSBUYXBlcmVkIE1hc3QgLS0+Cgo8cGF0aCBkPSJNMjM2IDI2MEwyNDggMTgwSDI2NEwyNzYgMjYwSDIzNloiIGZpbGw9IiMwMDc3QjYiLz4KCjwhLS0gVGhlIExpZ2h0IC8gQ2VudHJhbCBOb2RlIC0tPgoKPGNpcmNsZSBjeD0iMjU2IiBjeT0iMTY1IiByPSIyMiIgZmlsbD0iI0ZGNkI2QiIvPgoKPCEtLSBXaUZpIFNpZ25hbCBBcmNzIChSb3VuZGVkIGFuZCBCb2xkKSAtLT4KCjwhLS0gSW5uZXIgQXJjIC0tPgoKPHBhdGggZD0iTTIyMCAxMzVDMjMwIDEyMCAyODIgMTIwIDI5MiAxMzUiIHN0cm9rZT0iI0ZGNkI2QiIgc3Ryb2tlLXdpZHRoPSIxMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBmaWxsPSJub25lIi8+CjwhLS0gT3V0ZXIgQXJjIC0tPgo8cGF0aCBkPSJNMTk1IDEwNUMyMTUgODAgMjk3IDgwIDMxNyAxMDUiIHN0cm9rZT0iI0ZGNkI2QiIgc3Ryb2tlLXdpZHRoPSIxMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBmaWxsPSJub25lIiBvcGFjaXR5PSIwLjUiLz4KCjwhLS0gU29mdCBIaWdobGlnaHQgZm9yIERlcHRoIC0tPgoKPHBhdGggZD0iTTIxMCAzMjVWMzQ1IiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgb3BhY2l0eT0iMC40Ii8+Cjwvc3ZnPg==" alt="Buoy" width="120" />
</p>

# Buoy

**Your ROS 2 hub that keeps the network afloat.**

Headless ROS 2 Jazzy hub for Raspberry Pi 5: WiFi access point (hostapd), local `.buoy` DNS, and a web command center. No desktop or display on the Pi—all UIs are web-based from devices on the WiFi. Devices connect to the hub’s WiFi and run ROS 2 nodes that discover each other via DDS with minimal configuration.

## Features

- **WiFi AP** – Native hostapd + dnsmasq so devices connect to one SSID and get DHCP/DNS from the Pi
- **Local DNS** – `buoy.buoy`, `hub.buoy`, and `hostname.buoy` for connected devices. After joining WiFi, open **http://buoy.buoy:8080** for the command center.
- **ROS 2 Jazzy** – Runs in Docker with **host networking** so the hub and WiFi clients share the same DDS multicast domain
- **Command center** – Web dashboard (ROS topic graph link, connected devices list). Optional **captive portal** (Nodogsplash): when enabled, new WiFi clients are redirected here on first browse; set `captive_portal_enable: false` in `ansible/group_vars/all.yml` to skip.
- **Single image** – Flash one image to each Pi; first boot runs Ansible to configure the hub

## Quick links

- **[Changelog](CHANGELOG.md)** – Notable changes and migration notes
- **[User guide: connecting and interacting with ROS devices](docs/ros-hub.md)** – For users of the hub: connect to WiFi, run ROS 2 nodes, use rosbridge (Python, JavaScript, TypeScript examples)
- **[Image build: flash and first boot](image/README.md)** – Build the image (with network once); first boot on the Pi runs offline. Use the **headless** (Lite/server) base OS. **GitHub Actions:** Run **Actions → Build Image and Release** to build and publish a release with the image and Pi Imager manifest. *(Originally developed for [MASER-DC](https://www.maserdc.org/) Buoy project.)*
- **[Build image with QEMU](image/BUILD-QEMU.md)** – Build the image on a PC (Linux, macOS, or Windows via WSL2) using QEMU emulation—no Raspberry Pi required. **Easiest:** `uv run build` (requires [UV](https://docs.astral.sh/uv/) and Docker; see [image/README.md](image/README.md) for install).

## Running the playbook manually

On a Raspberry Pi 5 with Raspberry Pi OS 64-bit (Trixie, Lite/server, headless):

```bash
git clone https://github.com/your-org/buoy.git
cd buoy/ansible
ansible-playbook -i localhost, -c local playbook.yml
```

Or use **ansible-pull** (e.g. from a first-boot script):

```bash
ansible-pull -U https://github.com/your-org/buoy.git -C main -i localhost, -d /tmp/buoy ansible/playbook.yml
```

## Variables

Edit `ansible/group_vars/all.yml` to set hostname, WiFi SSID/passphrase, ROS domain ID, and ports. Key variables: `buoy_hostname`, `wifi_ssid`, `wifi_passphrase`, `ros_domain_id`, `ros_bridge_port`, `command_center_port`.

**Offline first boot:** Default is `offline_first_boot: true` so the playbook does not require internet when it runs on first boot (e.g. in the field). Build the image once with network and `offline_first_boot: false` so Docker, hostapd, images, and pnpm deps are installed; then image the SD and set `offline_first_boot: true` again. See [image/README.md](image/README.md).

## License

MIT License. See [LICENSE](LICENSE) for details.
