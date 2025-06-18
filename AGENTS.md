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
