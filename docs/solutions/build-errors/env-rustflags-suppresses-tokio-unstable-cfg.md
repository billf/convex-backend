---
title: Shell-exported RUSTFLAGS suppressed the cargo-config tokio_unstable cfg and broke the disable_lifo_slot build
date: 2026-09-28
category: build-errors
module: crates/runtime
problem_type: build_error
component: tooling
symptoms:
  - cargo build fails with E0599 no method named disable_lifo_slot found for tokio runtime Builder at crates/runtime/src/prod.rs line 163
root_cause: config_error
resolution_type: environment_setup
severity: high
framework_version: tokio 1.53.1
tags: [rustflags, tokio-unstable, cargo-config, disable-lifo-slot, nix]
---

# Shell-exported RUSTFLAGS suppressed the cargo-config tokio_unstable cfg and broke the disable_lifo_slot build

## Problem

`cargo build` failed in `ProdRuntime::init_tokio()` because `tokio::runtime::Builder::disable_lifo_slot` was not visible as a method. The root cause was environmental: the shell's exported `RUSTFLAGS` suppressed the repo's cargo-config `rustflags`, so the `--cfg tokio_unstable` flag the method is gated behind never reached `rustc`. No repo change was needed then — but note the code has since changed: commit `ac6ce4d` `#[cfg(tokio_unstable)]`-gated the call, so at HEAD a suppressed cfg silently compiles the call out instead of producing E0599.

## Symptoms

`cargo build` failed with:

```text
error[E0599]: no method named `disable_lifo_slot` found for struct `tokio::runtime::Builder` in the current scope → `private field, not a method`
```

pointing at `crates/runtime/src/prod.rs:163`, inside `ProdRuntime::init_tokio()` (`crates/runtime/src/prod.rs:151-165`):

```rust
if *RUNTIME_DISABLE_LIFO_SLOT {
    #[cfg(tokio_unstable)] // added later by ac6ce4d; absent in the failing revision
    tokio_builder.disable_lifo_slot(); // crates/runtime/src/prod.rs:163
}
```

The "private field, not a method" note makes this look like a tokio version incompatibility (as if the installed tokio simply lacks the API), but per this session's verification the workspace tokio (`tokio = { version = "1.53.1", ... }` in `Cargo.toml:232`) was never the problem.

## What Didn't Work

The misleading trail was treating this as a tokio version or dependency issue: the error reads like `Builder` has no such method, so reinstalling, upgrading, or pinning tokio looks like the fix. That would not help, because the method exists in the pinned tokio — it is just hidden behind an unstable cfg. The failure reproduced with the nix-provided environment as-is, and required no dependency change to resolve.

## Solution

Environmental fix, no repo change. In this session, the shell had exported a nix-provided `RUSTFLAGS` (e.g. `RUSTFLAGS=-L/Users/bill/.nix-profile/lib/`). Appending the missing cfg restores the build:

Before (fails):

```sh
echo "$RUSTFLAGS"  # shows -L/Users/bill/.nix-profile/lib/ without --cfg tokio_unstable
cargo check -p runtime  # reproduces E0599 at crates/runtime/src/prod.rs:163 on the pre-ac6ce4d code
```

After (works):

```sh
export RUSTFLAGS="$RUSTFLAGS --cfg tokio_unstable"
cargo check -p runtime  # passes
```

Equivalently, unsetting the environment flags lets the repo config take effect again:

```sh
env -u RUSTFLAGS cargo check -p runtime  # passes
```

Per this session's verification, all three outcomes above were executed and observed: nix `RUSTFLAGS` as-is → E0599; `env -u RUSTFLAGS` → passes; `RUSTFLAGS="$RUSTFLAGS --cfg tokio_unstable"` → passes.

## Why This Works

The repo sets the required cfg globally in `.cargo/config.toml:36-37`:

```toml
[target.'cfg(all())']
rustflags = ["--cfg", "tokio_unstable"]
```

`Builder::disable_lifo_slot` only exists as a method under `--cfg tokio_unstable`; without that cfg, name resolution finds only tokio's private field of the same name, producing the misleading "private field, not a method" error at `crates/runtime/src/prod.rs:163`.

Per this session's verification, the exported `RUSTFLAGS` took the place of (rather than added to) the config-file `target` `rustflags`: unsetting `RUSTFLAGS` restored the build and appending `--cfg tokio_unstable` fixed it, so the nix-provided `-L...` flags had silently dropped the `--cfg tokio_unstable` flag. Appending `--cfg tokio_unstable` to the exported `RUSTFLAGS` (or unsetting `RUSTFLAGS` so the config's flags apply) restores the cfg, the method becomes visible, and the crate compiles against the same tokio 1.53.1 (`Cargo.toml:232`).

## Prevention

- Treat `no method named ... → private field, not a method` on `tokio::runtime::Builder` (e.g. `disable_lifo_slot`) as a missing `tokio_unstable` cfg first, not a version problem. Check whether the symbol is cfg-gated before touching dependencies.
- When repo cargo-config flags seem ignored, check for an overriding environment: `echo "$RUSTFLAGS"` (and `echo "$CARGO_ENCODED_RUSTFLAGS"`). If `RUSTFLAGS` is set, the config `target.*.rustflags` (such as `.cargo/config.toml:36-37`) is suppressed.
- Verify the cfg is actually reaching `rustc` after any shell/nix env change, e.g. `env -u RUSTFLAGS cargo check -p runtime` as a baseline, then re-introduce env flags with `--cfg tokio_unstable` appended.
- Record required cfgs that live only in `.cargo/config.toml` in shell/nix env setup notes, so future `RUSTFLAGS` exports append rather than replace them (e.g. `export RUSTFLAGS="$RUSTFLAGS --cfg tokio_unstable"`).

Scope note: JS turbo/`uv`/node-version failures seen in the same session are a separate, unsolved problem and are not covered here.

## Related Issues

- None — no related learnings exist yet and no matching GitHub issues were found.
