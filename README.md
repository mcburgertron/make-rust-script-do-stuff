# make-rust-script-do-stuff

This repository hosts cross-platform scripts written in Rust and executed with [`rust-script`](https://rust-script.org/).

## Running scripts

Install `rust-script` using Cargo:

```sh
cargo install rust-script
```

Run any script by pointing `rust-script` at it:

```sh
rust-script your_script.ers
```

### Shebang and extension

Start each script with a shebang so it can run directly on Unix-like systems:

```rust
#!/usr/bin/env rust-script
```

Name scripts with the `.ers` extension and mark them executable. On Windows, run once:

```powershell
rust-script --install-file-association
```

Afterwards you can execute the script just like any other file:

```bash
./your_script.ers
```

Development resources live in [AGENTS.md](AGENTS.md).

## Avoiding common async pitfalls

When writing or modifying these scripts keep a few runtime considerations in mind:

* Do not hold locks (e.g. `RwLock` guards) across `.await` points. Clone the
  needed data first, release the lock and then perform async work.
* Prefer async file and network APIs from `tokio`/`reqwest` to avoid blocking the
  executor.
* If you spawn background tasks ensure they are awaited or detached properly so
  the program can shut down cleanly.


## boarder.ers

`boarder.ers` implements a tiny service that refreshes Atlassian Jira OAuth
tokens and serves the current access token at `GET /token`.

To obtain the initial authorization code, print the consent URL:

```bash
./boarder.ers --client-id <id> --client-secret <secret> --print-auth-url
```

Open the URL, authorize the app and pass the resulting code via
`--auth-code` when starting the server.

The app requires a Jira OAuth token with the following scopes:

```
offline_access
read:jira-user
manage:jira-configuration
manage:jira-project
manage:jira-webhook
write:jira-work
read:jira-work
```

## gci.ers

`gci.ers` lists files in a directory and prints them as JSON. You can limit recursion depth, filter with glob patterns or regex, and include hidden files.

```bash
./gci.ers --path . --filter '*.rs'
```

## irm.ers

`irm.ers` is a flexible HTTP client inspired by PowerShell's `Invoke-RestMethod`. It supports various methods, headers, authentication and saving the response to a file.

```bash
./irm.ers https://api.github.com/repos/rust-lang/rust -Verbose
```

## whisper_transcribe.ers

`whisper_transcribe.ers` sends an audio file to OpenAI Whisper for transcription. By default the audio is uploaded as-is; use `--speed` to alter playback speed via `ffmpeg` before sending.

```bash
./whisper_transcribe.ers --apikey <key> --path audio.wav
```

## subnet_ping_seekers.ers

`subnet_ping_seekers.ers` pings a range of addresses on a subnet and lists those that respond.

```bash
./subnet_ping_seekers.ers --subnet 192.168.1 --start 1 --end 20
```

## gh_pr_hydra.ers

`gh_pr_hydra.ers` offers several GitHub pull request utilities. You can merge PRs
by author, query mergeability, detect conflicting file changes, clean up merged
branches and mark draft PRs ready for review. Pass `--repo-path` to run the tool
against a different local repository without changing directories.

```bash
./gh_pr_hydra.ers merge-serial --author <username>
./gh_pr_hydra.ers ready-drafts --author <username>
./gh_pr_hydra.ers clean-merged --what-if
```

```powershell
Get-ChildItem -Directory -Depth 0 | ForEach-Object -Process {
    Write-Host -ForegroundColor Yellow "Divining merge for $_"
    rust-script .\make-rust-script-do-stuff\gh_pr_hydra.ers --repo-path $_.FullName merge-divination --author mcburgertron
}
```

`remove-branch-safe` deletes a branch only when all of the following hold:

* The branch is not the default branch.
* The branch is not marked as protected on GitHub.
* Its latest commit is an ancestor of the default branch, ensuring it was fully
  merged.


## ipmi_scan.ers

`ipmi_scan.ers` locates IPMI-enabled devices on a subnet. It pings each address and then probes port 623 for any UDP response before attempting a full IPMI handshake. The results are grouped by confidence.

```bash
./ipmi_scan.ers --subnet 192.168.1 --user root --password root
```

A typical run might produce output like:

```
IPMI devices found (confirmed by handshake):
  192.168.1.12
  192.168.1.20

Possible IPMI devices (responded to UDP/623):
  192.168.1.25
  192.168.1.42

Responsive hosts not matching IPMI (ICMP ping only):
  192.168.1.66
  192.168.1.77
```

## update_packages.ers

`update_packages.ers` updates system packages using the appropriate package manager for the current operating system. Linux hosts use `apt-get`, macOS relies on Homebrew, Windows uses `winget`, and Android (Termux) uses `pkg`.

```bash
./update_packages.ers
# show commands without executing them
./update_packages.ers --dry-run
```

## machine_details.ers

`machine_details.ers` prints information about the current machine. It combines
generic data from `sysinfo` with platform specific helpers. Use `--json` to
output structured data.

```bash
./machine_details.ers --json
```
