---
name: maser-buoy-ansible
description: Manages Ansible roles and playbook for Maser Buoy Pi configuration. Use when adding roles, changing service order, or modifying docker_image_build / docker_image_prebuilt / offline_first_boot variables.
---

# Maser Buoy Ansible

## Role Order (playbook.yml)

1. common
2. docker
3. local_dns
4. wifi_ap
5. ros2_docker
6. command_center
7. captive_portal
8. first_boot

Do not reorder without checking service dependencies.

## Build vs Runtime Variables

| Variable | When | Effect |
|----------|------|--------|
| `docker_image_build=true` | SD image build (chroot) | Skips "Start ROS 2" tasks (no dockerd in chroot) |
| `docker_image_prebuilt=true` | ROS image built on host | Skips "Build ROS 2 image" task |
| `offline_first_boot=true` | Field deployment | Playbook does not install packages or pull images |

Set `offline_first_boot=false` during initial image build.

## Service Dependencies

- **nodogsplash**: `After=wifi-ap-setup.service hostapd.service` (captive_portal systemd override)
- **maser-buoy-ros**: `After=docker.service`

## Key Files

- `ansible/group_vars/all.yml` – hostname, WiFi, ROS, captive_portal_enable
- `ansible/roles/ros2_docker/tasks/main.yml` – conditions for `docker_image_build` / `docker_image_prebuilt`
- `ansible/roles/captive_portal/` – nodogsplash config and systemd drop-in
