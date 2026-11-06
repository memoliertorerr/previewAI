# PreviewAI — architecture

PreviewAI is two SwiftPM targets: **PreviewAICore** (everything testable — documents, prompts,
providers, the session state machine, settings) and **PreviewAI** (the AppKit app — status
item, hotkey, Finder integration, panel, settings window). The app is thin: it turns user
actions into `SummarySession` calls and renders `SummarySession.state`.

## Flow

```
entry point                     (hotkey + Finder selection · Service · Open With · Summarize File…)
   │  file URL
   ▼
SummarySession.summarize(url:provider:length:)          @MainActor, @Observable
   │ 1. provider.availability()        → .failed(reason) if not ready
   │ 2. DocumentLoader.load(url)       → DocumentContent (text, kind, pages)
   │ 3. .budgeted(maxCharacters: provider.inputBudget)  → visible truncation note if cut
   │ 4. SummaryCache lookup            (path + mtime + size + provider + model + length)
   │ 5. PromptBuilder.request(...)     → SummaryRequest (system, user, maxOutputTokens)
   │ 6. provider.stream(request)       → AsyncThrowingStream<String> of text deltas
   │    (ProviderError.contextTooLong → one retry with a third of the text)
   ▼
state: idle → loading → streaming(text…) → finished(text) | failed(message)
   ▼
SummaryPanel (SwiftUI in a non-activating NSPanel) renders the state
```

## Entry points

All four paths call `AppDelegate.handle(files:)`, which filters with `EntryPoint.resolveFiles`.

| Path | Code | Variant | Notes |
|---|---|---|---|
| Global shortcut (default ⌥⇧Space) | `HotkeyManager` (Carbon `RegisterEventHotKey`) → `FinderSelection` | direct | Asks Finder for its selection via Apple Events, only when Finder is frontmost. First use triggers the macOS Automation prompt. In the APPSTORE build the shortcut shows a hint to use the Service. |
| Service "Summarize with PreviewAI" | `ServiceProvider` + `NSServices` in `Info.plist` | both | Finder → right-click → Services. Bindable to a shortcut in System Settings → Keyboard → Keyboard Shortcuts → Services. Limited to supported document types. |
| Open With / drop on app icon | `application(_:open:)` + `CFBundleDocumentTypes` (Viewer, Alternate rank) | both | |
| Summarize File… (⌘O in the menu) | `NSOpenPanel` | both | |

## Key types

| Type | File | Role |
|---|---|---|
| `DocumentLoader` / `DocumentContent` | `Core/Document/` | Extract text from PDF (PDFKit), Markdown/text, RTF/DOCX/HTML (`NSAttributedString`). HTML runs on the main actor (WebKit importer). |
| `SummaryLength`, `PromptBuilder` | `Core/Prompt/` | One provider-neutral prompt for every backend. |
| `SummaryProvider` | `Core/Providers/SummaryProvider.swift` | The contract: `availability()`, `inputBudget`, `stream(_:)`. Cancelling the consuming task must stop the provider's work (it is torn down via `onTermination`). |
| `ScriptedProvider` | `Core/Providers/` | Canned chunks (optional delay, failure, context limit); used by tests. |
| `SummarySession` | `Core/Session/` | One summary at a time; a generation counter discards results from superseded requests. |
| `KeyCombo` | `Core/Hotkey/` | Shortcut as data: Codable, display string (⌃⌥⇧⌘ order), Carbon modifier mask, validity. |
| `PanelContent`, `MarkdownBlock` | `Core/Session/` | What the panel shows for each state; Markdown split into blocks (SwiftUI `Text` only renders inline Markdown). |
| `SummaryPanelController`, `SummaryView`, `PanelModel` | `App/SummaryPanel/` | Borderless, non-activating floating `NSPanel` (Liquid Glass on macOS 26) hosting SwiftUI. Esc/×/shortcut close it; closing calls `session.close()` and releases the panel and its view, so idle memory returns to baseline. |
| `AppleIntelligenceProvider` | `Core/Providers/` | FoundationModels (`#if canImport`, macOS 26+). Budget derived from `contextSize`; snapshots → deltas via `DeltaTracker`. |
| `ProviderRegistry`, `UnavailableProvider` | `Core/Providers/` | Builds the selected provider; unconfigured ones explain themselves. |
| `SSEParser`, `HTTPClient` | `Core/Net/` | Incremental SSE parsing over raw bytes; ephemeral `URLSession` wrapper; `HTTPFailure` error-body parsing. |
| `AnthropicProvider` | `Core/Providers/` | `POST /v1/messages`, `anthropic-version: 2026-10-21`, streaming, `output_config.effort: low`, `fallbacks: "default"` for Opus/Sonnet; only `text_delta` text is shown; refusals and stream errors map to `ProviderError`. |
| `OpenAICompatibleProvider` | `Core/Providers/` | `POST {base}/chat/completions` streaming for OpenAI / Ollama / LM Studio / custom; Bearer key only when set; `listModels()` via `GET {base}/models`; local-server connection errors say "is it running?". |
| `ClaudeCodeProvider`, `CodexProvider`, `CLIRunner` | `Core/Providers/` (`#if !APPSTORE`) | Subscriptions via the installed CLIs. Binary discovery (override, then `~/.local/bin`, Homebrew, `/usr/local/bin`, npm/bun/volta). Child gets an extended PATH, cwd `/`, document on stdin; stdout parsed line by line (stream-json / `exec --json`); cancel terminates the child. |
| `SettingsStore` | `Core/Settings/` | `@Observable` settings persisted as JSON in a `KeyValueStore` (UserDefaults in the app, in-memory in tests). API keys only via `SecretStore` (Keychain), per provider / per OpenAI-compatible preset. |
| `SettingsWindowController`, `SettingsModel`, `SettingsView` | `App/Settings/` | Standard window (General / Providers / About) hosting SwiftUI; shortcut recorder (pauses the hotkey while recording; logic in Core `ShortcutRecorderModel`); per-provider forms; Test Connection via Core `ConnectionTester`. |
| `LaunchAtLogin`, `LoginItemService` | `Core/Settings/` | `SMAppService.mainApp` login item, kept in sync with the setting. |
| `SummaryCache` | `Core/Session/` | In-memory LRU (20). No disk. |

## Distribution

See `docs/DISTRIBUTION.md` — Developer ID signing + notarization (`scripts/release.sh`, hardened
runtime with the Apple Events entitlement) and the planned Mac App Store build.

## Build variants

`make verify` builds two app bundles from the same sources:

- `build/PreviewAI.app` — direct distribution, every feature.
- `build/appstore/PreviewAI.app` — compiled with `-DAPPSTORE`: no Apple Events (Finder
  selection) and no `Process`-spawning CLI providers, so the code stays sandbox-compatible.

Rule: any code using `NSAppleScript` or `Process` must be inside `#if !APPSTORE`.

## Safety rules in the providers

- API keys: Keychain only, cached in memory after the first read; a denied read is reported as
  such. OpenAI-compatible keys are per preset; base URLs are per preset; OpenAI's URL is fixed.
  Keys are attached only over HTTPS or to localhost.
- CLI children: `F_SETNOSIGPIPE` on stdin and SIGPIPE ignored app-wide; cancel sends SIGTERM then
  SIGKILL after 1.5 s; all children are killed when the app quits.

## Testing boundaries

Tests never touch the network, real AI CLIs, the real Keychain, real `UserDefaults` suites, or
`$TMPDIR`. Scratch files go under `.build/test-scratch/` via `TestSupport.scratch()`.
