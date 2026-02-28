# Maser Buoy – Single flashable image build

This directory describes how to build a **single image** that you can flash to every Raspberry Pi 5. The hub is **headless** (no desktop or display); all UIs are web-based from devices on the WiFi. On first boot (e.g. in the field with **no internet**), the Pi configures itself by running the Ansible playbook in offline mode.

## Base OS: headless (Lite or server)

Use **Raspberry Pi OS 64-bit (Trixie) – Lite** (or the “other” / server variant without a desktop). Do **not** use the full desktop image; the stack runs entirely headless (RaspAP, Docker, command center, and captive portal are all accessed via browser from other devices).

## No internet during initial setup

The playbook supports **offline first boot**. Set `offline_first_boot: true` in `ansible/group_vars/all.yml` (this is the default). The image must be **built once with internet** so that Docker, RaspAP, Docker images, and command center dependencies are already on the disk. When you flash that image and boot a Pi with no network, the first-boot service runs the playbook and only applies configuration and starts services; it does not install packages or pull images.

## Build the image (with network)

Do this once on a machine or Pi that has internet. To build **without a Raspberry Pi** (on a PC using QEMU), see **[BUILD-QEMU.md](BUILD-QEMU.md)** for Linux, macOS, and Windows (WSL2).

### Option A: Build on a real Raspberry Pi

1. Flash **Raspberry Pi OS 64-bit (Trixie) – Lite** (headless) to an SD card and boot the Pi with **network connected**.
2. Log in and set **offline_first_boot to false** so the playbook can install everything:
   ```bash
   sudo sed -i 's/offline_first_boot: true/offline_first_boot: false/' /path/to/maser_buoy/ansible/group_vars/all.yml
   ```
   Or edit `ansible/group_vars/all.yml` and set `offline_first_boot: false`.
3. Install Ansible and run the full playbook:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   sudo apt-get install -y ansible
   cd /opt/maser_buoy  # or wherever you cloned the repo
   sudo ansible-playbook -i localhost, -c local ansible/playbook.yml
   ```
   This installs Docker, pulls the RaspAP Docker image and starts it, pulls/builds ROS 2 images, runs `pnpm install` for the command center, and configures everything.
4. (Optional) Save Docker images to a tarball for fully offline clones:
   ```bash
   cd /opt/maser_buoy/docker && docker save -o docker_images.tar $(docker compose images -q)
   ```
5. Set **offline_first_boot** back to **true** in `group_vars/all.yml` (so that when this image is cloned and booted offline, the playbook does not try to use the network).
6. Install the first-boot systemd unit so that when you image this SD and boot another Pi, it runs the playbook once:
   ```bash
   sudo cp /opt/maser_buoy/image/first_boot/maser-buoy-firstboot.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable maser-buoy-firstboot.service
   ```
7. Power off and create an image of the SD card (e.g. `dd` or Raspberry Pi Imager “Use custom” with the card as source).

### Option B: Build on a PC with Docker (easiest – no Pi required)

If you have **Docker Desktop**: put a Raspberry Pi OS 64-bit Lite `.img` or `.img.xz` in `image/`, then from the repo root run **`./image/build-with-docker.sh`**. The script **automatically expands the image by 4 GiB** and grows the root partition, so you do **not** need Raspberry Pi Imager to increase storage. Output: **`image/maser_buoy_build.img`**. **WiFi uses native hostapd + dnsmasq** on the host (RaspAP Docker fails on Pi due to driver limitations). The command center and ROS run on the host/Docker. Docker Compose images for ROS are not pre-built in chroot; first boot or a later run with network will pull/build them. If the script fails with "Could not create loop device" (e.g. on Mac), use Linux/WSL2 or see **[BUILD-QEMU.md](BUILD-QEMU.md)** for manual steps.

**Expected build output:** You may see `failed to start daemon: Devices cgroup isn't mounted` and `Cannot connect to the Docker daemon`. These are expected when building inside Docker/QEMU—the chroot lacks full cgroup support. WiFi uses native hostapd (not Docker); on first boot the playbook configures hostapd and dnsmasq on the host.

## Pi Imager settings (hostname, WiFi, SSH)

When you use **Use custom** and select the image file directly, Pi Imager does not show the settings gear because it has no metadata for custom images. To enable hostname/WiFi/SSH customization:

1. Run `./image/create-pi-imager-manifest.sh` (optionally with the image path)
2. In Pi Imager: **App Options** (gear) → **Content Repository** → **EDIT** → **Use custom file** → select `image/maser_buoy.rpi-imager-manifest` → **APPLY & RESTART**
3. The Maser Buoy image will appear in the OS list with the settings gear enabled

Or double-click the manifest file to open it in Imager. The manifest uses `init_format: cloudinit-rpi` (same as Raspberry Pi OS) so Imager can apply hostname, WiFi, and SSH settings to the boot partition.

## Deploy (no internet)

Flash the built image to each Pi 5, insert the SD, and power on **without network**. The first-boot service runs the playbook with `offline_first_boot: true`, which configures hostapd and dnsmasq for WiFi, starts ROS Docker Compose, command center, and other services. Hostapd and dnsmasq run natively on the host and provide the MaserBuoy AP with .buoy DNS. The first_boot role then disables the service so it does not run again on the next boot.

## First-boot unit

- **Unit file:** `image/first_boot/maser-buoy-firstboot.service`
- **Option A (baked playbook):** `ExecStart` runs the playbook from `/opt/maser_buoy/ansible` (no clone). Use this for the offline image.
- **Option B (ansible-pull):** Use `scripts/first_boot.sh` with `REPO_URL` when the Pi has network and you prefer to pull the latest playbook on first boot.

## After imaging

Flash the image to each Pi, power on. First boot runs the playbook in offline mode. Subsequent reboots do not re-run the first-boot service.

## Checking the device after flashing

You have no display, so use one of these to verify the Pi is up and see what’s going on.

### Option 1: Ethernet + SSH (recommended)

1. **Connect the Pi to your router with an Ethernet cable** (before or right after first boot). The Pi gets an IP via DHCP on `eth0`.
2. **Wait 1–2 minutes** for first boot (playbook, services).
3. **Find the Pi’s IP**: check your router’s DHCP/client list (hostname `maser-buoy`), or from another machine on the same LAN run:
   - `arp -a` (look for a new entry after the Pi boots), or
   - `nmap -sn 192.168.1.0/24` (adjust subnet to match your router).
4. **SSH in:** `ssh maser@<ip>` (default password: `ChangeMe`)
   - The playbook creates user `maser` with sudo access. Override in `ansible/group_vars/all.yml` (`maser_buoy_ssh_user`, `maser_buoy_ssh_password`) before building the image.
5. **Check first boot and services:**
   - `cat /etc/maser_buoy_configured` — present if the first-boot playbook completed.
   - `sudo systemctl status maser-buoy-command-center` — command center.
   - `sudo docker ps` — RaspAP and (if pulled) ROS containers.
   - From a device on the Pi’s **WiFi** (MaserBuoy): open http://maser.buoy:8080 for the command center.

SSH is enabled by the playbook so the Pi accepts logins as soon as it has an IP.

### Option 2: Serial console

With a **USB‑to‑TTL** adapter (e.g. PL2303, CP2102) connect to **GPIO 14 (Tx)** and **GPIO 15 (Rx)**, 3.3 V (do not use 5 V). Use 115200 8N1. You get a login console and full boot logs; useful if the Pi doesn’t get an IP or you need to debug early boot.

### SSH over WiFi (optional)

The built-in WiFi (wlan0) is used for the **access point** (MaserBuoy). To SSH over WiFi without Ethernet you’d need a **second WiFi interface** (e.g. USB WiFi as `wlan1`) and configure it as a client to your network; the playbook doesn’t do that by default. For verification, Ethernet (Option 1) or serial (Option 2) is enough.

### WiFi not broadcasting (troubleshooting)

If the MaserBuoy SSID does not appear:

1. **Check hostapd:** `sudo systemctl status hostapd` — it should be active.
2. **Check wlan0:** `ip link show wlan0` — should show state UP after wifi-ap-setup runs.
3. **Check who manages wlan0:** `nmcli device status` — if `wlan0` shows `managed` instead of `unmanaged`, NetworkManager is holding it. Re-run the playbook to apply the unmanage config.
4. **Check hostapd logs:** `sudo journalctl -u hostapd -n 50` — look for driver or interface errors.
