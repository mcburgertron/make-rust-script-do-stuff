# Codex glibc helper patch/install (proot)

Use `codex_glibc_helper_patch_install.ers` to fetch the Codex aarch64 glibc helper, verify integrity (when a digest is available), confirm the expected `prctl(PR_SET_DUMPABLE, 0)` failure under proot, patch the `prctl@plt` stub to return success, and install the patched helper as `/usr/local/bin/codex.bin.real` with backup/rollback.

## Usage

```bash
# Dry run (no install); leaves patched helper in /tmp
./codex_glibc_helper_patch_install.ers --test

# Install a specific tag (requires write to /usr/local/bin)
sudo ./codex_glibc_helper_patch_install.ers --tag rust-v0.63.0
```

Flags:
- `--tag <tag>`: override the release tag; defaults to latest (e.g., `rust-v0.63.0`).
- `--test`: run everything in /tmp, skip install.
- `--allow-unsigned`: proceed when the GitHub release omits a digest (skips checksum verification).

## Expectations and flow
1. Download `codex-aarch64-unknown-linux-gnu.tar.gz` from the release.
2. Verify SHA256 if the release publishes a digest; otherwise require `--allow-unsigned`.
3. Run raw `--version`; expect failure containing `prctl(PR_SET_DUMPABLE, 0)`. Any other outcome aborts.
4. Locate `prctl@plt` via `objdump`, patch the PLT stub to `mov w0, wzr; ret; nop; nop`.
5. Run patched `--version`; abort if it fails.
6. If installing (non-`--test`):
   - Backup existing `/usr/local/bin/codex.bin.real` to `/usr/local/bin/codex.bin.bak-<timestamp>` if present.
   - Install patched helper to `/usr/local/bin/codex.bin.real` (mode 755).
   - Run `codex --version`; on failure, restore backup and abort; on success, print backup path.

## Requirements / caveats
- Platform: Linux aarch64.
- Tools: `objdump`, network access to GitHub releases.
- Permissions: install requires write access to `/usr/local/bin`; `--test` requires none.
- Uses `codex` on PATH only for final verification; the helper install itself does not require the wrapper.

## When to use
- Updating the local proot environment to the latest Codex CLI helper while keeping the prctl patch applied.
- Verifying a new upstream release before installing (`--test` first).

## Restore a backup
If a post-install `codex --version` or subsequent use fails, restore the previous helper:
```bash
sudo install -m 755 /usr/local/bin/codex.bin.bak-<timestamp> /usr/local/bin/codex.bin.real
```
Replace `<timestamp>` with the backup printed by the installer, e.g. `codex.bin.bak-20251124050714`.
