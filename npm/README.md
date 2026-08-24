# reasonix-termux

Prebuilt `reasonix` CLI binary for **Termux (Android/aarch64)**.

[Reasonix](https://github.com/esengine/DeepSeek-Reasonix) is a cache-first DeepSeek-native coding agent for the terminal. The official `reasonix` npm package ships prebuilt binaries for `linux/darwin/win32 × x64/arm64` — but **not** for `android/arm64`. This package fills that gap so you can install Reasonix in Termux via `npm` instead of an `apt` source.

## Install

```bash
# In Termux (Android arm64)
pkg install nodejs        # if you don't have Node.js yet
npm install -g reasonix-termux

# Verify
reasonix --version
```

> Non-Termux users: this package sets `os: ["android"], cpu: ["arm64"]` in `package.json`, so `npm install` will refuse to install it on other platforms with `EBADPLATFORM`. That's intentional — the binary only runs on Android/arm64.

## How it differs from upstream `reasonix`

- Upstream `reasonix` (npm) → JS wrapper + platform-specific subpackages (`@reasonix/cli-{os}-{arch}`)
- This package → ships the **android/arm64 binary** directly, built with `GOOS=android GOARCH=arm64 CGO_ENABLED=0` (static ELF)
- Same upstream source, two small Termux-specific patches applied at build time:
  1. `TMPDIR` patched to `~/.reasonix/tmp/` (Termux's `/tmp` is read-only)
  2. `atto/clipboard` init bypassed (Android `seccomp` faccessat2 workaround)

## Build pipeline

- **Source**: [esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix)
- **Build pipeline**: [masgzy/reasonix-termux](https://github.com/masgzy/reasonix-termux) — auto-syncs upstream every 6 hours, rebuilds, and publishes to:
  - **npm** (this package)
  - **apt** (Termux `pkg install reasonix` via orphan `apt` branch)

## Alternative install (apt)

If you prefer apt over npm:

```bash
curl -fsSL https://raw.githubusercontent.com/masgzy/reasonix-termux/main/scripts/install.sh | bash
# or manually:
echo 'deb [trusted=yes] https://raw.githubusercontent.com/masgzy/reasonix-termux/apt stable main' \
  > $PREFIX/etc/apt/sources.list.d/reasonix.list
pkg update && pkg install reasonix
```

## License

- **Reasonix binary**: MIT — upstream license, see [esengine/DeepSeek-Reasonix](https://github.com/esengine/DeepSeek-Reasonix)
- **Build scripts** (in source repo, not in this npm tarball): GPL-3.0

## Issues

- Reasonix CLI bugs → upstream: <https://github.com/esengine/DeepSeek-Reasonix/issues>
- Termux packaging / npm package issues → <https://github.com/masgzy/reasonix-termux/issues>

## Provenance

This package is published with npm [provenance](https://docs.npmjs.com/generating-provenance-statements) attestation via GitHub Actions. You can verify the binary was built from a specific commit on the official pipeline.
