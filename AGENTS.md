# Development Resources

This repository is for building cross-platform Rust scripts. All scripts run with `rust-script` instead of Cargo.

## Script format

Every Rust script should:

1. Use the `.ers` extension.
2. Start with the shebang:

   ```rust
   #!/usr/bin/env rust-script
   ```

Mark new scripts executable so they can run directly on Unix-like systems:

```bash
chmod +x my_script.ers
git add my_script.ers
git update-index --chmod=+x my_script.ers
```

The repo already includes files like `.gitattributes` and `.gitignore` for cross-platform behavior.

## Testing scripts

Always run a script after editing it to ensure it still compiles and functions.
Use the script directly or via `rust-script`. A quick check is running the help
text:

```bash
./my_script.ers --help
```

For more involved changes, run the script with typical options to verify its
behaviour.

### Runtime tips

Async scripts should avoid common pitfalls that lead to deadlocks or needless
blocking:

* Never hold a `Mutex` or `RwLock` guard across an `.await`. Clone or copy the
  data you need first, then release the lock before calling async functions.
* Use the async versions of file and network APIs whenever possible.
* Be mindful of spawned tasks and clean them up when your program exits.

## Parsing URLs and text

Avoid ad-hoc string manipulation when dealing with URLs or other structured
text. Use the [`url`](https://docs.rs/url) crate to parse and validate URLs, and
consider libraries like [`regex`](https://docs.rs/regex) or `serde` for more
complex formats. Proper parsing prevents subtle bugs and makes the code easier
to maintain.

## Coding standards

All `.ers` files must match the house style demonstrated in **`gh_pr_hydra.ers`**.

1. **Lint gates** - add `#![warn(clippy::all, missing_docs, rust_2018_idioms)]` immediately after the shebang. You may run lints with "rust-script --package <ers>; cargo clippy --manifest-path <path>/Cargo.toml".
2. **Embedded manifest** - include a `//! \`\`\`cargo` header block pinning `[package]` and `[dependencies]`; use edition 2021.  
3. **Usage & caveats first** - document `bash,no_run` (and when relevant `powershell,no_run`) examples plus runtime prerequisites _before_ the manifest.  
4. **CLI via `clap` derive** - define `Cli` with `#[derive(Parser)]`; model subcommands with `#[derive(Subcommand)]`; reference `author, version, about`.  
5. **Error handling** - adopt `anyhow::Result` everywhere; attach context using `.with_context(...)`.  
6. **Process wrapper** - route every `std::process::Command` through a `run(&mut Command) -> anyhow::Result<Output>` helper for uniform diagnostics.  
7. **Environment guard** - validate external dependencies once (e.g. `ensure_ready()`) near the start of `main()`.  
8. **Internal module** - move implementation details into an `internal` module; expose helpers `pub(crate)` for testability while keeping the public API slim.  
9. **Unit tests** - embed a `#[cfg(test)]` module with at least one test covering a critical helper or failure path (see `run_reports_missing_binary`).  
10. **Doctests** - ensure header code-blocks compile under `rust-script test`; treat them as executable documentation.