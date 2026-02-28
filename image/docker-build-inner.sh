#!/bin/bash
# Runs inside the Docker container (Debian trixie, privileged).
# Expects: /work/image.img (Raspberry Pi OS Lite image, writable copy)
#          /repo (bind-mount of Maser Buoy repo, read-only)
# Builds the image by mounting root partition, chroot, and running Ansible.

set -e
WORK=/work
REPO=/repo
MNT=/mnt
IMG="${IMG:-$WORK/image.img}"

echo "[*] Installing QEMU and tools..."
apt-get -qq update
apt-get -qq install -y qemu-user-static binfmt-support rsync parted e2fsprogs

# Expand image so the root partition has room for Docker, ROS, npm, etc. (avoids "No space left on device")
echo "[*] Expanding image by 4 GiB and growing root partition..."
dd if=/dev/zero bs=1M count=4096 status=none >> "$IMG"
LOOP_FULL=$(losetup -f --show "$IMG")
parted -s "$LOOP_FULL" resizepart 2 100%
losetup -d "$LOOP_FULL"
# Resize the root filesystem to use the new partition size
PARTX_OUT=$(partx -r -o START,SECTORS "$IMG" 2>/dev/null | tail -n +2 | sed -n '2p')
START=$(echo "$PARTX_OUT" | awk '{print $1}')
SECTORS=$(echo "$PARTX_OUT" | awk '{print $2}')
OFFSET=$(( START * 512 ))
SIZELIMIT=$(( SECTORS * 512 ))
LOOP_P2=$(losetup -f -o "$OFFSET" --sizelimit "$SIZELIMIT" --show "$IMG")
resize2fs "$LOOP_P2"
losetup -d "$LOOP_P2"

echo "[*] Mounting root partition (by offset; explicit loop device to avoid overlapping loop error)..."
# Get partition 2 start and size in sectors (Raspberry Pi OS root is usually p2)
PARTX_OUT=$(partx -r -o START,SECTORS "$IMG" 2>/dev/null | tail -n +2 | sed -n '2p')
if [ -n "$PARTX_OUT" ]; then
  START=$(echo "$PARTX_OUT" | awk '{print $1}')
  SECTORS=$(echo "$PARTX_OUT" | awk '{print $2}')
  OFFSET=$(( START * 512 ))
  SIZELIMIT=$(( SECTORS * 512 ))
else
  # Fallback: typical RPi OS root start; size = rest of file
  START=532480
  OFFSET=$(( START * 512 ))
  SIZELIMIT=$(( $(stat -c %s "$IMG") - OFFSET ))
fi
# Single losetup call: find free device, attach with offset/sizelimit, print device name
LOOP=$(losetup -f -o "$OFFSET" --sizelimit "$SIZELIMIT" --show "$IMG")
mount "$LOOP" "$MNT"

echo "[*] Enabling arm64 emulation in chroot..."
cp /usr/bin/qemu-aarch64-static "$MNT/usr/bin/"

echo "[*] Bind-mounting dev, proc, sys..."
mount --bind /dev "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys "$MNT/sys"
mount --bind /dev/pts "$MNT/dev/pts"
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

echo "[*] Copying repo to /opt/maser_buoy in image..."
mkdir -p "$MNT/opt/maser_buoy"
rsync -a --exclude=.git --exclude=.venv --exclude='*.img' --exclude='*.img.xz' "$REPO/" "$MNT/opt/maser_buoy/"
# Copy pre-pulled RaspAP image tarball for offline first boot
if [ -f "$WORK/raspap-docker.tar" ]; then
  mkdir -p "$MNT/opt/maser_buoy/docker"
  cp "$WORK/raspap-docker.tar" "$MNT/opt/maser_buoy/docker/"
  echo "[*] Copied RaspAP Docker image tarball into image for offline first boot."
fi

echo "[*] Setting offline_first_boot to false for build..."
sed -i 's/offline_first_boot: true/offline_first_boot: false/' "$MNT/opt/maser_buoy/ansible/group_vars/all.yml"

echo "[*] Running playbook (first pass; Docker service may not start in chroot)..."
# Install ansible-core only (full ansible pulls in many collections and fills the root partition)
# docker_image_build=true skips RaspAP quick install (chroot has no real network/cgroups).
chroot "$MNT" /bin/bash -c '
  apt-get -qq update
  apt-get -qq install -y ansible-core
  apt-get -qq clean
  cd /opt/maser_buoy/ansible
  ansible-playbook -i localhost, -c local playbook.yml -e docker_image_build=true
' || true

echo "[*] Starting Docker daemon in chroot and re-running playbook for docker compose..."
chroot "$MNT" /bin/bash -c '
  apt-get -qq clean
  dockerd --storage-driver=vfs &
  sleep 15
  cd /opt/maser_buoy/ansible
  ansible-playbook -i localhost, -c local playbook.yml -e docker_image_build=true
  kill %1 2>/dev/null || true
' || true

echo "[*] Saving Docker images for offline first boot..."
chroot "$MNT" /bin/bash -c '
  cd /opt/maser_buoy/docker 2>/dev/null && docker save -o docker_images.tar $(docker compose images -q) 2>/dev/null || true
' || true

echo "[*] Setting offline_first_boot back to true..."
sed -i 's/offline_first_boot: false/offline_first_boot: true/' "$MNT/opt/maser_buoy/ansible/group_vars/all.yml"

echo "[*] Installing first-boot systemd unit..."
cp "$MNT/opt/maser_buoy/image/first_boot/maser-buoy-firstboot.service" "$MNT/etc/systemd/system/"
chroot "$MNT" systemctl enable maser-buoy-firstboot.service 2>/dev/null || true

echo "[*] Unmounting..."
# Stop any daemons that might still be using the chroot (e.g. containerd from failed dockerd)
chroot "$MNT" /bin/bash -c 'killall dockerd containerd 2>/dev/null; sleep 2' || true
umount "$MNT/dev/pts" 2>/dev/null || true
umount "$MNT/dev" 2>/dev/null || true
umount "$MNT/proc" 2>/dev/null || true
umount "$MNT/sys" 2>/dev/null || true
if ! umount "$MNT" 2>/dev/null; then
  echo "[*] Lazy unmount (mount was busy)..."
  umount -l "$MNT"
fi
losetup -d "$LOOP" 2>/dev/null || true

echo "[*] Done. Built image: $IMG"
exit 0
