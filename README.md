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
