# 5. Dev tool version management via Mise

Date: 2026-04-04

## Status

Accepted

## Context

Language runtimes like python, node, and go need per-project version isolation — different projects pin different versions, and a system-wide install causes conflicts. Previously this was handled with [asdf](https://asdf-vm.com/), a multi-runtime version manager with a plugin ecosystem.

[mise](https://mise.jdx.dev/) (formerly rtx) has emerged as a compatible and significantly improved alternative. It reads the same `.tool-versions` files as asdf, supports the asdf plugin ecosystem, and adds a native `.mise.toml` format with more flexibility. Performance is noticeably better, and the CLI UX is cleaner.

## Decision

We use mise to manage all language runtimes and dev tools that require per-project version isolation. The scope boundary follows the rule from ADR-0002: if a tool needs to be version-pinned per project, it belongs in mise. If it's a universal CLI tool used the same way everywhere (e.g. `shellcheck`, `shfmt`, `gh`), it belongs in the platform package manager (brew or apt) even if it's developer-oriented.

mise replaces asdf entirely — we don't support both in parallel.

## Consequences

mise is fast, asdf-compatible, and handles the non-interactive shell case well via `mise activate --shims`. Migration from asdf is low-friction since `.tool-versions` files work without modification.

The main operational consideration is bootstrapping order: mise needs to be installed before any managed runtime is available, and it needs to be activated in the shell before per-project overrides take effect. This is handled in the shell configuration, but it means there's a brief window during initial machine setup where runtimes aren't available.

Universal CLI tools intentionally excluded from mise (e.g. `shellcheck`, `shfmt`) are installed via brew/apt so they're available unconditionally, regardless of shell activation state.
