#!/usr/bin/env bash
# omarchy-mac-fix.sh — Wi-Fi + Touch Bar for the 2016 15" MacBook Pro (MacBookPro13,3, T1 chip) on Omarchy.
# Verified on a MacBookPro13,3 (2016 15") with Omarchy 4.5.0, kernel 7.2.15-1-omarchy (2026-11-21).
#
#   sudo bash omarchy-mac-fix.sh            run the next stage (it remembers where it is)
#   sudo bash omarchy-mac-fix.sh --verify   read-only status, changes nothing
#   sudo bash omarchy-mac-fix.sh --dry-run  show what the next stage would do, change nothing
#
# Stage 1 (offline): T1 firmware back onto the ESP, Wi-Fi NVRAM, Option-menu boot
#                    entry, Caps Lock = Escape, Touch Bar freeze guard. Then: FULL POWER CYCLE.
# Stage 2 (network): build + install the Touch Bar driver (DKMS), SSH.
#                    Then: FULL POWER CYCLE.
# Full power cycle = shut down, wait 20 s, press power. A reboot is NOT enough for the T1.
#
# Layout expected on the stick (next to this folder):
#   ./t1-firmware/{combined.memboot,FDRData,version.plist}  YOUR Mac's own T1 firmware backup (see README)
#   ./t1-firmware/SHA256SUMS                               sha256sum of those three files
#   ./firmware/brcmfmac43602-pcie.txt                      Wi-Fi NVRAM (shipped in this repo)
#   ./apple-ib-drv/          optional; otherwise stage 2 clones AJ-dev-i60/t1-touchbar at a pinned commit
#   ./authorized_keys        optional; public key(s) allowed to SSH in
set -uo pipefail

KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
T1DIR=$KIT/t1-firmware
NVRAM_SRC=$KIT/firmware/brcmfmac43602-pcie.txt
DRV_SRC=$KIT/apple-ib-drv
DRV_REPO=https://github.com/AJ-dev-i60/t1-touchbar
DRV_COMMIT=20d65c7b0fe6d05ea9734f869b27384a62de5109
MODEL=${MODEL:-MacBookPro13,3}   # only model verified; override at your own risk (13,1-3 / 14,1-3 are T1)
# Without NVRAM the chip reports a 00:90:4c:xx:xx:xx placeholder. Set WIFI_MAC to your real MAC if you know it
# (from macOS: System Information > Wi-Fi); otherwise the current address is reused.
WIFI_MAC=${WIFI_MAC:-}
STATE_DIR=/var/lib/omarchy-mac-fix
STATE=$STATE_DIR/stage
LOG_DIR=$KIT/logs
FW_DIR=/usr/lib/firmware/brcm
DKMS_NAME=apple-ib-drv; DKMS_VER=0.1

MODE=run
case "${1:-}" in
  --verify) MODE=verify;; --dry-run) MODE=dry;; "") ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "unknown option: $1" >&2; exit 2;;
esac

say()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mSTOP: %s\033[0m\n' "$*" >&2; exit 1; }
run()  { printf '    + %s\n' "$*"; [ "$MODE" = dry ] || "$@"; }

t1_id() {  # prints 8600, 1281 or none — sysfs, because Omarchy has no lsusb
  local d
  for d in /sys/bus/usb/devices/*/; do
    [ "$(cat "$d/idVendor" 2>/dev/null)" = 05ac ] || continue
    case "$(cat "$d/idProduct" 2>/dev/null)" in 8600) echo 8600; return;; 1281) echo 1281; return;; esac
  done
  echo none
}
esp() { # mount point of the vfat ESP (Omarchy: /boot)
  local m; for m in /boot /efi /boot/efi; do
    [ "$(findmnt -no FSTYPE "$m" 2>/dev/null)" = vfat ] && { echo "$m"; return; }
  done; findmnt -rno TARGET -t vfat | head -1
}
wifi_if() { local n; for n in /sys/class/net/wl*; do [ -e "$n" ] && { basename "$n"; return; }; done; }
online() { ping -c1 -W3 archlinux.org >/dev/null 2>&1 || ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; }
user_home() { local u=${SUDO_USER:-}; [ -n "$u" ] && getent passwd "$u" | cut -d: -f6; }

verify() {
  say "Status (read-only)"
  note "model:        $(cat /sys/class/dmi/id/product_name 2>/dev/null)"
  note "kernel:       $(uname -r)"
  note "stage done:   $(cat "$STATE" 2>/dev/null || echo 0)"
  note "T1 USB id:    $(t1_id)   (8600 = firmware loaded, 1281 = recovery/dark)"
  local e; e=$(esp); note "ESP:          ${e:-not found}"
  [ -n "$e" ] && note "T1 firmware:  $(ls "$e/EFI/APPLE/EMBEDDEDOS" 2>/dev/null | tr '\n' ' ')"
  local i; i=$(wifi_if); note "Wi-Fi iface:  ${i:-none}  MAC $(cat "/sys/class/net/$i/address" 2>/dev/null)"
  note "NVRAM file:   $(ls "$FW_DIR"/brcmfmac43602-pcie*.txt 2>/dev/null | tr '\n' ' ')"
  if dmesg 2>/dev/null | grep -q 'brcmfmac43602-pcie.txt failed'; then warn "NVRAM NOT loaded this boot"; else note "NVRAM load:   no '-2' error for .txt this boot"; fi
  if command -v iw >/dev/null; then
    if iw phy 2>/dev/null | grep -q 'Band 2'; then note "5 GHz:        Band 2 present"; else warn "5 GHz band missing"; fi
  fi
  if online; then note "network:      online"; else warn "network: offline"; fi
  note "dkms:         $(dkms status 2>/dev/null | grep -i apple || echo none)"
  note "modules:      $(lsmod | awk '/^apple_(ibridge|touchbar)/{print $1}' | tr '\n' ' ')"
  if dmesg 2>/dev/null | grep -qi 'skip_acpi_power.*NOT running'; then note "freeze guard: active (SOCW skipped)"; fi
  note "sshd:         $(systemctl is-enabled sshd 2>/dev/null || echo absent)"
}

[ "$MODE" = verify ] && { verify; exit 0; }
[ "$(id -u)" -eq 0 ] || die "run with: sudo bash $0"
[ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = "$MODEL" ] || die "this kit is for $MODEL only (the T1 firmware belongs to one Mac)"
mkdir -p "$LOG_DIR" 2>/dev/null && exec > >(tee -a "$LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log") 2>&1
mkdir -p "$STATE_DIR"
DONE=$(cat "$STATE" 2>/dev/null || echo 0)
[ "$MODE" = dry ] && say "DRY RUN — nothing will change"

stage1() {
  say "Stage 1 — offline fixes"
  # 1. T1 firmware
  local e id; e=$(esp); [ -n "$e" ] || die "no mounted vfat ESP found"
  id=$(t1_id); note "T1 is at $id; ESP is $e"
  if [ "$id" != 8600 ]; then
    say "Restoring the saved T1 firmware to $e/EFI/APPLE/EMBEDDEDOS"
    [ -f "$T1DIR/combined.memboot" ] || die "no T1 firmware backup in $T1DIR — see README (back it up before installing, or use t1-revive)"
    ( cd "$T1DIR" && sha256sum -c SHA256SUMS ) || die "T1 firmware checksum mismatch in $T1DIR"
    run mkdir -p "$e/EFI/APPLE/EMBEDDEDOS"
    run cp "$T1DIR"/combined.memboot "$T1DIR"/FDRData "$T1DIR"/version.plist "$e/EFI/APPLE/EMBEDDEDOS/" || die "copy to the ESP failed"
    run sync
    if [ "$MODE" != dry ]; then
      ( cd "$e/EFI/APPLE/EMBEDDEDOS" && sha256sum -c "$T1DIR/SHA256SUMS" ) || die "T1 firmware on the ESP does not match the backup"
    fi
  else
    note "T1 already healthy (8600) — firmware not touched"
  fi
  # 2. Touch Bar freeze guard, written before any driver can exist
  run install -d /etc/modprobe.d
  [ "$MODE" = dry ] || printf '%s\n' '# T1: never run ASOC.SOCW (hard-freezes the machine).' 'options apple_ibridge skip_acpi_power=1' > /etc/modprobe.d/apple-touchbar.conf
  # 3. Wi-Fi NVRAM (+ board-specific name), MAC filled in
  say "Wi-Fi calibration (NVRAM)"
  [ -f "$NVRAM_SRC" ] || die "missing $NVRAM_SRC"
  run install -d "$FW_DIR" "$STATE_DIR/backup"
  cp -n "$FW_DIR"/brcmfmac43602-pcie*.txt "$STATE_DIR/backup/" 2>/dev/null || true
  [ -n "$WIFI_MAC" ] || WIFI_MAC=$(cat "/sys/class/net/$(wifi_if)/address" 2>/dev/null)
  [ -n "$WIFI_MAC" ] || die "could not read the Wi-Fi MAC; set WIFI_MAC=xx:xx:xx:xx:xx:xx"
  note "NVRAM macaddr=$WIFI_MAC"
  if [ "$MODE" != dry ]; then
    sed "s/^macaddr=.*/macaddr=$WIFI_MAC/" "$NVRAM_SRC" > "$FW_DIR/brcmfmac43602-pcie.txt"
    cp "$FW_DIR/brcmfmac43602-pcie.txt" "$FW_DIR/brcmfmac43602-pcie.Apple Inc.-MacBookPro13,3.txt"
    chmod 644 "$FW_DIR"/brcmfmac43602-pcie*.txt
  fi
  if grep -rqs 'feature_disable' /etc/modprobe.d/; then note "brcmfmac feature_disable already set (Omarchy)"
  else [ "$MODE" = dry ] || echo 'options brcmfmac feature_disable=0x82000' > /etc/modprobe.d/brcmfmac-macbookpro.conf; note "added feature_disable=0x82000"; fi
  # 4. Option-menu boot entry (Apple's picker only lists \EFI\BOOT\BOOTX64.EFI)
  if [ -f "$e/EFI/limine/limine_x64.efi" ] && [ ! -f "$e/EFI/BOOT/BOOTX64.EFI" ]; then
    run mkdir -p "$e/EFI/BOOT"; run cp "$e/EFI/limine/limine_x64.efi" "$e/EFI/BOOT/BOOTX64.EFI"
  fi
  # 5. Caps Lock = Escape (no Esc key until the Touch Bar works)
  local h; h=$(user_home)
  if [ -n "$h" ] && [ -f "$h/.config/hypr/input.lua" ]; then
    if ! grep -q 'caps:escape' "$h/.config/hypr/input.lua"; then
      [ "$MODE" = dry ] || echo 'hl.config({ input = { kb_options = "caps:escape" } })' >> "$h/.config/hypr/input.lua"
      note "Caps Lock = Escape (takes effect after log out/in)"
    fi
  elif [ -n "$h" ] && [ -f "$h/.config/hypr/input.conf" ]; then
    if ! grep -q 'caps:escape' "$h/.config/hypr/input.conf"; then
      [ "$MODE" = dry ] || printf '\ninput {\n  kb_options = caps:escape\n}\n' >> "$h/.config/hypr/input.conf"
      note "Caps Lock = Escape"
    fi
  else warn "Hyprland input config not found — set kb_options = caps:escape by hand"; fi
  [ "$MODE" = dry ] || echo 1 > "$STATE"
  say "Stage 1 done. Now: SHUT DOWN, wait 20 s, power on. Then run this script again."
}

stage2() {
  say "Stage 2 — needs network"
  local id; id=$(t1_id)
  if [ "$id" != 8600 ]; then
    warn "T1 is at $id after the power cycle: the restored firmware did not load."
    note "Path B (rebuild from Apple's servers) — see README.md, section 'Path B'. Stopping before the driver."
    exit 1
  fi
  note "T1 healthy (8600)"
  online || die "no network. Connect Wi-Fi (impala / iwctl) or plug USB Ethernet, then run again."
  if dmesg | grep -q 'brcmfmac43602-pcie.txt failed'; then warn "NVRAM did not load this boot — Wi-Fi works on generic firmware only"
  else note "Wi-Fi NVRAM loaded"; fi
  say "Building the Touch Bar driver (DKMS)"
  local hdr=linux-headers kpkg
  if ! pacman -Qq linux >/dev/null 2>&1; then
    kpkg=$(pacman -Qoq "/usr/lib/modules/$(uname -r)/vmlinuz" 2>/dev/null); [ -n "$kpkg" ] && hdr="$kpkg-headers"
  fi
  # Omarchy pre-installs macbook12-spi-driver-dkms on 13,x: same apple-ibridge module name, no SOCW guard,
  # cannot build on current kernels. Keyboard/trackpad use mainline applespi. Remove it before headers arrive.
  if pacman -Qq macbook12-spi-driver-dkms >/dev/null 2>&1; then
    note "removing macbook12-spi-driver-dkms (conflicts with the T1 driver)"
    if [ "$MODE" != dry ]; then
      dkms status 2>/dev/null | awk -F'[,/ :]+' '/macbook12-spi-driver/{print $2}' | sort -u | while read -r v; do dkms remove -m macbook12-spi-driver -v "$v" --all || true; done
      pacman -R --noconfirm macbook12-spi-driver-dkms || die "could not remove macbook12-spi-driver-dkms"
    fi
  fi
  modinfo -n applespi >/dev/null 2>&1 || warn "mainline applespi not found — keyboard may depend on it"
  # A fresh offline install has no sync databases, and Omarchy blocks direct pacman upgrades.
  # Run Omarchy's own updater first (locally: it fails over SSH), then install from fresh databases.
  [ -s /var/lib/pacman/sync/core.db ] || die "run 'omarchy update' in a terminal on this Mac first (answer no to reboot), then run this script again"
  run env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -S --needed --noconfirm base-devel dkms "$hdr" || die "pacman failed — run 'omarchy update', then this script again"
  [ "$MODE" = dry ] || [ -d "/usr/lib/modules/$(uname -r)/build" ] || die "headers do not match the running kernel $(uname -r). Run: sudo pacman -Syu, full power cycle, then this script again."
  if [ ! -f "$DRV_SRC/dkms.conf" ]; then
    note "fetching the driver: $DRV_REPO @ $DRV_COMMIT"
    run env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -S --needed --noconfirm git
    if [ "$MODE" != dry ]; then
      rm -rf "$KIT/.t1-touchbar" && git clone -q "$DRV_REPO" "$KIT/.t1-touchbar" && git -C "$KIT/.t1-touchbar" checkout -q "$DRV_COMMIT" || die "could not fetch the driver"
    fi
    DRV_SRC=$KIT/.t1-touchbar/apple-ib-drv
  fi
  local src="/usr/src/$DKMS_NAME-$DKMS_VER" f
  run install -d "$src"
  for f in Makefile apple-ibridge.c apple-ibridge.h apple-touchbar.c hid-ids.h dkms.conf; do run cp "$DRV_SRC/$f" "$src/"; done
  if ! dkms status "$DKMS_NAME/$DKMS_VER" 2>/dev/null | grep -q installed; then
    run dkms add -m "$DKMS_NAME" -v "$DKMS_VER" || true
    run dkms build -m "$DKMS_NAME" -v "$DKMS_VER" || die "driver build failed — see /var/lib/dkms/$DKMS_NAME/$DKMS_VER/build/make.log"
    run dkms install -m "$DKMS_NAME" -v "$DKMS_VER" || die "dkms install failed"
  fi
  grep -q skip_acpi_power=1 /etc/modprobe.d/apple-touchbar.conf || die "freeze guard missing — refusing to enable the driver"
  if [ "$MODE" != dry ]; then
    modinfo -n apple_ibridge 2>/dev/null | grep -q updates/dkms || die "apple_ibridge resolves to a module that is not ours: $(modinfo -n apple_ibridge 2>/dev/null)"
    modinfo -p apple_ibridge 2>/dev/null | grep -q skip_acpi_power || die "apple_ibridge has no skip_acpi_power parameter — refusing to auto-load it"
  fi
  run install -m644 "$DRV_SRC/packaging/99-ibridge.rules" /etc/udev/rules.d/99-ibridge.rules
  run install -m644 "$DRV_SRC/packaging/apple-touchbar.modules-load.conf" /etc/modules-load.d/apple-touchbar.conf
  local mux_src=/usr/lib/udev/rules.d/39-usbmuxd.rules mux_dst=/etc/udev/rules.d/39-usbmuxd.rules tmp
  if [ -r "$mux_src" ] && grep -q '5ac/8600' "$mux_src"; then
    tmp=$(mktemp "${TMPDIR:-/tmp}/usbmuxd.XXXXXX")
    sed -e 's#|5ac/8600/\*##g' -e 's#5ac/8600/\*|##g' "$mux_src" > "$tmp"
    if grep -q '8600' "$tmp" || ! grep -q '5ac/12' "$tmp"; then rm -f "$tmp"; warn "unexpected usbmuxd rule format — not overriding; if the bar stays dark, see README"
    else run install -m644 "$tmp" "$mux_dst"; rm -f "$tmp"; note "usbmuxd no longer grabs the iBridge (iPhones unaffected)"; fi
  else note "usbmuxd rule does not match the iBridge — nothing to override"; fi
  run udevadm control --reload
  say "SSH (key only)"
  run pacman -S --needed --noconfirm openssh || die "could not install openssh"
  local u=${SUDO_USER:-} h; h=$(user_home)
  if [ -n "$u" ] && [ -f "$KIT/authorized_keys" ]; then
    run install -d -m700 -o "$u" -g "$u" "$h/.ssh"
    if [ "$MODE" != dry ]; then
      cat "$KIT/authorized_keys" >> "$h/.ssh/authorized_keys"
      sort -u -o "$h/.ssh/authorized_keys" "$h/.ssh/authorized_keys"
      chown "$u:$u" "$h/.ssh/authorized_keys"; chmod 600 "$h/.ssh/authorized_keys"
    fi
  fi
  if [ "$MODE" != dry ]; then
    install -d /etc/ssh/sshd_config.d
    printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' > /etc/ssh/sshd_config.d/10-key-only.conf
  fi
  run systemctl enable --now sshd
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Status: active'; then run ufw allow 22/tcp; fi
  note "this Mac: $(hostname)  $(ip -4 -o addr show "$(wifi_if)" 2>/dev/null | awk '{print $4}')"
  [ "$MODE" = dry ] || echo 2 > "$STATE"
  say "Stage 2 done. Now: SHUT DOWN, wait 20 s, power on. The Touch Bar should light at boot."
  note "Check afterwards with: sudo bash $0 --verify"
  note "If boot hangs: in the Limine menu edit the entry, add modprobe.blacklist=apple_ibridge,apple_touchbar"
}

case "$DONE" in
  0) stage1;;
  1) stage2;;
  *) say "All stages done."; verify;;
esac
