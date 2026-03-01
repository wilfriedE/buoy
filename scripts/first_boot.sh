#!/bin/bash
# Buoy first-boot: clone repo and run Ansible playbook
set -e
REPO_URL="${REPO_URL:-https://github.com/wilfriedE/buoy.git}"
BRANCH="${BRANCH:-main}"
WORKDIR="/tmp/buoy_bootstrap"
mkdir -p "$WORKDIR"
cd "$WORKDIR"
if [ ! -d .git ]; then
  git clone --depth 1 -b "$BRANCH" "$REPO_URL" .
fi
cd ansible
ansible-playbook -i localhost, -c local playbook.yml
