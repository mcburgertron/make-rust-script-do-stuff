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
