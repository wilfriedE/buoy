#!/bin/bash
# Runs inside the Docker container (Debian trixie, privileged).
# Expects: /work/image.img (Raspberry Pi OS Lite image, writable copy)
#          /repo (bind-mount of Buoy repo, read-only)
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

echo "[*] Copying repo to /opt/buoy in image..."
mkdir -p "$MNT/opt/buoy"
rsync -a --exclude=.git --exclude=.venv --exclude=node_modules --exclude=build --exclude='*.img' --exclude='*.img.xz' "$REPO/" "$MNT/opt/buoy/"

echo "[*] Setting offline_first_boot to false for build..."
sed -i 's/offline_first_boot: true/offline_first_boot: false/' "$MNT/opt/buoy/ansible/group_vars/all.yml"

echo "[*] Running playbook (ROS image pre-built on host; skip compose start in chroot)..."
# Install ansible-core only (full ansible pulls in many collections and fills the root partition)
# docker_image_build=true: skips "Start ROS 2" tasks (no dockerd in chroot)
# docker_image_prebuilt=true: skips "Build ROS 2 image" task (we built on host, copy tar below)
chroot "$MNT" /bin/bash -c '
  apt-get -qq update
  apt-get -qq install -y ansible-core
  apt-get -qq clean
  cd /opt/buoy/ansible
  ansible-playbook -i localhost, -c local playbook.yml -e docker_image_build=true -e docker_image_prebuilt=true
'

echo "[*] Copying pre-built ROS image tar into image..."
if [ ! -f /work/docker_images.tar ]; then
  echo "ERROR: /work/docker_images.tar not found. ROS image pre-build may have failed."
  exit 1
fi
cp -f /work/docker_images.tar "$MNT/opt/buoy/docker/docker_images.tar"

echo "[*] Setting offline_first_boot back to true..."
sed -i 's/offline_first_boot: false/offline_first_boot: true/' "$MNT/opt/buoy/ansible/group_vars/all.yml"

echo "[*] Installing first-boot systemd unit..."
cp "$MNT/opt/buoy/image/first_boot/buoy-firstboot.service" "$MNT/etc/systemd/system/"
chroot "$MNT" systemctl enable buoy-firstboot.service 2>/dev/null || true

echo "[*] Unmounting..."
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
