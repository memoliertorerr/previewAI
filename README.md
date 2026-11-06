# PreviewAI

**Select a document in Finder, press a shortcut, get an AI summary** — in a small, native,
Quick Look-style panel.

PreviewAI is a lightweight macOS menu-bar app: no Dock icon, no background work while idle, zero
third-party dependencies, about 1.6 MB. Bring your own model:

| Provider | What you need | Where documents go |
|---|---|---|
| **Apple Intelligence** | macOS 26 with Apple Intelligence turned on | Stays on your Mac |
| **Claude (Anthropic API)** | An API key from console.anthropic.com | Anthropic |
| **OpenAI-compatible** | An OpenAI key — or any compatible server (OpenRouter, Groq, …) | That service |
| **Ollama / LM Studio** | The app running locally with a model pulled | Stays on your Mac |
| **Claude subscription** | Claude Code (`claude`) installed and logged in | Anthropic |
| **Codex subscription** | Codex (`codex`) installed and logged in | OpenAI |

Reads PDF, Markdown, plain text (including source code), RTF/RTFD, Word (.docx) and HTML.

> **Status:** v0.1, under active development. Progress and design notes:
> [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md).

## Install

1. Download `PreviewAI-<version>.zip` (or build it — see below), unzip, and move
   **PreviewAI.app** to `/Applications` (running it from Downloads can break "Open at login").
2. Builds that aren't notarized are blocked the first time. On macOS 15 and later: try to open
   it, then go to System Settings → Privacy & Security and click **Open Anyway**. (On macOS 14,
   right-click the app → **Open**.) Notarized releases open normally.
3. PreviewAI appears as an icon in the menu bar. Open **Settings…** from it to pick a provider.

## Ways to summarize

- **Shortcut** — select a document in Finder and press **⌥⇧Space** (change it in Settings →
  General). The first time, macOS asks whether PreviewAI may control Finder — that's how it
  learns which file is selected. Press the shortcut again to close the panel, or select another
  file and press it to switch.
- **Finder Service** — right-click a document → **Services → Summarize with PreviewAI**. You can
  give it its own shortcut in System Settings → Keyboard → Keyboard Shortcuts → Services → Files
  and Folders.
- **Open With** — right-click → Open With → PreviewAI, or drop a file on the app icon.
- **Summarize File…** from the menu-bar icon.

In the panel: **Brief / Standard / Detailed**, **⌘R** regenerate, **⇧⌘C** copy the summary,
**⌘C** copy selected text, **Esc** close.

## Providers

Settings → Providers → choose one, fill in its fields, and click **Test Connection**.

- **Apple Intelligence** — free and private; the on-device model reads roughly the first 7 500
  characters of long documents (the panel says when it summarized only part).
- **Claude** — `claude-opus-5-5` by default; `claude-sonnet-5-5` and `claude-haiku-5-5` are faster
  and cheaper.
- **OpenAI-compatible** — choose OpenAI, Ollama, LM Studio or Custom; **Refresh** lists the
  server's models. Keys are stored per service and are only sent over HTTPS (or to this Mac).
- **Claude / Codex subscriptions** — PreviewAI runs the installed CLI in a locked-down mode (no
  tools, no saved session, read-only). Log in once by running `claude` or `codex` in Terminal.

API keys are stored only in your macOS Keychain.

## Privacy

PreviewAI sends a document's text to the provider you chose, and nowhere else. With Apple
Intelligence or a local server, nothing leaves your Mac. There is no analytics or telemetry.

## Build from source

Requires macOS 14+ and Xcode 26+.

```bash
make verify                              # build, test, bundle both variants, lint
make app && open build/PreviewAI.app     # run it
make dist                                # dist/PreviewAI-<version>.zip (ad-hoc signed)
```

Signing, notarization and the Mac App Store variant: [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).
How it works: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Roadmap

Long-document mode (chunked summaries), follow-up questions, OCR for scanned PDFs, and a Mac App
Store build — see **Later** in the build plan.

## License

MIT
