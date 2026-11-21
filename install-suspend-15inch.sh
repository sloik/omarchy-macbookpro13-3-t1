#!/usr/bin/env bash
# install-suspend-15inch.sh — working lid-close suspend on the 15" T1 MacBook Pro (13,3 / 14,3).
# s2idle + pcie_port_pm=off + no D3cold for PCI devices + thunderbolt unloaded around sleep.
# Verified on MacBookPro13,3 (Omarchy 4.5.0): suspend/resume OK, GPU, Wi-Fi, all 3 xHCI and the
# Touch Bar chip back after resume; wake needs a keypress. Recipe from nohzafk/omarchy-macbookpro-t1
# PR #5 (strawberry-code), which explains each part. Run: sudo bash install-suspend-15inch.sh, reboot.
set -euo pipefail
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
[ "$(id -u)" -eq 0 ] || { echo "run with: sudo bash $0"; exit 1; }
m=$(cat /sys/class/dmi/id/product_name)
case "$m" in MacBookPro13,3|MacBookPro14,3) ;; *) echo "$m is not a 15-inch T1 model; not installing"; exit 1;; esac
S=$KIT/suspend-15inch
install -m644 "$S/90-macbook-t1-pci-pm.rules" /etc/udev/rules.d/
install -d /etc/limine-entry-tool.d
install -m644 "$S/macbook-t1-suspend.conf" /etc/limine-entry-tool.d/
install -d /usr/lib/systemd/system-sleep
install -m755 "$S/macbook-t1-thunderbolt" /usr/lib/systemd/system-sleep/
limine-update
echo "Installed. Reboot, then check: cat /sys/power/mem_sleep  (should show [s2idle])"
