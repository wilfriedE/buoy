---
name: maser-buoy-commits
description: Generates conventional commit messages for Maser Buoy. Use when writing commit messages, squashing changes, or reviewing staged diffs.
---

# Maser Buoy Commit Messages

## Format

```
<type>(<scope>): <short summary>

<optional body>
```

## Types

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `build` | Build system, UV scripts, image pipeline |
| `ansible` | Ansible roles, playbook, vars |
| `chore` | Maintenance, deps, tooling |

## Scopes (examples)

- `image` – image build, download, manifest
- `ansible` – playbook, roles, group_vars
- `docker` – Dockerfile, compose
- `command-center` – Node.js app
- `captive-portal` – nodogsplash

## Examples

```
feat(ansible): add captive portal systemd override for nodogsplash

After=wifi-ap-setup.service hostapd.service
```

```
build(image): move ROS image build to host, copy tar into image

dockerd fails in chroot; pre-build on host and use docker_image_prebuilt
```

```
fix(docker): correct rosbridge host networking for DDS multicast
```

```
docs: add UV install and build workflow to image README
```
