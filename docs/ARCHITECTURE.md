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
   ▼
state: idle → loading → streaming(text…) → finished(text) | failed(message)
   ▼
SummaryPanel (SwiftUI in a non-activating NSPanel) renders the state
```

## Entry points

All four paths call `AppDelegate.handle(files:)`, which filters with `EntryPoint.resolveFiles`.

| Path | Code | Variant | Notes |
|---|---|---|---|
| Global shortcut (default ⌃⌥Space) | `HotkeyManager` (Carbon `RegisterEventHotKey`) → `FinderSelection` | direct | Asks Finder for its selection via Apple Events, only when Finder is frontmost. First use triggers the macOS Automation prompt. In the APPSTORE build the shortcut shows a hint to use the Service. |
| Service "Summarize with PreviewAI" | `ServiceProvider` + `NSServices` in `Info.plist` | both | Finder → right-click → Quick Actions/Services. Bindable to a shortcut in System Settings → Keyboard → Keyboard Shortcuts → Services. Limited to supported document types. |
| Open With / drop on app icon | `application(_:open:)` + `CFBundleDocumentTypes` (Viewer, Alternate rank) | both | |
| Summarize File… (⌘O in the menu) | `NSOpenPanel` | both | |

## Key types

| Type | File | Role |
|---|---|---|
| `DocumentLoader` / `DocumentContent` | `Core/Document/` | Extract text from PDF (PDFKit), Markdown/text, RTF/DOCX/HTML (`NSAttributedString`). HTML runs on the main actor (WebKit importer). |
| `SummaryLength`, `PromptBuilder` | `Core/Prompt/` | One provider-neutral prompt for every backend. |
| `SummaryProvider` | `Core/Providers/SummaryProvider.swift` | The contract: `availability()`, `inputBudget`, `stream(_:)`. Cancelling the consuming task must stop the provider's work (it is torn down via `onTermination`). |
| `ScriptedProvider` | `Core/Providers/` | Canned chunks; used by tests and the debug demo. |
| `SummarySession` | `Core/Session/` | One summary at a time; a generation counter discards results from superseded requests. |
| `KeyCombo` | `Core/Hotkey/` | Shortcut as data: Codable, display string (⌃⌥⇧⌘ order), Carbon modifier mask, validity. |
| `PanelContent`, `MarkdownBlock` | `Core/Session/` | What the panel shows for each state; Markdown split into blocks (SwiftUI `Text` only renders inline Markdown). |
| `SummaryPanelController`, `SummaryView`, `PanelModel` | `App/SummaryPanel/` | Borderless, non-activating floating `NSPanel` (Liquid Glass on macOS 26) hosting SwiftUI. Esc/×/shortcut close it; closing calls `session.close()`. |
| `AppleIntelligenceProvider` | `Core/Providers/` | FoundationModels (`#if canImport`, macOS 26+). Budget derived from `contextSize`; snapshots → deltas via `DeltaTracker`. |
| `ProviderRegistry`, `UnavailableProvider` | `Core/Providers/` | Builds the selected provider; unconfigured ones explain themselves. |
| `SummaryCache` | `Core/Session/` | In-memory LRU (20). No disk. |

## Build variants

`make verify` builds two app bundles from the same sources:

- `build/PreviewAI.app` — direct distribution, every feature.
- `build/appstore/PreviewAI.app` — compiled with `-DAPPSTORE`: no Apple Events (Finder
  selection) and no `Process`-spawning CLI providers, so the code stays sandbox-compatible.

Rule: any code using `NSAppleScript` or `Process` must be inside `#if !APPSTORE`.

## Testing boundaries

Tests never touch the network, real AI CLIs, the real Keychain, real `UserDefaults` suites, or
`$TMPDIR`. Scratch files go under `.build/test-scratch/` via `TestSupport.scratch()`.
