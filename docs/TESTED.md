# Test log

## MacBookPro13,3 (15" 2016, Radeon Pro 450), Omarchy 4.5.0, kernel 7.2.15-1-omarchy — 2026-11-21

Whole-disk install, LUKS, no macOS. T1 firmware restored from a backup taken under Ubuntu.

| Item | Result |
| --- | --- |
| T1 after stage 1 + full power cycle | `05ac:1281` → `05ac:8600` (backup restored to `/boot/EFI/APPLE/EMBEDDEDOS`, checksums verified) |
| Stage 2, first try | failed: no pacman sync DBs on a fresh install; fixed by running `omarchy update` first |
| Touch Bar driver | apple-ib-drv 0.1 via DKMS; loaded at boot from modules-load.d, no hang; strip lit |
| Wi-Fi | NVRAM loaded (no `-2` for `.txt`), Band 2 present, 5220 MHz, −56 to −62 dBm |
| Audio | snd_hda_macbookpro (subsystem 0x106b3900); 440 Hz test tone heard on the speakers |
| Suspend | with install-suspend-15inch.sh: `PM: suspend entry (s2idle)` / `exit`, success=1 fail=0; screen back after keypress, unlock OK; 3 xHCI present, thunderbolt reloaded, Wi-Fi reconnected 5 GHz, T1 still `8600` |
| Trackpad extras | natural scroll + lower-right right-click active after `hyprctl reload` |

Not yet checked: Esc/F-key input from the Touch Bar, Touch Bar lit after resume, long sleeps,
driver rebuild after a kernel update, `rebuild-t1-firmware.sh` on hardware.
