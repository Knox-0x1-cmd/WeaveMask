#!/usr/bin/env bash
set -euo pipefail

if [ ! -e /dev/kvm ]; then
  echo "WARNING: /dev/kvm not found; emulator will fail later" >&2
fi

echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo -n tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
sudo -n udevadm control --reload-rules
sudo -n udevadm trigger
sudo -n chmod 666 /dev/kvm 2>/dev/null || true
ls -l /dev/kvm || true
