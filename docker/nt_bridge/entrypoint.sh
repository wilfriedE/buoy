#!/bin/bash
set -e
source /opt/ros/jazzy/setup.bash
exec python3 /app/bridge.py
