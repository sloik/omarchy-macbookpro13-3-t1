#!/usr/bin/env bash
# enable-ssh.sh — key-only SSH into this Mac, using the public key(s) in ./authorized_keys.
# Run:  sudo bash enable-ssh.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with: sudo bash $0"; exit 1; }
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
U=${SUDO_USER:?run with sudo from your normal account}
H=$(getent passwd "$U" | cut -d: -f6)
# full upgrade, never a partial -Sy: Arch does not support partial upgrades
command -v sshd >/dev/null || pacman -Syu --needed --noconfirm openssh
install -d -m700 -o "$U" -g "$U" "$H/.ssh"
[ -s "$KIT/authorized_keys" ] || { echo "put your public key in $KIT/authorized_keys first"; exit 1; }
cat "$KIT/authorized_keys" >> "$H/.ssh/authorized_keys"
sort -u -o "$H/.ssh/authorized_keys" "$H/.ssh/authorized_keys"
chown "$U:$U" "$H/.ssh/authorized_keys"; chmod 600 "$H/.ssh/authorized_keys"
install -d /etc/ssh/sshd_config.d
printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' > /etc/ssh/sshd_config.d/10-key-only.conf
systemctl enable --now sshd
systemctl restart sshd
if command -v ufw >/dev/null && ufw status | grep -q 'Status: active'; then ufw allow 22/tcp; fi
echo
echo "SSH is on:"
echo "  user: $U"
echo "  host: $(hostname)"
ip -4 -br addr | awk '$1 ~ /^(wl|en|eth)/ {print "  ip:   " $3 "  (" $1 ")"}'
