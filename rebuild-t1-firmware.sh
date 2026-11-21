#!/usr/bin/env bash
# rebuild-t1-firmware.sh — regenerate the T1 firmware (EFI/APPLE/EMBEDDEDOS) from Apple's signing servers
# when you have no backup. Wraps niconistal/t1-revive (vendored copy, MIT) and builds its patched
# libimobiledevice stack from the source tarballs in vendor/t1-revive-deps (no GitHub needed).
# Still needs network: Apple's TSS signing server, and Apple's EmbeddedOSFirmware.pkg unless you pass one.
#
#   sudo bash rebuild-t1-firmware.sh                         download the pkg from Apple (checksum-pinned)
#   sudo T1_PKG=/path/EmbeddedOSFirmware.pkg bash rebuild-t1-firmware.sh
#
# Mains power, lid open. Afterwards: full power cycle (shut down, wait 20 s, power on).
set -euo pipefail
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
[ "$(id -u)" -eq 0 ] || { echo "run with: sudo bash $0"; exit 1; }
U=${SUDO_USER:?run with sudo from your normal account}
H=$(getent passwd "$U" | cut -d: -f6)
REV=666fe8dca338a4f1e8c71cef841361c3cbee35f7
WORK=$H/.cache/t1-revive-${REV:0:12}
PKG_SHA256=0c97ab746ec635b34b1bdea4e4722cd0173443e2ba6ede54cc6af3b5e220d230

if [ ! -x "$WORK/bin/t1-revive" ]; then
  echo "==> preparing t1-revive in $WORK"
  rm -rf "$WORK"; mkdir -p "$WORK/vendor/src"
  cp -R "$KIT/vendor/t1-revive/." "$WORK/"
  for t in "$KIT"/vendor/t1-revive-deps/*.tar.gz; do tar -xzf "$t" -C "$WORK/vendor/src"; done
  chown -R "$U:$U" "$WORK"
  chmod +x "$WORK/bin/t1-revive" "$WORK/build.sh"
fi
echo "==> build tools"
env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -S --needed --noconfirm base-devel autoconf automake libtool pkgconf openssl libusb libzip curl readline
if [ ! -d "$WORK/prefix" ]; then
  echo "==> building the patched libimobiledevice stack (offline, from vendored sources)"
  sudo -u "$U" bash "$WORK/build.sh" --offline
fi
ARGS=()
if [ -n "${T1_PKG:-}" ]; then
  echo "$PKG_SHA256  $T1_PKG" | sha256sum -c - || { echo "T1_PKG checksum mismatch"; exit 1; }
  ARGS=(--firmware "$T1_PKG")
fi
cd "$WORK"
echo "==> t1-revive preflight"
bin/t1-revive "${ARGS[@]}" preflight
echo "==> t1-revive regenerate (asks before each device step)"
bin/t1-revive "${ARGS[@]}" --confirm-each regenerate
echo
echo "Done. Back up $(findmnt -no TARGET -t vfat | head -1)/EFI/APPLE/EMBEDDEDOS somewhere off this disk,"
echo "then: full power cycle, and run omarchy-mac-fix.sh again."
