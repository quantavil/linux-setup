# Tauri / WebKitGTK Lag Fix

Tauri apps (Tolaria, Mouzi, etc.) felt laggy on this machine — sluggish scrolling,
stuttery window drags. The cause was **not** the hardware.

Both binaries hardcode `WEBKIT_DISABLE_DMABUF_RENDERER=1`. That is Tauri
boilerplate copy-pasted as a workaround for broken NVIDIA proprietary drivers.
It makes WebKitGTK abandon the zero-copy DMA-BUF path and push every rendered
frame through shared-memory CPU blits instead.

This machine has an **Intel UHD (Comet Lake-U) iGPU on Mesa** where DMA-BUF works
correctly, so the workaround is pure cost. The apps only set the variable when it
is unset, so an external override wins.

---

## Diagnosis

Confirm the flag is active inside a running Tauri app:

```bash
# find a WebKit child process and read its environment
for p in $(pgrep -f WebKitWebProcess); do
    tr '\0' '\n' < /proc/$p/environ | grep DMABUF
done
```

`=1` means the slow path is in use. `=0` (or absent) means the GPU path is live.

Confirm the flag is baked into the binary:

```bash
strings -a /usr/bin/tolaria | grep WEBKIT_DISABLE
```

---

## What the scripts do

### `apply_tauri_webkit_lag.sh`
1. Writes `~/.config/environment.d/webkit.conf` with `WEBKIT_DISABLE_DMABUF_RENDERER=0`
2. Backs up `~/.config/kwinrc` to `~/.config/kwinrc.bak`
3. Disables the `wobblywindows` KWin effect (per-frame vertex simulation, expensive on an iGPU)
4. Sets `[Compositing] LatencyPolicy=Low` in `kwinrc` (~1 frame less input-to-photon at 60 Hz)
5. Reloads KWin live via D-Bus — no logout needed for the KWin changes

### `revert_tauri_webkit_lag.sh`
1. Removes `~/.config/environment.d/webkit.conf`
2. Restores `~/.config/kwinrc` from `~/.config/kwinrc.bak` if present, otherwise
   re-enables `wobblywindows` and deletes the `LatencyPolicy` key
3. Reloads KWin live

No `sudo` anywhere. Everything is user-level config.

---

## 🚀 Install

```bash
chmod +x apply_tauri_webkit_lag.sh
./apply_tauri_webkit_lag.sh
```

> **Log out and back in** for the env var to reach apps launched from Plasma.
> The KWin changes take effect immediately.

## 🗑️ Revert

```bash
chmod +x revert_tauri_webkit_lag.sh
./revert_tauri_webkit_lag.sh
```

---

## Result

Measured before/after on this machine (same session, ~45 min apart):

| | before | after |
|---|---|---|
| available RAM | 2.8 Gi | 5.4 Gi |
| zram swap used | 2.5 G | 270 M |

Scrolling and window drags became visibly smoother.

---

## Optional hardening

`strings /usr/bin/tolaria` also contains `WEBKIT_DISABLE_COMPOSITING_MODE`. That
flag is **worse** than the DMA-BUF one — it disables accelerated compositing
entirely, dropping all rendering to the CPU. It is currently unset at runtime,
but a future app update could start setting it. To make that impossible, add a
second line to the env file:

```
WEBKIT_DISABLE_COMPOSITING_MODE=0
```

Not applied by the script, since it is insurance rather than a speedup.

---

## Why not just use Chromium?

Short answer: not possible from the user side.

- Tauri routes rendering through **WRY**, which supports exactly one engine per
  platform — WebView2 on Windows, WKWebView on macOS, **WebKitGTK on Linux**.
  There is no backend switch.
- The binaries are linked at build time against `libwebkit2gtk-4.1.so.0` and
  `libgtk-3.so.0`. `webkitgtk-6.0` (GTK4) may be installed on the system, but it
  is a different SONAME and ABI, so the binaries cannot be pointed at it.
- The app frontends are welded to the Rust backend through Tauri IPC
  (`__TAURI__`, `__TAURI_CHANNEL__`, `__TAURI_INVOKE_KEY__`). Neither app serves
  HTTP (`ss -ltnp` shows no listening socket), so there is no URL a browser could
  even open, and a plain browser could not answer the IPC calls anyway.

Switching to Chromium would require the developers to rebuild on Electron, Wails,
or CEF. Note that Electron equivalents idle around 450–600 MB versus ~130 MB for
a Tauri app — on a 7.6 GB machine that trade can push you back into swap, which
feels worse than any renderer difference.

There is also nothing to *upgrade* to: `webkit2gtk-4.1 2.52.5-2` is already the
newest in the Arch `extra` repo.

---

## Notes

- Applies to any WebKitGTK app, not just Tauri ones.
- If lag returns after an app update, re-run the diagnosis above — the app may
  have switched to setting the variable unconditionally, which an external
  override cannot beat.
- Unrelated knobs that were checked and found **already correct** on this machine:
  Baloo (idle, fully indexed), thermals (43 °C, no throttling), btrfs
  `noatime`+`zstd:3`, `mq-deadline` on the SATA SSD, zero XWayland clients.
- Remaining untouched lever: intel_pstate energy preference is `balance_power`,
  which ramps clocks slowly. `balance_performance` improves burst responsiveness
  at some battery cost. Requires `sudo`.
