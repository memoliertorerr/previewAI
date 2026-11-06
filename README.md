# PreviewAI

Select a document in Finder, press a shortcut, get an AI summary — in a small, native,
Quick Look-style panel.

PreviewAI is a lightweight macOS menu-bar app (no Dock icon, no background work while idle,
zero third-party dependencies). Bring your own model:

- **Apple Intelligence** — on-device, free, private
- **Anthropic API key** (Claude)
- **OpenAI-compatible API key** (OpenAI or any compatible endpoint)
- **Local models** — Ollama, LM Studio
- **Claude / Codex subscriptions** — through the installed `claude` / `codex` CLIs

Supports PDF, Markdown, plain text, RTF, Word (.docx) and HTML.

> **Status:** under construction — Apple Intelligence works end to end; other providers are next. See [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md) for progress.

## Ways to summarize

- **Shortcut** — select a document in Finder and press **⌃⌥Space**. The first time, macOS asks
  whether PreviewAI may control Finder (that's how it learns which file is selected).
- **Finder Service** — right-click a document → Quick Actions / Services → **Summarize with
  PreviewAI**. You can give it its own shortcut in System Settings → Keyboard → Keyboard
  Shortcuts → Services → Files and Folders.
- **Open With** — right-click → Open With → PreviewAI, or drop a file on the app icon.
- **Summarize File…** from the menu-bar icon.

## Build from source

Requires macOS 14+ and Xcode 26+.

```bash
make app && open build/PreviewAI.app
```

## License

MIT
