#!/bin/bash
set -e
source /opt/ros/jazzy/setup.bash
source /app/llm_ws/install/setup.bash

# Run with namespace /llm so action is /llm/chat
# Fallback: if ros2 run fails (Package not found), run script directly (works with older images)
run_node() {
  if ros2 run llm_node llm_node --ros-args -r __ns:=/llm 2>/dev/null; then
    return 0
  fi
  # Fallback 1: run built executable (package in install but not in ament index)
  for exe in /app/llm_ws/install/llm_node/lib/llm_node/llm_node /app/llm_ws/install/lib/llm_node/llm_node; do
    if [ -f "$exe" ]; then
      exec python3 "$exe" --ros-args -r __ns:=/llm
    fi
  done
  # Fallback 2: run from source (build failed; llm_msgs is built, source is present)
  if [ -f /app/llm_ws/src/llm_node/llm_node/llm_node.py ]; then
    for d in /app/llm_ws/install/llm_msgs/lib/python3.12/site-packages /app/llm_ws/install/llm_msgs/lib/python3.11/site-packages; do
      [ -d "$d" ] && export PYTHONPATH="$d:$PYTHONPATH" && break
    done
    export PYTHONPATH="/app/llm_ws/src/llm_node:$PYTHONPATH"
    exec python3 /app/llm_ws/src/llm_node/llm_node/llm_node.py --ros-args -r __ns:=/llm
  fi
  echo "llm_node: no executable or source found" >&2
  return 1
}

run_node || { sleep 30; exit 1; }
