# Vendored sources

Exact copies of upstream code, so this repository still works if an upstream disappears.
`check-upstreams.sh` reports whether each original is still online at the pinned commit.

| Path | Upstream | Commit | License |
| --- | --- | --- | --- |
| `apple-ib-drv/` | https://github.com/AJ-dev-i60/t1-touchbar (subdir `apple-ib-drv`) | 20d65c7b0fe6 | GPL-2.0 (`apple-ib-drv/LICENSE`; repo license in `LICENSE.t1-touchbar`) |
| `t1-revive/` | https://github.com/niconistal/t1-revive | 666fe8dca338 | MIT (`t1-revive/LICENSE`) |
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
