#!/usr/bin/env bash
# Buoy – install on Debian, Ubuntu, or Fedora
# Usage: curl -sSL https://github.com/wilfriedE/buoy/releases/download/v1.0.0/install.sh | sudo bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/install.sh" "$@"
