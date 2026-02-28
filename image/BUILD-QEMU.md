# Building the Maser Buoy image with QEMU (no Raspberry Pi required)

You can build the flashable image on a regular PC by running the Ansible playbook inside the Raspberry Pi OS root filesystem using **QEMU user-mode emulation** and **chroot**. This works on **Linux**, **macOS**, and **Windows (WSL2)**. The result is the same as building on a real Pi: a modified Raspberry Pi OS image you can write to an SD card.

**Easiest:** If you have Docker Desktop, run **`./image/build-with-docker.sh`** from the repo root (see [image/README.md](README.md)). The sections below are for manual QEMU/chroot steps per OS.

**Base image:** Use **Raspberry Pi OS 64-bit (Trixie) – Lite** (headless). Download from [Raspberry Pi OS – Other](https://www.raspberrypi.com/software/operating-systems/) (e.g. “Raspberry Pi OS (64-bit) – Lite”) or via [Raspberry Pi Imager](https://www.raspberrypi.com/software/).

**Idea:** Mount the `.img` file’s root partition on your host, copy in the QEMU static binary so the host can run arm64 binaries, chroot into the mounted root, and run the playbook (with network from the host). Then unmount; the image file is ready to flash.

---

## Prerequisites (all platforms)

- **Raspberry Pi OS 64-bit Lite image** – e.g. `2025-xx-xx-raspios-trixie-arm64-lite.img.xz` (or `.img`).
- **Maser Buoy repo** – cloned somewhere (e.g. `~/maser_buoy`).
- **Enough disk space** – several GB free for the image and temporary mounts.
- **Network** – required while running the playbook inside the chroot (the chroot will use the host’s network).

---

## Linux

### 1. Install QEMU and tools

**Debian / Ubuntu / Raspberry Pi OS:**

```bash
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support
```

**Fedora:**

```bash
sudo dnf install -y qemu-user-static
```

**Arch:**

```bash
sudo pacman -S qemu-user-static binfmt-support
```

Register the arm64 binary format (Debian/Ubuntu/Arch with binfmt-support):

```bash
# May already be done by the package; if not:
sudo update-binfmts --enable
```

### 2. Download and prepare the image

```bash
# Example: download (adjust URL to latest 64-bit Lite)
# wget https://downloads.raspberrypi.com/raspios_lite_arm64/images/.../2025-xx-xx-raspios-trixie-arm64-lite.img.xz
# unxz 2025-xx-xx-raspios-trixie-arm64-lite.img.xz

# Or use an image you already have; set the path:
IMG="$HOME/Downloads/2025-xx-xx-raspios-trixie-arm64-lite.img"
```

Create a writable copy so the original stays intact:

```bash
cp "$IMG" maser_buoy_build.img
IMG=maser_buoy_build.img
```

### 3. Mount the image’s root partition

The root filesystem is usually the **second** partition. Use `losetup -P` so the kernel exposes partition devices:

```bash
sudo losetup -P -f "$IMG"
# Example: loop device is /dev/loop0
LOOP=$(losetup -l -n -O NAME -j "$IMG" | head -1)
ROOT_PART="${LOOP}p2"
sudo mount "$ROOT_PART" /mnt
# If p2 doesn't exist, run: sudo partprobe "$LOOP" and check with lsblk
```

If your distro doesn’t create `p2` automatically:

```bash
# Inspect partitions
sudo fdisk -l "$IMG"
# Mount root (partition 2) with offset; example offset for 532480 sectors:
# sudo mount -o loop,offset=$((532480*512)),sizelimit=... "$IMG" /mnt
```

### 4. Enable arm64 emulation in chroot

```bash
sudo cp /usr/bin/qemu-aarch64-static /mnt/usr/bin/
```

### 5. Bind-mount host resources (network, proc, sys, dev)

```bash
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /dev/pts /mnt/dev/pts
sudo cp /etc/resolv.conf /mnt/etc/resolv.conf
```

### 6. Copy the repo and set offline_first_boot

```bash
sudo mkdir -p /mnt/opt/maser_buoy
sudo cp -a /path/to/maser_buoy/. /mnt/opt/maser_buoy/
sudo sed -i 's/offline_first_boot: true/offline_first_boot: false/' /mnt/opt/maser_buoy/ansible/group_vars/all.yml
```

### 7. Chroot and run the playbook

In a minimal chroot, **systemd is not running**, so the Docker daemon may not start during the playbook. Two approaches:

**Option 1 – Start Docker manually in the chroot, then run the playbook**

(Requires bind mounts from step 5 so `/proc` and `/sys` are available.) The playbook installs Docker; in chroot `systemctl start docker` will not start the daemon. So: run the playbook once (it installs Docker and may fail at “start docker”), then start `dockerd` manually and run the playbook again so the `ros2_docker` role can run `docker compose up -d --build`. Use the `vfs` storage driver to avoid overlay issues in chroot.

```bash
sudo chroot /mnt /bin/bash -c '
  apt-get update && apt-get install -y ansible
  cd /opt/maser_buoy/ansible
  ansible-playbook -i localhost, -c local playbook.yml
'
# If Docker did not start (expected in chroot), start it and re-run so compose can build:
sudo chroot /mnt /bin/bash -c '
  dockerd --storage-driver=vfs &
  sleep 15
  cd /opt/maser_buoy/ansible && ansible-playbook -i localhost, -c local playbook.yml
  kill %1
'
```

**Option 2 – Run playbook and ignore Docker start errors; build images on first real boot**

If you prefer not to run Docker in the chroot, run the playbook as below. Package installs and file copies will succeed; `systemctl start docker` may fail. Then **do not** set `offline_first_boot: true` for the baked image—on first boot on a real Pi (with network), the playbook will run again and pull/build images. Alternatively, build the image once on a real Pi to get a fully offline-capable image.

```bash
sudo chroot /mnt /bin/bash -c '
  apt-get update && apt-get install -y ansible
  cd /opt/maser_buoy/ansible
  ansible-playbook -i localhost, -c local playbook.yml
'
```

If you use **Python 3 and venv** for Ansible on the host, you can still run Ansible **inside** the chroot (the chroot has its own Python and we install Ansible there). The commands above are enough.

### 8. (Optional) Save Docker images for offline first boot

```bash
sudo chroot /mnt /bin/bash -c '
  cd /opt/maser_buoy/docker
  docker save -o docker_images.tar $(docker compose images -q)
'
```

Then set `offline_first_boot` back to `true` in the baked repo:

```bash
sudo sed -i 's/offline_first_boot: false/offline_first_boot: true/' /mnt/opt/maser_buoy/ansible/group_vars/all.yml
```

### 9. Install first-boot unit and clean up

```bash
sudo cp /mnt/opt/maser_buoy/image/first_boot/maser-buoy-firstboot.service /mnt/etc/systemd/system/
sudo chroot /mnt systemctl enable maser-buoy-firstboot.service
```

### 10. Unmount

```bash
sudo umount /mnt/dev/pts
sudo umount /mnt/dev
sudo umount /mnt/proc
sudo umount /mnt/sys
sudo umount /mnt
sudo losetup -d "$LOOP"
```

Your built image is `maser_buoy_build.img`. Flash it with Raspberry Pi Imager (“Use custom”) or `dd`.

---

## macOS

On macOS you don’t have `losetup` or native loop devices. Use a **Linux VM or Docker** to run the same steps, or use **multipass** / **UTM** with a small Linux image and pass through the RPi image file.

### Option A: Use the repo script (recommended)

From the repo root, run **`./image/build-with-docker.sh`** (see [image/README.md](README.md)). It uses a privileged container to mount the image and run the playbook. If it fails with "Could not create loop device" on Docker Desktop for Mac, use Option B.

### Manual Docker approach (if you prefer not to use the script)

Use a privileged container that can mount loop devices; the image file must be available inside the container.

1. **Install Docker Desktop** (or Colima, etc.).

2. **Create a helper script** (e.g. `build-in-docker.sh`) that:
   - Uses a Debian/Ubuntu image with `qemu-user-static`, `binfmt-support`, `kpartx` (or `losetup -P`), `ansible`, and `sudo`.
   - Binds the current directory (with the `.img` and repo) into the container.
   - Runs the same mount/chroot/playbook sequence as in the Linux section inside the container.

3. **Run the script** so the container has access to your `maser_buoy` clone and the Raspberry Pi OS Lite image; after the script finishes, the modified `.img` is in your bind-mounted directory.

Example (high level; adjust paths and image name):

```bash
# From the directory that contains your .img and maser_buoy repo
docker run --rm -it --privileged -v "$(pwd):/work" -w /work \
  debian:trixie bash -c '
    apt-get update && apt-get install -y qemu-user-static binfmt-support ansible
    update-binfmts --enable
    # Then same losetup, mount, cp qemu, bind mounts, chroot, playbook, unmount
    # Use /work for image and repo paths
  '
```

You’ll need to translate the Linux mount/chroot steps into commands run inside this container; the image file and repo are under `/work`.

### Option B: UTM or other VM with Linux (if Docker script fails on Mac)

1. Install **UTM** (or Parallels, VMware, etc.) and create a **Linux** VM (e.g. Ubuntu).
2. Copy the Raspberry Pi OS Lite `.img` and the Maser Buoy repo into the VM (shared folder or SCP).
3. Inside the VM, follow the **Linux** instructions above (mount image, qemu-user-static, chroot, playbook).
4. Copy the modified `.img` back to the Mac and flash it with Raspberry Pi Imager for macOS.

---

## Windows (WSL2)

Use **WSL2** with a Linux distro (e.g. Ubuntu) and run the same steps as on **Linux**. The image file and repo should live inside the WSL filesystem (e.g. under `~/maser_buoy`) so that loop mounts and chroot work correctly.

### 1. Install WSL2 and Ubuntu

In PowerShell (Admin):

```powershell
wsl --install -d Ubuntu
```

After reboot, open Ubuntu from the Start menu.

### 2. Install QEMU and tools inside WSL2

```bash
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support
sudo update-binfmts --enable
```

### 3. Put the image and repo in WSL

- Copy the Raspberry Pi OS 64-bit Lite `.img` into your WSL home (e.g. `cp /mnt/c/Users/You/Downloads/raspios-lite.img ~/`).
- Clone or copy the Maser Buoy repo into WSL (e.g. `~/maser_buoy`).

Avoid working from `/mnt/c/...` for the image when using loop mounts; use a path under your Linux filesystem (e.g. `~/maser_buoy_build/`).

### 4. Run the same steps as Linux

From step **2. Download and prepare the image** through **10. Unmount**, use the same commands. Use paths like `$HOME/maser_buoy_build.img` and `$HOME/maser_buoy`.

### 5. Flash the image from Windows

After unmounting, the built image is inside WSL (e.g. `~/maser_buoy_build.img`). Copy it to Windows if needed:

```powershell
# From PowerShell
copy \\wsl$\Ubuntu\home\YourUser\maser_buoy_build.img C:\Users\You\Downloads\
```

Then use **Raspberry Pi Imager for Windows** (“Use custom” and select that image), or use a tool that can write a raw image to the SD card.

---

## Summary

| Host OS   | Method                                      |
|----------|---------------------------------------------|
| Linux    | Native: losetup, mount, qemu-user-static, chroot, playbook |
| macOS    | Docker (privileged) with Linux image, or Linux VM (UTM) and run Linux steps |
| Windows  | WSL2 (Ubuntu): same as Linux; flash from Windows with Imager |

In all cases you use **Raspberry Pi OS 64-bit (Trixie) – Lite** (headless), run the playbook with **offline_first_boot: false** inside the chroot, then re-enable **offline_first_boot: true** and install the first-boot systemd unit so that when you flash the image and boot a real Pi (with no internet), the playbook runs in offline mode and only applies configuration.

---

## Troubleshooting

- **“Cannot start Docker” in chroot** – Use Option 1 (start `dockerd` manually with `--storage-driver=vfs`) or build the image on a real Pi once so Docker and images are already on disk.
- **Loop device or partition not found** – Run `sudo partprobe "$LOOP"` after `losetup -P`; on some systems the partition device may appear as `${LOOP}2` instead of `${LOOP}p2`. Use `lsblk` to confirm.
- **apt or network fails in chroot** – Ensure `/etc/resolv.conf` is copied into the chroot and that `bind` mounts for `/dev`, `/proc`, `/sys` are in place so DNS and package installs work.
- **macOS: no losetup** – Use the Docker or Linux VM approach; don’t try to mount the image natively on macOS for this workflow.
