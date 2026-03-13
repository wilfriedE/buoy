#!/usr/bin/env bash
# Buoy – install on Debian, Ubuntu, or Fedora
# Usage (from release): curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash
#        sudo bash install.sh [--no-wifi | --wifi]
#
# --no-wifi   Headless only (no hostapd). Default for install script.
# --wifi      Enable WiFi AP if wlan0 exists.

set -e

BUOY_ROOT="${BUOY_ROOT:-/opt/buoy}"
REPO_URL="${REPO_URL:-https://github.com/wilfriedE/buoy.git}"
BUOY_VERSION="${BUOY_VERSION:-main}"
WIFI_AP_ENABLE=false

for arg in "$@"; do
  case "$arg" in
    --wifi)    WIFI_AP_ENABLE=true ;;
    --no-wifi) WIFI_AP_ENABLE=false ;;
    *)         echo "Unknown option: $arg. Use --wifi or --no-wifi."; exit 1 ;;
  esac
done

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (e.g. sudo bash $0)"
  exit 1
fi

# Detect distro
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "Cannot detect OS. /etc/os-release not found."
  exit 1
fi

# Supported: Debian, Ubuntu, Fedora, RHEL, Rocky, Alma
case "$ID" in
  debian|ubuntu)
    PKG_MGR=apt
    ;;
  fedora|rhel|rocky|almalinux)
    if [[ "${ID_LIKE:-}" == *fedora* ]] || [[ "${ID_LIKE:-}" == *rhel* ]]; then
      PKG_MGR=dnf
    else
      PKG_MGR=dnf
    fi
    ;;
  *)
    if [[ "${ID_LIKE:-}" == *debian* ]] || [[ "${ID_LIKE:-}" == *ubuntu* ]]; then
      PKG_MGR=apt
    elif [[ "${ID_LIKE:-}" == *fedora* ]] || [[ "${ID_LIKE:-}" == *rhel* ]]; then
      PKG_MGR=dnf
    else
      echo "Unsupported OS: $ID ($ID_LIKE). Supported: Debian, Ubuntu, Fedora, RHEL, Rocky, Alma."
      exit 1
    fi
    ;;
esac

echo "[*] Detected: $PRETTY_NAME (using $PKG_MGR)"
echo "[*] Version: $BUOY_VERSION"
echo "[*] WiFi AP: $WIFI_AP_ENABLE"
echo ""

# Install prerequisites (Ansible will install Docker via its role)
if [ "$PKG_MGR" = "apt" ]; then
  apt-get update -qq
  apt-get install -y ansible git curl
elif [ "$PKG_MGR" = "dnf" ]; then
  dnf install -y ansible git curl
else
  echo "Unknown package manager."
  exit 1
fi

# Clone, update, or use existing repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$REPO_DIR/ansible/playbook.yml" ]; then
  echo "[*] Using repo at $REPO_DIR"
  BUOY_ROOT="$REPO_DIR"
elif [ -d "$BUOY_ROOT/.git" ] && [ -f "$BUOY_ROOT/ansible/playbook.yml" ]; then
  echo "[*] Using existing repo at $BUOY_ROOT"
  if [ "$BUOY_VERSION" = "main" ]; then
    (cd "$BUOY_ROOT" && git pull --rebase || true)
  fi
else
  echo "[*] Cloning Buoy $BUOY_VERSION to $BUOY_ROOT"
  mkdir -p "$(dirname "$BUOY_ROOT")"
  git clone -b "$BUOY_VERSION" --depth 1 "$REPO_URL" "$BUOY_ROOT"
fi

# Run playbook (offline_first_boot=false so we install packages)
echo "[*] Running Ansible playbook..."
cd "$BUOY_ROOT/ansible"
ansible-playbook -i localhost, -c local playbook.yml \
  -e "offline_first_boot=false" \
  -e "wifi_ap_enable=$WIFI_AP_ENABLE"

# Mark as configured
touch /etc/buoy_configured 2>/dev/null || true

echo ""
echo "Buoy installed. Web portal: http://localhost (or http://$(hostname))"
if [ "$WIFI_AP_ENABLE" = true ]; then
  echo "WiFi AP: Connect to the Buoy network and open http://buoy.buoy"
fi
