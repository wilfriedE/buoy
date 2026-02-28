# Changelog

All notable changes to Buoy are documented in this file.

## [Unreleased]

### Fixed – ROS image now baked into SD image (macOS / Linux)

**Why:** The image build previously tried to start `dockerd` inside the chroot to build the ROS image. On macOS (and some Linux setups), dockerd fails in chroot with "Devices cgroup isn't mounted", so the ROS image was never built and `docker_images.tar` was missing. The Pi would fail on first boot when trying to start the ROS container.

**What changed:**
- ROS image is now built in a separate Docker run on the host (before the main chroot build)
- Uses `docker:24` with the host socket to run `docker compose build` and `docker save`
- The resulting tar is copied into the mounted image after the playbook runs
- No chroot Docker socket bind-mount needed; works reliably on macOS and Linux

### Added – ROS container starts soon after dockerd on boot

**Why:** The ROS (rosbridge) container was previously started by the Ansible playbook in `first_boot`, which waits for `network-online.target` and runs four roles first. That caused a long delay between dockerd starting and the ROS container being available.

**What changed:**
- New `buoy-ros.service` systemd unit runs `docker compose up -d` as soon as dockerd is ready
- Service has `After=docker.service` and `ConditionPathExists` for the compose file (skips on first boot before playbook creates it)
- On subsequent boots, the ROS container starts within seconds of dockerd, instead of waiting for the full playbook

### Changed – WiFi AP: RaspAP Docker → Native hostapd + dnsmasq

**Why:** Hostapd fails inside the RaspAP Docker container on Raspberry Pi. The wireless driver does not support the operations hostapd needs when running in a containerized environment (e.g. "Operation not supported" -95). This is a known limitation on Pi hardware.

**What changed:**
- Replaced the `raspap` Ansible role with a new `wifi_ap` role
- WiFi AP now runs natively on the host using `hostapd` and `dnsmasq`
- Removed RaspAP Docker image from the build pipeline (faster builds, no pre-pull step)
- Playbook now installs `hostapd` and `dnsmasq` via apt and configures them directly

**Initial goals retained:**

| Goal | Before (RaspAP Docker) | After (Native hostapd) |
|------|-------------------------|-------------------------|
| WiFi access point | Hostapd crashed in container | ✅ Working |
| Configurable SSID/password | Via env vars (never worked) | ✅ Via `wifi_ssid`, `wifi_passphrase` in group_vars |
| DHCP for connected devices | dnsmasq in container | ✅ dnsmasq on host (10.3.141.2–254) |
| Local .buoy DNS (maser.buoy, hub.buoy) | dnsmasq in container | ✅ dnsmasq on host, same config |
| NAT for WiFi clients → LAN/internet | iptables | ✅ iptables, same rules |
| Offline first boot | RaspAP tarball baked into image | ✅ hostapd/dnsmasq installed during build |
| Single flashable image | Yes | ✅ Yes |

**Trade-off:** The RaspAP web GUI (manage AP settings, view clients at http://10.3.141.1) is no longer available. It was never functional because hostapd failed in the container. AP configuration is now done via Ansible variables in `ansible/group_vars/all.yml` before building or deploying.

**Migration:** Existing deployments with the RaspAP container will have it stopped and removed when the playbook runs. The new `wifi_ap` role configures and starts native hostapd and dnsmasq automatically.
