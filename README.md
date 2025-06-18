# make-rust-script-do-stuff

What:
  * This repo is for building rust scripts.

Why:
  * The reason this repo exists is to create cross-platform non-PowerShell, non-python, and non-bash scripts.

## Running Rust Scripts

Rust scripts can be executed with [`rust-script`](https://rust-script.org/). Install it once using Cargo:

```sh
cargo install rust-script
```

After installation you can run a script on **any platform** with:

```sh
rust-script your_script.rs
```

On Unix systems you may embed a shebang line so scripts run directly:

```rust
#!/usr/bin/env rust-script
```

On Windows you can associate the `.ers` extension with `rust-script` so scripts run just like any other executable. Run once:

```powershell
rust-script --install-file-association
```

Renaming `your_script.rs` to `your_script.ers` then lets you double-click it.

For maximum portability, keep the shebang line and use the `.ers` extension.
After associating the extension or marking the file executable, you can run the
script directly:

```bash
./your_script.ers
```

## Cross-platform Repository Setup

Below are recommended settings so your shebang'ed Rust scripts work everywhere.

### 1. `.gitattributes`

```gitattributes
# ─────────── EOL normalization ───────────
*               text=auto

# Force LF for code, including executable Rust scripts…
*.rs            text eol=lf
*.ers           text eol=lf
*.sh            text eol=lf
*.toml          text eol=lf
*.md            text eol=lf

# …but allow CRLF on Windows for PowerShell
*.ps1           text eol=crlf

# Binary files
*.png           binary
*.jpg           binary
*.exe           binary
*.dll           binary
```

> • Treat your renamed `.ers` files just like `.rs` so they always check out with LF.
> • `text=auto` covers Markdown, TOML, JSON, etc., but you can explicitly list `.sh`, `.toml`, or `.md` for extra certainty.

### 2. `.gitignore`

```gitignore
# Rust build artifacts
/target/
*.rs.bk
Cargo.lock

# OS cruft
.DS_Store
Thumbs.db
desktop.ini

# IDE / editor
.vscode/
.idea/

# Swap / temp
*~
*.swp
```

### 3. (Optional) `.editorconfig`

```editorconfig
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 4
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.ps1]
end_of_line = crlf
```

### 4. Mark your scripts executable

On Unix-like shells, once you’ve added your new script:

```bash
chmod +x my_script.rs    # or .ers
git add my_script.rs
git update-index --chmod=+x my_script.rs
git commit -m "Make my_script.rs executable"
```

Git will now track the "+x" bit so anyone cloning on Linux/macOS can just run:

```bash
./my_script.rs
```

and on Windows they can double-click `my_script.ers` (after running `rust-script --install-file-association` once).

### 5. Embed the shebang in every script

At the very top of each script file:

````rust
#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! …
//! ```
````

