# Omarchy on a 2016 15" MacBook Pro (MacBookPro13,3, T1) — Wi-Fi and Touch Bar

Two script runs after a normal Omarchy install bring back the **Touch Bar** and **5 GHz Wi-Fi** on the
T1 MacBook Pro. Verified on a **MacBookPro13,3** (15" 2016) with **Omarchy 4.5.0**, kernel
**7.2.15-1-omarchy**, whole-disk install, no macOS (2026-11-21).

| | Result |
| --- | --- |
| Touch Bar | lit at boot, survives power cycles (driver: [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar), DKMS) |
| Wi-Fi | NVRAM loaded, 5 GHz band, −56 dBm at the test spot |
| Keyboard / trackpad | mainline `applespi` |
| Speakers + mic | optional `install-audio.sh` (vendored davidjo/snd_hda_macbookpro), verified |
| Suspend (lid close) | optional `install-suspend-15inch.sh`, verified once (s2idle; wake needs a keypress) |
| Not covered | Touch ID, ambient light sensor |

> **Built on [nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1).**
> That repo is the original write-up for Omarchy on T1 MacBook Pros (verified on the 13" 2017,
> MacBookPro14,2): the ESP/T1-firmware rule, the BCM43602 NVRAM fix, audio, suspend, Limine boot entry
> and many traps this repo relies on. Read it first. This repo adds a tested, scripted path for the
> 15" 2016 (MacBookPro13,3) using a different Touch Bar driver (AJ-dev-i60, with a freeze guard).

Other T1 models (13,1/13,2/14,x) are likely similar but **untested here**.

## Self-contained

Everything needed is in this repository, pinned to exact upstream commits (`vendor/SOURCES.md`):
the Touch Bar driver, the BCM43602 NVRAM, t1-revive and the libimobiledevice sources it builds from.
`bash check-upstreams.sh` checks whether the originals are still online; if one disappears, the copy
here keeps working. Two things cannot be included: **your Mac's own T1 firmware backup** (per-chip,
private) and **Apple's `EmbeddedOSFirmware.pkg`** (Apple software; only needed to regenerate the
firmware; keep your own copy, sha256 in `vendor/APPLE_PKG`).

## Read this first: the T1 firmware lives on the disk

The T1 chip has no firmware of its own. At every power-on Apple's EFI loads
`EFI/APPLE/EMBEDDEDOS/{combined.memboot,FDRData,version.plist}` from the EFI system partition.
**A whole-disk install deletes them**, and the T1 stays in recovery mode (USB `05ac:1281`): Touch Bar,
camera and Touch ID go dark, and no driver can fix that.

**Before installing**, copy those three files off the machine, from macOS or from your current Linux
(e.g. `/boot/efi/EFI/APPLE/EMBEDDEDOS/`, wherever your ESP is mounted). They are **specific to
your Mac** (signed for your chip): never use another Mac's files, never publish yours.

No backup? Regenerate them from Apple's signing servers with `sudo bash rebuild-t1-firmware.sh`
(wraps the vendored [niconistal/t1-revive](https://github.com/niconistal/t1-revive); needs network and
Apple still signing this firmware; this wrapper is **not yet tested** on hardware, while t1-revive itself is tested on Omarchy upstream). t1-revive also has `backup --to PATH` for taking the backup.

## Prepare a USB stick

Copy this repository to a stick and add:

    t1-firmware/combined.memboot
    t1-firmware/FDRData
    t1-firmware/version.plist
    t1-firmware/SHA256SUMS        # cd t1-firmware && sha256sum combined.memboot FDRData version.plist > SHA256SUMS
    authorized_keys               # optional: your SSH public key, for enable-ssh.sh / stage 2


## Steps

1. Write the Omarchy ISO to a second stick. Boot holding **Option**, pick **EFI Boot**, install
   (whole disk is fine), keep encryption on. T1 Macs have no Secure Boot setting; skip that step.
2. Log in, plug in your stick, open a terminal in its folder:

       sudo bash omarchy-mac-fix.sh --dry-run     # optional
       sudo bash omarchy-mac-fix.sh               # stage 1, offline

   Restores the T1 firmware to `/boot/EFI/APPLE/EMBEDDEDOS` (checksum-verified), installs the Wi-Fi
   NVRAM, writes the Touch Bar freeze guard, adds `EFI/BOOT/BOOTX64.EFI` so Apple's boot picker lists
   Omarchy, maps Caps Lock to Escape.
3. **Full power cycle**: shut down, wait 20 s, power on. A reboot is not enough for the T1.
4. Connect Wi-Fi, then run **`omarchy update`** in a terminal on the Mac (a fresh install has no package
   databases, and Omarchy blocks direct pacman upgrades; it also fails over SSH). Decline the reboot.
5. Run the script again (stage 2):

       sudo bash omarchy-mac-fix.sh

   Removes Omarchy's `macbook12-spi-driver-dkms` (same `apple-ibridge` module name, no freeze guard,
   does not build on current kernels), installs `dkms`, builds and installs the Touch Bar driver,
   enables key-only SSH if `authorized_keys` is present.
6. Full power cycle again. The Touch Bar lights during boot. Check with:

       sudo bash omarchy-mac-fix.sh --verify

Want SSH earlier (to drive the rest remotely)? `sudo bash enable-ssh.sh`.

## Optional extras (verified on the 13,3)

- **Speakers and microphone:** `sudo bash install-audio.sh`, reboot. The CS8409 codec binds without it
  but the speakers stay silent. The microphone ships muted:
  `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0`.
- **Suspend on the 15-inch (13,3 / 14,3):** `sudo bash install-suspend-15inch.sh`, reboot. Without it,
  Omarchy's NVMe suspend fix lands on the Radeon (`01:00.0`; the NVMe is `02:00.0` on 15-inch models,
  omacom/omarchy#10826), `deep` sleep can resume to a black screen, and `s2idle` alone leaves USB-C dead.
  Recipe and full explanation: nohzafk/omarchy-macbookpro-t1 PR #5 (strawberry-code). Wake with a keypress;
  opening the lid alone does not finish resume.
- **Trackpad:** `extras/trackpad.lua`: macOS-style scrolling and lower-right-corner right-click.

## Good to know

- **Boot picker:** holding Option at power-on may not list Omarchy; a normal power-on boots it
  (stage 1 also adds `EFI/BOOT/BOOTX64.EFI` so the picker shows "EFI Boot").
- **Touch Bar keys:** with this driver the T1 firmware draws its own strip (Esc, brightness, media,
  volume; hold Fn for F1–F12).
- **Wi-Fi NVRAM:** the community file declares 10 TX-calibration channels but carries data for fewer;
  it is the same everywhere and works (measured in nohzafk PR #1). Not a cause of low link rates.
- **No firmware backup and no wish to rebuild it?** A keyboard-only setup (Fn+number row = F-keys,
  Caps+Tab = Esc) without the Touch Bar: omacom/omarchy discussion #13519.
- **Ambient light sensor / auto-brightness:** not in this driver; reported working with
  creolben/macbook-t1-touchbar (`apple-ib-als`) + wluma on a 14,3 (omacom/omarchy discussion #2457).
- **Other 15-inch 2017 notes:** Daniel-E-N's sleep write-up for the 14,3 (linked in discussion #2457).

## Safety

- `options apple_ibridge skip_acpi_power=1` must stay in `/etc/modprobe.d/apple-touchbar.conf`.
  Without it the driver runs ACPI `ASOC.SOCW(1)`, which **hard-freezes T1 machines**. Stage 2 refuses
  to enable a driver that lacks the parameter.
- Install one Touch Bar driver lineage only.
- **If boot hangs** after stage 2: power off, in the Limine menu press E on the entry, add
  `modprobe.blacklist=apple_ibridge,apple_touchbar` to the kernel line, boot, then
  `sudo rm /etc/modules-load.d/apple-touchbar.conf`.
- After a kernel update, `dkms status` should list `apple-ib-drv` for the new kernel.

## Wi-Fi notes

- BCM43602 firmware ships in `linux-firmware`; only the board NVRAM is missing. Without it the chip
  reports a `00:90:4c:…` placeholder MAC, 2.4 GHz only, weak signal.
- `no clm_blob available (err=-2)` is harmless. Do not add a fake clm_blob.
- The NVRAM `macaddr=` is set to `WIFI_MAC` if you pass it (`sudo WIFI_MAC=aa:bb:… bash …`), otherwise
  to the address the chip currently reports.
- Undo: `sudo rm /usr/lib/firmware/brcm/brcmfmac43602-pcie*.txt`, power cycle.

## Credits

- Touch Bar driver: [AJ-dev-i60/t1-touchbar](https://github.com/AJ-dev-i60/t1-touchbar) (GPL-2.0), with the `skip_acpi_power` guard.
- T1 firmware regeneration: [niconistal/t1-revive](https://github.com/niconistal/t1-revive).
- **[nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1)** — the groundwork for Omarchy on T1 Macs.
- libimobiledevice project (vendored sources for t1-revive).
- [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) (GPL-2.0), audio driver.
- strawberry-code (nohzafk PR #5) for the 15-inch suspend recipe.
- NVRAM: community BCM43602 file circulated via the kernel bugzilla (#193121) and Arch forums.

Scripts are MIT-licensed. Use at your own risk.
