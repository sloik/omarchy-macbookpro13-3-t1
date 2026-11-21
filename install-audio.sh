#!/usr/bin/env bash
# install-audio.sh — speakers + mic on T1 MacBook Pros (Cirrus CS8409) via the vendored
# davidjo/snd_hda_macbookpro DKMS driver. Verified on MacBookPro13,3 (subsystem 0x106b3900),
# Omarchy 4.5.0, kernel 7.2.15. The build downloads the matching kernel source (~150 MB) from
# kernel.org, so it needs network. Run:  sudo bash install-audio.sh   then reboot.
set -euo pipefail
KIT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd -P)
[ "$(id -u)" -eq 0 ] || { echo "run with: sudo bash $0"; exit 1; }
[ -s /var/lib/pacman/sync/core.db ] || { echo "run 'omarchy update' first"; exit 1; }
hdr=linux-headers
pacman -Qq linux >/dev/null 2>&1 || hdr="$(pacman -Qoq "/usr/lib/modules/$(uname -r)/vmlinuz")-headers"
env OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -S --needed --noconfirm base-devel dkms wget patch "$hdr"
work=$(mktemp -d "${TMPDIR:-/tmp}/snd_hda_macbookpro.XXXXXX")
cp -R "$KIT/vendor/snd_hda_macbookpro/." "$work/"
chmod +x "$work"/*.sh
cd "$work"
./install.cirrus.driver.sh -i
echo
echo "Installed. Reboot, then unmute the microphone (it ships muted):"
echo "  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 && wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 100%"
