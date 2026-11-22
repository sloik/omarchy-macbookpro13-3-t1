# Vendored sources

Exact copies of upstream code, so this repository still works if an upstream disappears.
`check-upstreams.sh` reports whether each original is still online at the pinned commit.

| Path | Upstream | Commit | License |
| --- | --- | --- | --- |
| `apple-ib-drv/` | https://github.com/AJ-dev-i60/t1-touchbar (subdir `apple-ib-drv`) | 20d65c7b0fe6 | GPL-2.0 (`apple-ib-drv/LICENSE`; repo license in `LICENSE.t1-touchbar`) |
| `t1-revive/` | https://github.com/niconistal/t1-revive | 666fe8dca338 | MIT (`t1-revive/LICENSE`) |
| `snd_hda_macbookpro/` | https://github.com/davidjo/snd_hda_macbookpro | 1931615d7238 | GPL-2.0 (`snd_hda_macbookpro/LICENSE`); `tests/` WAV files (30 MB) omitted. Its build downloads the matching kernel source from kernel.org. |
| `t1-revive-deps/libplist-32428abacb90.tar.gz` | https://github.com/libimobiledevice/libplist | 32428abacb90 | LGPL-2.1-or-later |
| `t1-revive-deps/libimobiledevice-glue-da770a7687f3.tar.gz` | https://github.com/libimobiledevice/libimobiledevice-glue | da770a7687f3 | LGPL-2.1-or-later |
| `t1-revive-deps/libtatsu-60a39f36d719.tar.gz` | https://github.com/libimobiledevice/libtatsu | 60a39f36d719 | LGPL-2.1-or-later |
| `t1-revive-deps/libirecovery-95dec3aa25b1.tar.gz` | https://github.com/libimobiledevice/libirecovery | 95dec3aa25b1 | LGPL-2.1-only |
| `t1-revive-deps/libusbmuxd-93eb168bf6b0.tar.gz` | https://github.com/libimobiledevice/libusbmuxd | 93eb168bf6b0 | LGPL-2.1-or-later |
| `t1-revive-deps/libimobiledevice-fa0f79190142.tar.gz` | https://github.com/libimobiledevice/libimobiledevice | fa0f79190142 | LGPL-2.1-or-later AND GPL-2.0-or-later |
| `t1-revive-deps/usbmuxd-3ded00c9985a.tar.gz` | https://github.com/libimobiledevice/usbmuxd | 3ded00c9985a | GPL-2.0-only OR GPL-3.0-only |
| `t1-revive-deps/idevicerestore-540c352c4c44.tar.gz` | https://github.com/libimobiledevice/idevicerestore | 540c352c4c44 | LGPL-2.1-or-later AND LGPL-3.0-or-later |

The `t1-revive-deps` tarballs are `git archive` of the pinned base commits listed in
`t1-revive/vendor/refs.env`; t1-revive's own patches (`t1-revive/vendor/patches/`) are applied at build time
(`build.sh --offline`). Unmodified copies; licenses travel inside each tarball.

**Not vendored:** Apple's `EmbeddedOSFirmware.pkg` (Apple software, not redistributable; URL and checksum in
`APPLE_PKG` — keep your own copy), and each Mac's T1 firmware files (per-chip, private).

### Why `EmbeddedOSFirmware.pkg` is not in this repository

- **License.** Everything vendored above is MIT, GPL or LGPL, and those licenses explicitly allow copying.
  Apple's package is proprietary software with no redistribution grant. That Apple serves it free from its
  CDN does not make re-hosting it allowed. Committing it to a public repository would mean redistributing
  it, and a takedown could disable the whole repository, not just that file.
- **Limited value as a fallback.** Regenerating T1 firmware still needs Apple's TSS server to sign the
  firmware for your particular chip, so it needs the network either way. If Apple withdraws the package,
  it may well stop signing that version too.
- **What covers the risk instead.** `APPLE_PKG` pins the URL and sha256, so any copy can be verified as
  the original. `check-upstreams.sh` checks weekly that it is still online. Keep a private copy (personal
  storage or a private repo) and pass it with `T1_PKG=/path/EmbeddedOSFirmware.pkg` to
  `rebuild-t1-firmware.sh` or with `--firmware FILE` to `t1-revive`.

## Upstream status

Updated weekly by the `upstreams` GitHub Actions workflow.

<!-- status:start -->
Last checked: 2026-11-21 (UTC) by check-upstreams.sh.

| Source | Upstream | Pinned | Status |
| --- | --- | --- | --- |
| t1-touchbar | https://github.com/AJ-dev-i60/t1-touchbar | `20d65c7b0fe6` | ✅ online |
| t1-revive | https://github.com/niconistal/t1-revive | `666fe8dca338` | ✅ online |
| libplist | https://github.com/libimobiledevice/libplist | `32428abacb90` | ✅ online |
| libimobiledevice-glue | https://github.com/libimobiledevice/libimobiledevice-glue | `da770a7687f3` | ✅ online |
| libtatsu | https://github.com/libimobiledevice/libtatsu | `60a39f36d719` | ✅ online |
| libirecovery | https://github.com/libimobiledevice/libirecovery | `95dec3aa25b1` | ✅ online |
| libusbmuxd | https://github.com/libimobiledevice/libusbmuxd | `93eb168bf6b0` | ✅ online |
| libimobiledevice | https://github.com/libimobiledevice/libimobiledevice | `fa0f79190142` | ✅ online |
| usbmuxd | https://github.com/libimobiledevice/usbmuxd | `3ded00c9985a` | ✅ online |
| idevicerestore | https://github.com/libimobiledevice/idevicerestore | `540c352c4c44` | ✅ online |
| EmbeddedOSFirmware.pkg | Apple CDN | `sha256 0c97ab74` | ✅ online |
<!-- status:end -->
