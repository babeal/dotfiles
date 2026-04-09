# 4. MacOS system package management via Homebrew

Date: 2026-04-04

## Status

Accepted

## Context

macOS machines need system CLI tools, GUI applications, Mac App Store apps, and third-party taps installed as part of dotfiles setup. macOS has no built-in general-purpose package manager, so one needs to be chosen.

[Homebrew](https://brew.sh/) is the de facto standard package manager for macOS. It covers CLI tools (formulae), GUI applications (casks), Mac App Store apps (via the `mas` integration), and custom repositories (taps). Alternatives like [MacPorts](https://www.macports.org/) or [Nix](https://nixos.org/) offer more reproducibility but come with significantly more operational overhead and a steeper learning curve. Given that the primary goal is a practical, maintainable personal setup rather than hermetic reproducibility, Homebrew is the right fit.

## Decision

Homebrew is the package manager for all macOS system packages and applications — formulae, casks, taps, and Mac App Store apps. This scope is limited to system-level software; dev tool runtime versions are managed by mise per ADR-0005.

## Consequences

Homebrew's coverage of macOS software is comprehensive and its tooling is well-maintained and widely documented. Using it for everything in the system layer means one mental model and one place to look when something isn't installed.

The main trade-off is that Homebrew is macOS-only, so Linux package management is handled separately (ADR-0003). Packages that exist in both ecosystems need to be listed in both places. There's also a soft dependency on Homebrew being bootstrapped before any managed package is available, which is handled in the dotfiles setup sequence.
