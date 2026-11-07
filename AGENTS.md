# PreviewAI — standing instructions

> Read this file in full before any work in this repo. It applies to every session and every
> agent, whatever its filename says. The build plan lives in `docs/BUILD_PLAN.md`.

## What this is

PreviewAI is a lightweight, native macOS menu-bar app. Select a document in Finder, press a
global shortcut of your choosing, and a small floating panel (Quick Look-style) streams an AI
summary of it. Users pick the model backend: Apple Intelligence (on-device), an Anthropic API
key, an OpenAI-compatible API key, a local model server (Ollama / LM Studio), or their existing
Claude / ChatGPT plan through the user's own installed `claude` / `codex` CLIs.

Priorities, in order: **fast** (panel appears instantly, text streams), **light** (menu-bar only,
no Dock icon, no background work while idle, zero third-party dependencies), **native** (AppKit +
SwiftUI, system materials, standard keyboard behavior).

## Stack

- Swift 6 (language mode 6, strict concurrency), Swift Package Manager, Xcode 26 toolchain.
- Minimum macOS 14. Apple Intelligence (FoundationModels) is used behind
  `#if canImport(FoundationModels)` + `@available(macOS 26, *)`.
- AppKit app lifecycle (`main.swift` + `AppDelegate`), SwiftUI for views hosted in AppKit windows.
- Tests: Swift Testing (`import Testing`) in `Tests/PreviewAICoreTests`.
- **No third-party dependencies.** Adding one is a stop condition.

## Layout

```
Package.swift
Makefile                      build / test / app / app-appstore / lint / verify / dist — the entry points
Resources/Info.plist          app bundle Info.plist (LSUIElement, Apple Events usage, NSServices, ATS)
Resources/*.entitlements      Developer ID (Apple Events) and future App Store (sandbox) entitlements
scripts/bundle.sh             assembles a .app from a built binary, ad-hoc signs (writes only in repo)
scripts/release.sh            Developer ID sign + notarize + staple (needs the owner's certificate)
scripts/check-zip.sh          proves a zip unpacks to a valid app with any unzip tool (used by dist/release)
Sources/PreviewAICore/        all logic that can be unit-tested (no AppKit windows)
  Document/                   DocumentLoader, DocumentContent, budgets/truncation
  Prompt/                     PromptBuilder, SummaryLength
  Providers/                  SummaryProvider protocol + one file per backend
  Net/                        SSEParser, HTTP helpers
  Settings/                   SettingsStore, KeyValueStore, SecretStore (Keychain)
  Session/                    SummarySession (state machine the panel renders), SummaryCache
  Hotkey/                     KeyCombo (pure model of a shortcut)
  EntryPoint.swift            filtering shared by every way a file reaches the app
Sources/PreviewAI/            the app: AppDelegate (menu + entry points), HotkeyManager (Carbon),
                              FinderSelection (Apple Events, direct build only), ServiceProvider
                              (Finder Service), MainMenu (hidden Edit menu), SummaryPanel/,
                              Settings/ (window, model, SwiftUI view)
Tests/PreviewAICoreTests/     unit tests; Fixtures/ for committed sample files and fake CLIs
docs/BUILD_PLAN.md            the plan and progress tracker (single source of truth for status)
docs/ARCHITECTURE.md          how the pieces fit (kept current)
docs/DISTRIBUTION.md          Developer ID signing/notarization and the App Store path
docs/PROVIDER_TERMS.md        what Anthropic/OpenAI allow for the CLI providers (re-check per release)
```

## Commands

- `make verify` — the gate. Builds debug, runs all tests, builds the release `.app` bundle, and
  lints the bundle's Info.plist. Must be green before any commit.
- `make app` — builds `build/PreviewAI.app`. `open build/PreviewAI.app` runs it (a human does this).
- `make dist` — zipped, ad-hoc-signed app in `dist/` (`*-adhoc.zip`, checked by `scripts/check-zip.sh`). Signed releases: `scripts/release.sh` (owner only).
- All SwiftPM invocations go through the Makefile, which pins SwiftPM's cache/config/security
  paths under `.build/` so builds write nothing outside the repo.

## Non-negotiable rules

1. **Never write or delete files outside this repository** — from code, tests, scripts, or
   commands. Tests use in-memory stores and `.build/test-scratch/` (see `TestSupport.swift`),
   never `$TMPDIR`, real `UserDefaults` suites, or the real Keychain.
2. **Tests never hit the network or run real AI CLIs.** HTTP is stubbed with a `URLProtocol`
   subclass; CLIs are replaced by fake scripts in `Tests/PreviewAICoreTests/Fixtures/bin/`.
3. **Never weaken verification** to get green — no skipped/deleted tests, loosened assertions,
   or swallowed errors.
4. **Secrets live only in the Keychain** (`SecretStore`), never in `UserDefaults`, logs, or files.
5. **Idle means idle.** No timers, polling, or background threads while no summary is running.
6. **Every change updates whatever docs went stale** — this file, `docs/ARCHITECTURE.md`,
   `README.md`, and the tracker in `docs/BUILD_PLAN.md` — in the same commit.
7. Match the surrounding code's style; comments are short and explain *why*.
8. **CLI providers follow `docs/PROVIDER_TERMS.md`.** Never read, store, prompt for, log, or pass
   CLI credentials (`~/.claude`, `~/.codex`, OAuth tokens); never bundle, download, or modify the
   CLIs or disable their sign-in methods; no in-app login, background/batch use, or rate-limit
   workarounds; descriptive labels only ("Claude Code CLI (your login)"), no implied affiliation.
   A paid or App Store build ships without them unless the vendors have approved it.

## Git and GitHub (project-specific override)

The owner's global default is "the agent never commits or pushes". **For this repo only, the
owner explicitly authorized (2026-11-06) autonomous work:** the agent may `git init`, branch,
commit, push, open PRs, and merge its own phase PRs, following the autopilot rules in
`docs/BUILD_PLAN.md` (one step = one green commit; one phase = one PR; merge only after
`make verify` and CI are green; never force-push; never rewrite pushed history).

- **No AI attribution anywhere** — no `Co-Authored-By:` trailers, no "Generated with…" lines, no
  mention of an assistant or model in commits, PR titles, or PR bodies.
- Remote: `https://github.com/memoliertorerr/previewAI` (public). Base branch `main`.
- Stop and ask the owner before anything destructive (deleting branches with unmerged work,
  resets, history rewrites), before publishing a GitHub Release, and whenever a step needs a
  credential, a permission prompt, or a product decision.

## What the agent cannot verify

Anything visual (panel look, Liquid Glass/vibrancy), the global hotkey actually firing, the
macOS Automation (Finder) permission prompt, Apple Intelligence output (it is disabled on the
dev machine), and real responses from Anthropic / OpenAI / local servers / CLIs. These are
listed under **Pending human checks** in `docs/BUILD_PLAN.md`.
