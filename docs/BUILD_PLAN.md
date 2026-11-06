# PreviewAI — v0.1 build plan

> PreviewAI is a native macOS menu-bar app: select a document in Finder, press a shortcut, and
> a Quick Look-style floating panel streams an AI summary. Users choose the backend — Apple
> Intelligence, Anthropic API key, OpenAI-compatible API key, local server (Ollama / LM Studio),
> or their Claude / Codex subscription through the installed CLIs.
>
> **In scope for v0.1:** menu-bar app; configurable global hotkey that summarizes the Finder
> selection; a Finder Service ("Summarize with PreviewAI") bindable to a shortcut in System
> Settings; Open With / drag-onto-icon / "Summarize File…"; PDF, Markdown, plain text, RTF,
> DOCX, HTML; six providers; Keychain-stored keys; settings window; streaming panel with copy /
> regenerate / length; an `APPSTORE` build variant that compiles out the non-sandboxable parts;
> `make dist` producing a zipped, ad-hoc-signed `.app`.
>
> **Explicitly NOT in scope** (designed, deferred — see **Later**): Developer ID signing and
> notarization, the Mac App Store target, chat/follow-up questions, map-reduce summaries of
> very long documents, OCR of scanned PDFs, images, history, auto-update.
>
> **Distribution decision (owner, 2026-11-06):** ship direct-download first with every feature;
> keep the code App Store-ready — Apple Events (Finder selection) and CLI providers live behind
> the `APPSTORE` compilation condition and `make verify` builds both variants.
>
> **Autopilot:** one step = one commit, made by the agent only when `make verify` is green. One
> phase = one pull request. The owner authorized the agent to merge its own phase PRs once
> `make verify` and CI are green. Steps gated `check` owe a human check that the agent cannot do;
> the agent records it under **Pending human checks** and keeps going. The agent stops at any
> stop condition.

---

## Progress Tracker

> Each session flips its own row to ✅ in the same commit as the step's change. Read this table
> at the start of a session to know where to resume.

| Step | Scope | Model | Gate | Status |
|------|-------|-------|------|--------|
| PA1 | SwiftPM scaffold, menu-bar shell, Makefile, bundle script, CI | strong | auto | ✅ done |
| PA2 | Document loading + per-provider text budgets | strong | auto | ✅ done |
| PA3 | Provider contract, prompt builder, SummarySession, cache | strong | auto | ⬜ todo |
| PA4 | KeyCombo + Carbon hotkey + entry points (Finder selection, Service, Open With) + `APPSTORE` flag | strong | check | ⬜ todo |
| PA5 | Floating summary panel (SwiftUI in NSPanel) | strong | check | ⬜ todo |
| PA6 | Apple Intelligence provider + end-to-end wiring | strong | check | ⬜ todo |
| PA7 | SettingsStore + Keychain SecretStore + provider configuration | standard | auto | ⬜ todo |
| PA8 | SSE parser + Anthropic provider | standard | auto | ⬜ todo |
| PA9 | OpenAI-compatible provider (OpenAI, Ollama, LM Studio, custom) | standard | auto | ⬜ todo |
| PA10 | CLI providers: Claude Code (`claude -p`) and Codex (`codex exec`) | standard | auto | ⬜ todo |
| PA11 | Settings window + shortcut recorder + Test connection | strong | check | ⬜ todo |
| PA12 | Polish: launch at login, error UX, idle memory, About | standard | auto | ⬜ todo |
| PA13 | Docs, `make dist`, distribution guide | standard | check | ⬜ todo |

**Overall status:** not started. Sequence: foundation → first runnable (hotkey → panel → Apple
Intelligence) → remaining providers → settings + ship.

**Model note:** Phases 1, 2 and 4's settings step use the stronger model — they fix the
contracts (provider protocol, session state machine) and the AppKit/Swift 6 concurrency
boundaries everything else inherits. Provider steps (phase 3) are well-specified and
test-pinned; a standard model is fine.

**Phases** — one pull request each:
1. **PA1 → PA3** · strong — Foundation. Reviewer focus: the `SummaryProvider` / `SummarySession`
   shapes, and that nothing writes outside the repo.
2. **PA4 → PA6** · strong — First runnable. Reviewer focus: hotkey + Finder flow, panel feel.
3. **PA7 → PA10** · standard — Providers. Reviewer focus: request shapes, secret handling.
4. **PA11 → PA13** · strong — Settings and ship. Reviewer focus: settings UX, docs accuracy.

Never start a phase with uncommitted changes in the tree.

---

## How To Run This

1. Open a **new session** in `/Users/memoli/Storage/CS/previewAI` on the model the next phase
   names. `AGENTS.md` is the standing-instructions file.
2. **Paste the Opening prompt.** It reports which phase is next and waits.
3. **Paste the Phase prompt** with that phase's step range, and say go.
4. The session runs each step: does the work, runs `make verify`, ticks its tracker row, and
   commits — one commit per step, only when green. `check` steps add their human check to
   **Pending human checks** and the session continues.
5. At the end of the phase it pushes, opens the PR, waits for CI, merges when green, and stops.

### Opening prompt — every session

```text
You are building PreviewAI, a lightweight native macOS menu-bar app that summarizes the
selected Finder document with a user-chosen AI backend, in /Users/memoli/Storage/CS/previewAI.
Before any work:
1. Read AGENTS.md and docs/BUILD_PLAN.md in this repo, in full.
2. Run `git status`, `git branch --show-current`, and `git log -1 --oneline`. Confirm the tree
   is clean. If you are on main, create the next phase branch per "0. Before Starting".
3. Run `gh auth status` and `xcodebuild -version` (Xcode 26+ required).
4. Restate, in one line each, the rules you will not break this session:
   (a) you commit only when `make verify` is green, one commit per step, never on main;
   (b) you never force-push, rewrite pushed history, or add AI attribution; you merge your
       phase PR only after `make verify` and CI are green;
   (c) you stop at every stop condition in Ground Rules — list them;
   (d) nothing you run writes or deletes files outside this repository.
5. Read the Progress Tracker and tell me which phase is next and which steps it covers.
Then wait for me to say go.
```

### Phase prompt

```text
Execute steps PA<a> → PA<b> from docs/BUILD_PLAN.md, in order.

For each step:
1. Read the step's prompt in the plan and follow it exactly. Do not start work the prompt
   doesn't ask for; record anything out of scope under "Deferred follow-ups".
2. Run `make verify`. If green: flip its tracker row to ✅, add implementation notes under the
   step if anything differed from the prompt, and commit everything as one commit with the
   step's commit message.
3. Paste a short report: the verify tail and `git log -1 --stat`.
4. If the step's gate is `check`, copy its Human check line into "Pending human checks" (in
   the same commit) and continue.

Stop immediately at any stop condition in Ground Rules and say which one.
After the last step of the range: push the branch, open the PR with the PR description
template, wait for CI, and merge with `gh pr merge --merge --delete-branch` once CI is green.
Then `git switch main && git pull --ff-only` and stop.
```

### PR description template

```markdown
## PreviewAI — phase <n>: <phase name>

Steps: PA<a> → PA<b> (plan: docs/BUILD_PLAN.md)

| Step | Commit | Verify evidence |
|---|---|---|
| PA<a> | <short sha> <message> | `make verify` → <N tests passed, both variants built> |

### Implementation notes
- <what differed from the prompts, and why>

### Added to Deferred follow-ups
- <item, or "none">

### Needs human check
- [ ] <copied from the step's Human check line — or "nothing beyond the diff">
- [ ] Nothing regressed: <the specific earlier features to re-check>
```

### Who verifies what

| Check | Who | "Green" looks like |
|---|---|---|
| `make verify` | Agent | Debug build, all tests, release `.app` for both variants, `plutil -lint` — clean exit |
| Unit tests | Agent | Pass; prove document extraction, prompt shape, request bodies, stream parsing, session states |
| CI on the PR | CI (GitHub Actions, macOS runner) | `make verify` green |
| Panel look and feel | **owner** — PA5 | Floating, vibrant, readable in light and dark, Esc closes |
| Hotkey + Finder permission prompt | **owner** — PA4 | Prompt appears once; the selected file is summarized |
| Finder Service + System Settings shortcut | **owner** — PA4 | Right-click → Services/Quick Actions shows the item; a shortcut bound to it works |
| Apple Intelligence output | **owner** — PA6 | Needs Apple Intelligence enabled (it is off on the dev machine) |
| Real Anthropic / OpenAI / local / CLI responses | **owner** — PA11 "Test connection" | Each configured provider streams a summary |

The agent self-verifies everything the compiler and the test suite can show. Every visual,
permission, hotkey, or real-credential check belongs to the owner and is listed under
**Pending human checks**.

---

## Ground Rules

1. **Branches:** one per phase, `phase-<n>-<slug>`, cut from `main`. Tag `pre-v0.1` on the first
   commit of `main`. The agent never commits directly to `main` after step 0.
2. **One step = one commit**, message `pa-step-N: …`, made **only when `make verify` is green.**
3. **Push and PR:** the agent pushes the phase branch, opens the PR, and merges it with a merge
   commit (never squash — step commits stay individually revertable) once CI is green. Never
   force-push; never rewrite pushed history.
4. **Never weaken verification** — no skipped tests, loosened assertions, or swallowed errors.
5. **Nothing writes outside the repo.** No `$TMPDIR`, no real `UserDefaults` suites, no real
   Keychain, no network, no real CLI runs in tests. The Makefile pins SwiftPM caches to `.build/`.
6. **No third-party dependencies.** Apple frameworks only.
7. **Idle means idle**: no timers or background work unless a summary is running.
8. **App Store-readiness:** Apple Events and `Process`-spawning code compile only when `APPSTORE`
   is *not* defined. `make verify` builds both variants.
9. **No AI attribution** in commits, PR titles, or bodies.
10. **Every step:** update `AGENTS.md`, `docs/ARCHITECTURE.md` (from PA3 on), `README.md`, and
    this tracker as needed, in the same commit.

### Stop conditions

The agent stops, reports which condition fired, and waits:

- `make verify` still red after two honest fix attempts.
- Getting green would mean weakening verification (Ground Rule 4).
- The step needs something outside its prompt — a new dependency, a design decision, a file
  the prompt didn't name that changes behavior elsewhere.
- The diff is much larger than the step implies.
- The prompt contradicts the code (a named file or interface doesn't exist as described).
- Anything destructive or irreversible, publishing a GitHub Release, or changing repo settings.
- CI fails for a reason that doesn't reproduce locally after one fix attempt.
- Anything that needs a credential, a macOS permission grant, or a GUI interaction.

### Rollback

| Situation | Command |
|---|---|
| Step wrong, not yet committed | `git restore . && git clean -fd` (run `git status` first) |
| A committed step is bad | `git revert <sha>` |
| A merged phase is bad | `git revert -m 1 <merge-sha>` on a new branch, PR it |
| Abandon everything | `pre-v0.1` marks the start |

---

## 0. Before Starting

Greenfield — step 0 creates the repo (done once, by the planning session):

```bash
cd /Users/memoli/Storage/CS/previewAI
git init && git branch -M main
git add .gitignore LICENSE AGENTS.md README.md docs/BUILD_PLAN.md
git commit -m "pa-step-0: scope docs and build plan"
gh repo create memoliertorerr/previewAI --public --source . --remote origin --push \
  --description "Select a document in Finder, press a shortcut, get an AI summary. Native, lightweight macOS menu-bar app."
git tag pre-v0.1 && git push origin pre-v0.1
```

Each phase then starts with:

```bash
git switch main && git pull --ff-only
git switch -c phase-<n>-<slug>
```

---

## Design Decisions Already Made

Do not redesign these mid-plan; if a step seems to require changing one, that is a stop.

- **SwiftPM + Makefile + `scripts/bundle.sh`, no `.xcodeproj`.** Keeps the repo diffable and
  buildable from the CLI. The App Store target (which needs an app extension and archive) is
  Later and will add an Xcode project then.
- **AppKit lifecycle, SwiftUI views.** `NSStatusItem`, `NSPanel`, and a settings `NSWindow` host
  SwiftUI. Predictable activation behavior for an `LSUIElement` app.
- **Carbon `RegisterEventHotKey`** for the global shortcut. Needs no Accessibility permission and
  works in the sandbox.
- **Finder selection via Apple Events** (`NSAppleScript`), direct build only. The Service entry
  point is the sandbox-friendly path and exists in both variants.
- **Text extraction, not native file upload.** Every provider receives extracted text, so all
  six behave the same and requests stay small. Each provider declares a character budget; if
  the document exceeds it, the session shows a visible "Summarized the first N%" note — never a
  silent truncation.
- **Anthropic over raw HTTP** (no Swift SDK exists): `POST /v1/messages`, `anthropic-version:
  2026-10-21`, `stream: true`. Default model `claude-opus-5-5` with `output_config.effort:
  "low"` for speed; Settings offers `claude-sonnet-5-5` and `claude-haiku-5-5`. For Opus 5.5 and
  Sonnet 5.5 requests send `fallbacks: "default"` with `anthropic-beta:
  server-side-fallback-2026-07-01`; never for Haiku 5.5. Always check `stop_reason` for
  `refusal`. No `temperature`/`top_p`/`top_k`, no `thinking` field, no assistant prefill.
- **OpenAI-compatible = one provider, many presets.** OpenAI (`https://api.openai.com/v1`),
  Ollama (`http://localhost:11434/v1`), LM Studio (`http://localhost:1234/v1`), custom.
  `POST {base}/chat/completions` with `stream: true`. The model is a free-text field.
- **Subscriptions via CLIs** (direct build only). Claude: `claude -p --output-format stream-json
  --verbose --include-partial-messages --tools "" --no-session-persistence
  --disable-slash-commands --strict-mcp-config --system-prompt <sys> --model <m>`, document on
  stdin, cwd `/`. Never `--bare` (it ignores subscription login). Codex: `codex exec --json
  --skip-git-repo-check --sandbox read-only --ephemeral -C / [-m <m>] -`, prompt on stdin.
- **Default shortcut ⌃⌥Space**, user-changeable.
- **Zero dependencies; Swift Testing for tests.**

---

## Steps

### PA1 — Scaffold, menu-bar shell, Makefile, bundle, CI · strong · auto

**Verify:** `make verify` green: debug build, `swift test` runs ≥1 passing test, `make app`
produces `build/PreviewAI.app` whose `Contents/Info.plist` passes `plutil -lint` and has
`LSUIElement = true`; the `APPSTORE=1` variant also builds; `.github/workflows/ci.yml` exists.
**Commit:** `pa-step-1: swiftpm scaffold, menu-bar shell, make verify, ci`

**Implementation notes (2026-11-06):**

- **`scripts/bundle.sh` takes `<binary> <app path>`** instead of building itself; the Makefile
  does the build so the pinned SwiftPM paths live in one place. It refuses to write outside the
  repo.
- **The APPSTORE variant uses its own scratch dir** (`.build/appstore`) so switching `-D` flags
  doesn't force full rebuilds of the normal build.
- **`make lint` also runs `codesign --verify --deep`** on both bundles.
- The core constants enum is `PreviewAIInfo` (not `PreviewAI`) to avoid clashing with the
  executable module name.

```text
Create the project skeleton. Nothing user-facing beyond a menu-bar icon.

1. Package.swift — swift-tools-version 6.0, platforms [.macOS(.v14)]. Targets:
   - library PreviewAICore (Sources/PreviewAICore), linking PDFKit is implicit via import.
   - executableTarget PreviewAI (Sources/PreviewAI) depending on PreviewAICore. Linker
     setting: `-sectcreate __TEXT __info_plist Resources/Info.plist` is NOT used — the bundle
     script copies Info.plist instead.
   - testTarget PreviewAICoreTests with resources: [.copy("Fixtures")].
   No dependencies.
2. Sources/PreviewAICore/PreviewAICore.swift — `public enum PreviewAI { public static let
   version = "0.1.0" }`.
3. Sources/PreviewAI/main.swift + AppDelegate.swift — NSApplication with .accessory activation
   policy; an NSStatusItem using SF Symbol "text.page.badge.magnifyingglass" (fall back to
   "doc.text.magnifyingglass" if nil) with a menu: "Summarize Selection" (disabled for now),
   separator, "Settings…" (disabled), "Quit PreviewAI" (⌘Q). @MainActor throughout.
4. Resources/Info.plist — CFBundleIdentifier com.memoliertorerr.PreviewAI, name PreviewAI,
   executable PreviewAI, version 0.1.0, LSMinimumSystemVersion 14.0, LSUIElement true,
   NSAppleEventsUsageDescription "PreviewAI reads which file is selected in Finder so it can
   summarize it.", NSHighResolutionCapable true.
5. scripts/bundle.sh — args: <config> <outdir>. Builds `swift build -c release` via the same
   pinned paths as the Makefile, assembles <outdir>/PreviewAI.app/Contents/{MacOS,Resources},
   copies the binary and Info.plist, ad-hoc signs with `codesign --force --sign - `. set -euo
   pipefail. Writes only under the repo.
6. Makefile — SWIFT_FLAGS pin `--cache-path .build/cache --config-path .build/config
   --security-path .build/security --scratch-path .build`. Targets: build, test, app (release
   bundle into build/), app-appstore (same with `-Xswiftc -DAPPSTORE`, into build/appstore/),
   lint (plutil -lint the bundle Info.plists + check LSUIElement via /usr/libexec/PlistBuddy),
   verify = build test app app-appstore lint, clean (removes .build build dist only).
7. Tests/PreviewAICoreTests/SmokeTests.swift — Swift Testing test that version is "0.1.0".
   Tests/PreviewAICoreTests/Fixtures/.keep. Tests/PreviewAICoreTests/TestSupport.swift with
   `enum TestSupport { static var scratch: URL }` → <repo>/.build/test-scratch/<UUID>, derived
   from #filePath, created on demand. Every later test that needs a file uses it.
8. .github/workflows/ci.yml — on push to main and pull_request: runs-on macos-26, steps:
   checkout, `sudo xcode-select -s` the newest /Applications/Xcode_26*.app if present, print
   `swift --version`, `make verify`. If the macos-26 label turns out not to exist, that is
   discovered in phase PR CI — record it as a landmine and switch to the nearest available
   macOS image that ships Xcode 26.
9. README.md — what it is, status "under construction", build: `make app && open
   build/PreviewAI.app`.

Do NOT add any provider, panel, or hotkey code — later steps own them.

Run make verify. If it is green, flip PA1 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-1: swiftpm scaffold, menu-bar shell, make verify, ci". Paste the verify
output and the output of `git log -1 --stat`. If it is still red after two honest fix
attempts, stop and report — never commit red, never weaken a check to get green.
```

---

### PA2 — Document loading and budgets · strong · auto

**Verify:** `make verify` green, including tests that (a) a Markdown fixture loads verbatim with
kind `.markdown` and correct title; (b) a 3-page PDF generated in the test (CoreGraphics PDF
context, into `TestSupport.scratch`) loads with pageCount 3 and text from every page; (c) an
RTF and an HTML fixture load as plain text; (d) an unsupported file (`.png`) throws
`DocumentError.unsupported`; (e) an empty/scanned PDF throws `DocumentError.noText`;
(f) `budgeted(maxCharacters:)` on a 10 000-char doc with budget 4 000 returns 4 000 chars cut at
a whitespace/paragraph boundary, `isTruncated == true`, `fractionIncluded ≈ 0.4`.
**Commit:** `pa-step-2: document loader for pdf/md/txt/rtf/docx/html with budgets`

**Implementation notes (2026-11-06):**

- **HTML loads on the main actor**: the `NSAttributedString` HTML importer is WebKit-backed and
  documented as main-thread only. Other kinds extract in a detached task.
- **Budget cut rule:** prefer a paragraph break within the last 20% of the window, otherwise
  the last whitespace — keeps truncation from discarding most of the budget on one early break.
- Added a DOCX test (generated with `NSAttributedString` `.officeOpenXML` export) and a
  paragraph-boundary test beyond the Verify list.

```text
Build the document layer in Sources/PreviewAICore/Document/.

1. DocumentContent.swift — `public struct DocumentContent: Sendable, Equatable { url, title
   (filename without extension), kind: DocumentKind, text, pageCount: Int?, originalLength:
   Int, isTruncated: Bool }` and `func budgeted(maxCharacters: Int) -> DocumentContent` which
   cuts at the last paragraph break (or whitespace) before the limit and sets isTruncated;
   `var fractionIncluded: Double`.
   DocumentKind: pdf, markdown, plainText, richText, word, html. Built from the UTType of the
   file (UniformTypeIdentifiers): .pdf, net.daringfireball.markdown / extensions md, markdown,
   mdown; .plainText and conforming types (txt, source code files count as plainText);
   .rtf/.rtfd; org.openxmlformats.wordprocessingml.document (.docx); .html.
2. DocumentLoader.swift — `public struct DocumentLoader: Sendable { public func load(_ url: URL)
   async throws -> DocumentContent }`. Runs the extraction off the main actor (it's CPU work).
   - PDF: PDFKit PDFDocument(url:), concatenate page.string with "\n\n" between pages. Trim. If
     the result is empty → DocumentError.noText (scanned PDF; OCR is Later).
   - Markdown / plain text: read as UTF-8, falling back to `String(contentsOf:usedEncoding:)`.
   - RTF / DOCX / HTML: NSAttributedString(url:options:documentAttributes:) with the matching
     documentType, take .string. (NSAttributedString is in Foundation on macOS — no AppKit
     window needed.)
   - Refuse files over 200 MB with DocumentError.tooLarge before reading.
   DocumentError: unsupported(String), noText, tooLarge, unreadable(String) — LocalizedError
   with short human messages ("This PDF has no selectable text (it may be scanned).").
3. Tests: Tests/PreviewAICoreTests/DocumentLoaderTests.swift with committed fixtures
   Fixtures/sample.md, sample.rtf, sample.html (small, hand-written) and the PDF generated at
   test time into TestSupport.scratch. Cover the six cases in the Verify line.

Do NOT add prompts or providers (PA3). Do NOT use $TMPDIR — use TestSupport.scratch.

Run make verify. If it is green, flip PA2 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-2: document loader for pdf/md/txt/rtf/docx/html with budgets". Paste the
verify output and the output of `git log -1 --stat`. If it is still red after two honest fix
attempts, stop and report — never commit red, never weaken a check to get green.
```

---

### PA3 — Provider contract, prompt, session, cache · strong · auto

**Verify:** `make verify` green, including tests that (a) `PromptBuilder` output for each
`SummaryLength` contains the document title, the length instruction, and the text inside
`<document>` tags, plus a truncation note only when `isTruncated`; (b) `SummarySession` with a
mock provider moves `idle → loading → streaming(partial) → finished(full)` and concatenates
chunks in order; (c) a provider error lands in `.failed(message)`; (d) `cancel()` stops a slow
mock stream and leaves `.idle`; (e) a second request for the same file + mtime + provider +
length is served from `SummaryCache` without calling the provider; (f) the cache evicts beyond
its capacity (LRU, 20 entries).
**Commit:** `pa-step-3: provider contract, prompt builder, summary session, cache`

```text
Define the contract every provider and the panel depend on. Get the shape right — every later
step inherits it.

1. Providers/SummaryProvider.swift:
   public enum ProviderID: String, Codable, CaseIterable, Sendable { appleIntelligence,
     anthropic, openAICompatible, claudeCode, codex }
   public struct SummaryRequest: Sendable { system: String; user: String; maxOutputTokens: Int }
   public protocol SummaryProvider: Sendable {
     var id: ProviderID { get }
     var displayName: String { get }
     /// Characters of document text this provider can take in one request.
     var inputBudget: Int { get }
     func availability() async -> ProviderAvailability   // .ready / .unavailable(reason)
     func stream(_ request: SummaryRequest) -> AsyncThrowingStream<String, Error>
   }
   public enum ProviderError: LocalizedError — notConfigured(String), unauthorized,
     rateLimited, refused, http(Int, String), network(String), process(String),
     unavailable(String). Short, human messages.
2. Prompt/SummaryLength.swift — brief (TL;DR + 3 bullets), standard (TL;DR + 5–7 bullets +
   one-line "Why it matters"), detailed (TL;DR + sectioned summary). Codable, CaseIterable.
   Prompt/PromptBuilder.swift — `static func request(for doc: DocumentContent, length:
   SummaryLength) -> SummaryRequest`. System prompt: summarize faithfully, Markdown output,
   same language as the document, no preamble, don't invent facts. User message: title, kind,
   page count, then the text inside <document>…</document>, then the length instruction; if
   truncated add "Only the first N% of the document is included; say so in one short line at
   the end." maxOutputTokens: brief 600, standard 1200, detailed 3000.
3. Session/SummarySession.swift — `@MainActor @Observable public final class SummarySession`.
   State: idle, loading(DocumentInfo), streaming(DocumentInfo, text), finished(DocumentInfo,
   text), failed(DocumentInfo?, message). DocumentInfo: title, kind, pageCount, truncated note.
   `func summarize(url:, provider:, length:)` — cancels any running task; loads via
   DocumentLoader; budgets to provider.inputBudget; checks the cache; streams, appending
   chunks; stores the final text in the cache. `cancel()`, `regenerate()` (bypasses cache).
   Injectable DocumentLoader and SummaryCache for tests.
4. Session/SummaryCache.swift — in-memory LRU keyed by (path, mtime, size, provider id, model
   string, length). Capacity 20. No disk.
5. docs/ARCHITECTURE.md — create it: the flow (entry point → SummarySession → DocumentLoader →
   PromptBuilder → SummaryProvider → panel), the layout from AGENTS.md, and the APPSTORE rule.
6. Tests with a MockProvider (scripted chunks, optional delay, optional error).

Do NOT implement any real provider (PA6, PA8–PA10) or any UI (PA5).

Run make verify. If it is green, flip PA3 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-3: provider contract, prompt builder, summary session, cache". Paste the
verify output and the output of `git log -1 --stat`. If it is still red after two honest fix
attempts, stop and report — never commit red, never weaken a check to get green.
This ends phase 1: push the branch, open the PR using the PR description template, merge when
CI is green, then stop.
```

---

### PA4 — Shortcut, hotkey, entry points, APPSTORE flag · strong · check

**Verify:** `make verify` green (both variants), including tests that `KeyCombo` (a) round-trips
through Codable; (b) renders ⌃⌥Space as "⌃⌥Space" and ⌘⇧K as "⇧⌘K" (Apple's modifier order
⌃⌥⇧⌘); (c) converts NSEvent-style modifier flags to Carbon modifiers correctly; (d) rejects a
combo with no modifier (except F-keys); and a test that `EntryPoint.resolveFiles` keeps only
existing regular files. `grep -n "NSAppleScript" -r Sources` only matches inside `#if
!APPSTORE` blocks.
**Human check:** run `make app && open build/PreviewAI.app`; select a PDF in Finder, press
⌃⌥Space → the Automation prompt appears once; after allowing, the menu shows the file was
received (temporary "Last file: …" item). Right-click a file → Quick Actions / Services →
"Summarize with PreviewAI" exists; bind it in System Settings → Keyboard → Keyboard Shortcuts
→ Services → Files and Folders and confirm the shortcut triggers it.
**Commit:** `pa-step-4: global hotkey, finder selection, service and open-with entry points`

```text
Wire every way a file reaches the app. No summarizing yet — the panel is PA5.

1. Core: Hotkey/KeyCombo.swift — `public struct KeyCombo: Codable, Hashable, Sendable {
   keyCode: UInt32; modifiers: Modifiers (OptionSet: control, option, shift, command) }`,
   `static let default = ⌃⌥Space` (kVK_Space = 49), `displayString`, `carbonModifiers`
   (cmdKey/optionKey/controlKey/shiftKey values hard-coded as constants so Core needn't import
   Carbon), `init?(keyCode:modifierFlagsRawValue:)` mirroring NSEvent.ModifierFlags bits,
   `isValid`. Key names for letters, digits, space, return, tab, F1–F12, arrows.
2. Core: EntryPoint.swift — `static func resolveFiles(_ urls: [URL]) -> [URL]` keeps file URLs
   that exist and are regular files (not directories/packages).
3. App: HotkeyManager.swift — wraps RegisterEventHotKey / InstallEventHandler for one combo;
   `register(_:)` replaces the previous; reports failure (combo taken) via a return value.
   The Carbon callback hops to the main actor.
4. App: FinderSelection.swift — wrapped entirely in `#if !APPSTORE`. Uses NSAppleScript:
   tell Finder to return POSIX paths of the selection. Only queried when the frontmost app is
   Finder (NSWorkspace.shared.frontmostApplication bundle id com.apple.finder); otherwise
   returns .notFinder. Maps errAEEventNotPermitted (-1743) to .permissionDenied.
5. App: ServiceProvider.swift — NSServices handler `summarizeFiles(_:userData:error:)` reading
   file URLs from the pasteboard. Add the NSServices entry to Resources/Info.plist:
   NSMenuItem default "Summarize with PreviewAI", NSMessage summarizeFiles, NSRequiredContext
   {}, NSSendFileTypes [public.item]. Register with NSApp.servicesProvider and call
   NSUpdateDynamicServices() at launch.
6. App: AppDelegate — application(_:open:) for Open With / drag onto icon; menu item
   "Summarize Selection" (hotkey shown as key equivalent text) and "Summarize File…"
   (NSOpenPanel). All four paths call one `handle(files:)`, which for now records the first
   file and shows it as a disabled menu item "Last file: <name>" (removed in PA6). In the
   APPSTORE variant the hotkey path shows a one-line hint to use the Service instead.
   Add CFBundleDocumentTypes (viewer role, LSHandlerRank Alternate) for pdf, markdown, plain
   text, rtf, docx, html to Info.plist so "Open With" lists the app.
7. Update AGENTS.md / ARCHITECTURE.md (entry points), README (permissions section).

Do NOT persist the shortcut yet (PA7) or build the recorder (PA11) — use KeyCombo.default.

Run make verify. If it is green, flip PA4 to ✅ in docs/BUILD_PLAN.md, copy the Human check
line into "Pending human checks", and commit everything as one commit: "pa-step-4: global
hotkey, finder selection, service and open-with entry points". Paste the verify output and the
output of `git log -1 --stat`. If it is still red after two honest fix attempts, stop and
report — never commit red, never weaken a check to get green.
```

---

### PA5 — Floating summary panel · strong · check

**Verify:** `make verify` green, including tests of the panel's view-model mapping
(`PanelContent(from: SummarySession.State)`): loading shows the title and a spinner flag;
streaming exposes the text; failed exposes the message and a retry action; the truncation
note surfaces when present.
**Human check:** with a debug "Demo summary" menu item (streams canned text through a mock
provider), the panel appears centered on the screen with the mouse, floats over Finder without
stealing Finder's selection, uses system vibrancy, renders Markdown (bold, bullets, headings),
is readable in light and dark mode; Esc and the hotkey close it; ⌘C copies the summary.
**Commit:** `pa-step-5: quick-look style floating summary panel`

```text
Build the panel the user sees. Native first: system materials, system fonts, standard keys.

1. Core: Session/PanelContent.swift — pure mapping from SummarySession.State to what the view
   shows (title, subtitle "PDF · 12 pages", body text, isWorking, error, truncation note,
   canCopy, canRegenerate). Tested.
2. App: SummaryPanel/SummaryPanelController.swift — NSPanel subclass: styleMask [.titled,
   .closable, .resizable, .fullSizeContentView, .nonactivatingPanel], titlebar transparent,
   title hidden, level .floating, collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary],
   becomesKeyOnlyIfNeeded false, canBecomeKey true, hidesOnDeactivate false, isReleasedWhenClosed
   false. Size 560×460, min 420×300, remembers its frame (setFrameAutosaveName). Shown centered
   on the screen containing the mouse. Esc (cancelOperation) closes and cancels the session.
   Background: NSVisualEffectView, material .popover (light, native, Quick Look-like); on
   macOS 26 use SwiftUI `.glassEffect` instead (#available check).
3. App: SummaryPanel/SummaryView.swift — SwiftUI: header (file icon via
   NSWorkspace.shared.icon(forFile:), title, subtitle, provider name chip), body ScrollView with
   Text(AttributedString(markdown:, options: .inlineOnlyPreservingWhitespace fallback to full))
   rendered per block so bullets and headings look right; selectable text; ProgressView while
   loading; error state with "Try Again" and "Open Settings"; footer: length picker (segmented
   Brief / Standard / Detailed), Regenerate (⌘R), Copy (⌘C). Keep it to the system font and
   semantic colors.
4. Pressing the hotkey while the panel is visible closes it (toggle, like Space in Quick Look).
5. Add a DEBUG-only "Demo summary" menu item that runs a MockProvider-backed session, so the
   panel can be seen before real providers exist. Move MockProvider into Core under
   Providers/DemoProvider.swift (it's useful for the demo too); tests keep using it.

Do NOT add real providers (PA6+). Do NOT add a Dock icon or activate the app when showing the
panel — Finder must stay frontmost.

Run make verify. If it is green, flip PA5 to ✅ in docs/BUILD_PLAN.md, copy the Human check
line into "Pending human checks", and commit everything as one commit: "pa-step-5: quick-look
style floating summary panel". Paste the verify output and the output of `git log -1 --stat`.
If it is still red after two honest fix attempts, stop and report — never commit red, never
weaken a check to get green.
```

---

### PA6 — Apple Intelligence provider + end-to-end · strong · check

**Verify:** `make verify` green on both variants; `AppleIntelligenceProvider` compiles only
under `#if canImport(FoundationModels)` with `@available(macOS 26, *)`; a test asserts its
`inputBudget` keeps prompt + output within the on-device model's 4 096-token context (≤ 9 000
characters of document text); a test asserts `ProviderRegistry.current` falls back to Apple
Intelligence when nothing else is configured; the "Last file" placeholder is gone.
**Human check:** with Apple Intelligence enabled (System Settings → Apple Intelligence & Siri),
select a Markdown file and a PDF in Finder, press ⌃⌥Space: the panel opens instantly and text
streams in. With it disabled, the panel shows "Apple Intelligence is turned off" with an
"Open Settings" button.
**Commit:** `pa-step-6: apple intelligence provider and end-to-end summarize flow`

```text
First real provider and the full flow: entry point → panel → stream.

1. Core: Providers/AppleIntelligenceProvider.swift — FoundationModels: availability from
   SystemLanguageModel.default.availability mapped to human reasons (deviceNotEligible,
   appleIntelligenceNotEnabled, modelNotReady). stream(): LanguageModelSession(instructions:
   request.system), `streamResponse(to: request.user)`; FoundationModels yields cumulative
   snapshots — convert to deltas before yielding. inputBudget 9 000 characters.
   Map exceededContextWindowSize to a ProviderError with a clear message.
2. Core: Providers/ProviderRegistry.swift — builds the active provider from a selected
   ProviderID (for now only appleIntelligence is real; others report .unavailable("Not set up
   yet")). Default selection: appleIntelligence.
3. App: replace the PA4 placeholder — handle(files:) shows the panel and calls
   session.summarize(url: first, provider: registry.current, length: .standard). If several
   files are selected, summarize the first and note "+N more" in the subtitle.
4. Error states: .unavailable → panel error with "Open Settings" (opens the relevant System
   Settings pane via x-apple.systempreferences: URL for Apple Intelligence).

Do NOT build the settings window (PA11); selection is the registry default for now.

Run make verify. If it is green, flip PA6 to ✅ in docs/BUILD_PLAN.md, copy the Human check
line into "Pending human checks", and commit everything as one commit: "pa-step-6: apple
intelligence provider and end-to-end summarize flow". Paste the verify output and the output of
`git log -1 --stat`. If it is still red after two honest fix attempts, stop and report — never
commit red, never weaken a check to get green.
This ends phase 2: push the branch, open the PR using the PR description template, merge when
CI is green, then stop.
```

---

### PA7 — Settings and secrets · standard · auto

**Verify:** `make verify` green, including tests (with `InMemoryKeyValueStore` and
`InMemorySecretStore`) that (a) defaults are: provider appleIntelligence, length standard,
shortcut ⌃⌥Space, Anthropic model `claude-opus-5-5`, OpenAI-compatible preset OpenAI;
(b) every setting round-trips; (c) API keys are written only to the SecretStore — a test
asserts no stored UserDefaults value contains the key string; (d) `ProviderRegistry` builds the
selected provider from settings.
**Commit:** `pa-step-7: settings store, keychain secret store, provider configuration`

```text
1. Core: Settings/KeyValueStore.swift — protocol (data/string/bool get-set) with
   UserDefaultsStore (app) and InMemoryKeyValueStore (tests).
2. Core: Settings/SecretStore.swift — protocol get/set/delete(account:) with KeychainSecretStore
   (SecItem generic password, service "com.memoliertorerr.PreviewAI", kSecAttrAccessible
   AfterFirstUnlock) and InMemorySecretStore. KeychainSecretStore is never instantiated in
   tests.
3. Core: Settings/SettingsStore.swift — @MainActor @Observable: selectedProvider, length,
   shortcut (KeyCombo), launchAtLogin, per-provider config structs (AnthropicConfig{model},
   OpenAICompatibleConfig{preset, baseURL, model}, CLIConfig{binaryPath override, model}).
   Keys live behind `secret(for: ProviderID)`.
4. ProviderRegistry reads SettingsStore. App: hotkey registered from settings.shortcut.

Run make verify. If it is green, flip PA7 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-7: settings store, keychain secret store, provider configuration". Paste
the verify output and the output of `git log -1 --stat`. If it is still red after two honest
fix attempts, stop and report — never commit red, never weaken a check to get green.
```

---

### PA8 — SSE parser + Anthropic provider · standard · auto

**Verify:** `make verify` green, including tests that (a) `SSEParser` handles events split
across arbitrary byte chunks, multi-line `data:`, comments, and CRLF; (b) the Anthropic request
(captured by a stub `URLProtocol`) is `POST https://api.anthropic.com/v1/messages` with headers
`x-api-key`, `anthropic-version: 2026-10-21`, `content-type: application/json`, and body
`model`, `max_tokens`, `stream: true`, `system`, one user message, `output_config.effort: "low"`,
and **no** `temperature`/`top_p`/`top_k`/`thinking`; (c) for `claude-opus-5-5` the body has
`fallbacks: "default"` and the `anthropic-beta: server-side-fallback-2026-07-01` header; for
`claude-haiku-5-5` neither; (d) a canned stream yields only `text_delta` text in order and
ignores thinking deltas; (e) `stop_reason: "refusal"` → `ProviderError.refused`; an `error`
event → `ProviderError`; HTTP 401 → `.unauthorized`, 429 → `.rateLimited`.
**Commit:** `pa-step-8: sse parser and anthropic messages provider`

```text
1. Core: Net/SSEParser.swift — incremental parser over URLSession.AsyncBytes lines or raw
   chunks; emits (event, data) pairs.
2. Core: Net/HTTP.swift — shared helper: build a URLSession from an injectable
   URLSessionConfiguration (tests inject protocolClasses = [StubURLProtocol]); read error
   bodies for non-2xx.
3. Core: Providers/AnthropicProvider.swift — exactly the request in Design Decisions. Model
   list offered in Settings: claude-opus-5-5 (default), claude-sonnet-5-5, claude-haiku-5-5.
   max_tokens = max(request.maxOutputTokens, 4096). inputBudget 400 000 characters. Yield text
   from content_block_delta / text_delta only. Check message_delta.delta.stop_reason.
4. Tests: Tests/PreviewAICoreTests/StubURLProtocol.swift + AnthropicProviderTests.swift.

Do NOT send the PDF as a document block — text only (see Design Decisions).

Run make verify. If it is green, flip PA8 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-8: sse parser and anthropic messages provider". Paste the verify output
and the output of `git log -1 --stat`. If it is still red after two honest fix attempts, stop
and report — never commit red, never weaken a check to get green.
```

---

### PA9 — OpenAI-compatible provider · standard · auto

**Verify:** `make verify` green, including tests that (a) presets resolve to the documented base
URLs; (b) the request is `POST {base}/chat/completions` with `Authorization: Bearer <key>` only
when a key is set (Ollama/LM Studio need none), `stream: true`, system + user messages, and the
configured model; (c) `data: {choices:[{delta:{content}}]}` chunks yield text in order and
`data: [DONE]` ends the stream; (d) a connection-refused error on a localhost preset maps to
"Couldn't reach Ollama at localhost:11434 — is it running?"; (e) `listModels()` parses
`GET {base}/models`.
**Commit:** `pa-step-9: openai-compatible provider with openai, ollama, lm studio presets`

```text
1. Core: Providers/OpenAICompatibleProvider.swift with OpenAICompatiblePreset (openAI, ollama,
   lmStudio, custom). inputBudget: openAI 400 000; local presets 24 000 (local models have
   small contexts; user-adjustable later). max_tokens from request.
2. listModels() for the settings model picker.
3. Tests via StubURLProtocol.

Run make verify. If it is green, flip PA9 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-9: openai-compatible provider with openai, ollama, lm studio presets".
Paste the verify output and the output of `git log -1 --stat`. If it is still red after two
honest fix attempts, stop and report — never commit red, never weaken a check to get green.
```

---

### PA10 — CLI providers (Claude Code, Codex) · standard · auto

**Verify:** `make verify` green (both variants; CLI providers absent from the APPSTORE build),
including tests using fake executables in `Tests/PreviewAICoreTests/Fixtures/bin/` (shell
scripts that echo their argv to stderr and print canned output) that (a) the Claude provider
passes exactly the flags in Design Decisions, never `--bare`, sends the document on stdin, and
yields text from `stream_event` → `content_block_delta` → `text_delta` lines, falling back to
the final `result` line if no deltas came; (b) `is_error: true` in the result → ProviderError;
(c) the Codex provider passes the documented flags and yields the `agent_message` text from
`item.completed`; (d) a non-zero exit surfaces the last stderr line; (e) binary discovery checks
the override path, then `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`,
`~/.npm-global/bin`, `~/.bun/bin`, and reports "not installed" otherwise; (f) cancel terminates
the child process.
**Commit:** `pa-step-10: claude code and codex subscription providers via cli`

```text
1. Core: Providers/CLIRunner.swift (#if !APPSTORE) — Process with stdin/stdout/stderr pipes,
   line-buffered stdout as AsyncThrowingStream, termination on Task cancellation, cwd "/",
   environment = inherited + PATH extended with the discovery dirs (GUI apps get a minimal
   PATH; the CLIs are often node scripts needing `node` on PATH).
2. Core: Providers/ClaudeCodeProvider.swift and CodexProvider.swift (#if !APPSTORE). Model
   fields default to empty, meaning "use the CLI's own default model".
   inputBudget 400 000.
3. ProviderRegistry includes them only when !APPSTORE.
4. Fixtures/bin/fake-claude and fake-codex (chmod +x, committed).

Do NOT run the real claude or codex binaries from tests or verify — they use the owner's
subscription and write to ~/.claude / ~/.codex.

Run make verify. If it is green, flip PA10 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-10: claude code and codex subscription providers via cli". Paste the
verify output and the output of `git log -1 --stat`. If it is still red after two honest fix
attempts, stop and report — never commit red, never weaken a check to get green.
This ends phase 3: push the branch, open the PR using the PR description template, merge when
CI is green, then stop.
```

---

### PA11 — Settings window · strong · check

**Verify:** `make verify` green, including tests of `ShortcutRecorderModel` (rejects
modifier-less keys, Esc cancels recording, Delete clears to default) and of the
`ConnectionTester` (runs a tiny fixed prompt through a provider and reports success/failure
text) against the mock provider.
**Human check:** open Settings from the menu: General tab (shortcut recorder, default length,
launch at login), Providers tab (provider picker; per-provider fields; API key fields save to
Keychain; "Test connection" works for each provider you have). Change the shortcut and confirm
the new one works and the old one doesn't. Window looks native in light and dark.
**Commit:** `pa-step-11: settings window with shortcut recorder and connection test`

```text
1. App: Settings/SettingsWindowController.swift — a standard NSWindow (titled, closable,
   toolbar-style tabs) hosting SwiftUI SettingsView; activates the app while open, returns to
   .accessory when closed.
2. SettingsView: TabView General / Providers / About. Providers: Picker of ProviderID (CLI
   ones hidden in APPSTORE), then the selected provider's form: Anthropic (SecureField key,
   model picker), OpenAI-compatible (preset, base URL, SecureField key, model field + "Refresh"
   from listModels), Claude Code / Codex (detected path or "Not installed", optional override,
   model), Apple Intelligence (status line). "Test connection" button with inline result.
3. App: ShortcutRecorder.swift — a SwiftUI control backed by a local NSEvent monitor while
   recording; logic in Core ShortcutRecorderModel (tested). Re-registers the hotkey live; shows
   an inline warning if registration fails.
4. Core: ConnectionTester.swift.

Run make verify. If it is green, flip PA11 to ✅ in docs/BUILD_PLAN.md, copy the Human check
line into "Pending human checks", and commit everything as one commit: "pa-step-11: settings
window with shortcut recorder and connection test". Paste the verify output and the output of
`git log -1 --stat`. If it is still red after two honest fix attempts, stop and report — never
commit red, never weaken a check to get green.
```

---

### PA12 — Polish · standard · auto

**Verify:** `make verify` green, including tests that (a) the session releases its text and
task after `close()` (weak-reference check); (b) every ProviderError and DocumentError has a
non-empty, single-sentence message; (c) `LaunchAtLogin` wraps `SMAppService.mainApp` behind a
protocol and the settings toggle calls it (mock).
**Commit:** `pa-step-12: launch at login, error polish, idle memory`

```text
1. Launch at login via SMAppService.mainApp (register/unregister), surfaced in General.
2. Closing the panel cancels work and drops the session's text; the SwiftUI hosting view is
   torn down so idle memory returns to baseline.
3. Error copy pass: every error says what happened and what to do, in one sentence.
4. About tab: version, GitHub link, "No data leaves your Mac unless you choose a cloud
   provider."
5. Status-item menu shows the active provider name.

Run make verify. If it is green, flip PA12 to ✅ in docs/BUILD_PLAN.md and commit everything as
one commit: "pa-step-12: launch at login, error polish, idle memory". Paste the verify output
and the output of `git log -1 --stat`. If it is still red after two honest fix attempts, stop
and report — never commit red, never weaken a check to get green.
```

---

### PA13 — Docs, dist, distribution guide · standard · check

**Verify:** `make verify` green; `make dist` produces `dist/PreviewAI-0.1.0.zip` containing
`PreviewAI.app` with a valid ad-hoc signature (`codesign --verify --deep`); README covers
install, first run (permissions), providers, shortcuts, privacy, building; `docs/DISTRIBUTION.md`
documents Developer ID signing + notarization and the App Store path; `docs/ARCHITECTURE.md`
matches the code.
**Human check:** read README and DISTRIBUTION.md for accuracy; decide whether to publish a
GitHub Release (the agent does not publish releases).
**Commit:** `pa-step-13: readme, distribution guide, make dist`

```text
1. Makefile `dist` target: make app, then `ditto -c -k --keepParent build/PreviewAI.app
   dist/PreviewAI-<version>.zip`.
2. README.md: one-paragraph pitch, features, install (unzip → /Applications; ad-hoc builds need
   right-click → Open the first time), permissions (Automation for Finder), providers table,
   binding the Service shortcut, privacy, build from source, roadmap (link to Later).
3. docs/DISTRIBUTION.md: Developer ID Application cert, hardened runtime flags, `codesign
   --options runtime`, `xcrun notarytool submit --wait`, `xcrun stapler staple`; App Store
   path: Xcode project, sandbox entitlements (app-sandbox, network.client,
   files.user-selected.read-only), APPSTORE flag, a Finder Action extension, no CLI providers,
   review notes. State plainly which parts are untested.
4. Final pass on AGENTS.md and ARCHITECTURE.md.

Run make verify && make dist. If it is green, flip PA13 to ✅ in docs/BUILD_PLAN.md, copy the
Human check line into "Pending human checks", and commit everything as one commit: "pa-step-13:
readme, distribution guide, make dist". Paste the verify output and the output of
`git log -1 --stat`. If it is still red after two honest fix attempts, stop and report — never
commit red, never weaken a check to get green.
This ends phase 4: push the branch, open the PR using the PR description template, merge when
CI is green, then stop.
```

---

## Pending human checks

> `check` steps copy their Human check here when they land. Tick when done.

- *(none yet)*

---

## Deferred follow-ups (cross-step, live tracker)

> Things a step noticed but were out of its scope. Strike through when handled; don't delete.

- *(Steps add to this list as they surface out-of-scope friction.)*

---

## Landmines

Populated from real friction, not speculation:

- **Apple Intelligence is disabled on the dev machine** (`appleIntelligenceNotEnabled`, checked
  2026-11-06). The provider can be compiled and unit-tested for budgets/mapping only; its output
  is an owner check.
- **`claude --bare` ignores subscription login** — per `claude --help`, bare mode reads only
  `ANTHROPIC_API_KEY`. The Claude Code provider must not use it.
- **Ad-hoc signatures change on every rebuild.** macOS keys Automation (TCC) grants and Keychain
  item access to the code signature, so after a rebuild expect the Finder permission prompt and
  a Keychain "allow" prompt again. Fixed properly by Developer ID signing (Later).

---

## Later — designed, NOT built in v0.1

| Item | Design | What it needs |
|---|---|---|
| **Developer ID + notarization** | `codesign --options runtime` with a Developer ID cert; `notarytool` in a `make release` target; optional CI job with secrets | Owner's certificate and an app-specific password / API key in the keychain or CI secrets |
| **Mac App Store build** | Xcode project wrapping the same sources; `APPSTORE` flag; sandbox entitlements; Finder Action extension (appex) as the entry point; Apple Intelligence, API-key and local providers only | Xcode project, appex target, App Store Connect record, review notes |
| **Long-document mode** | Map-reduce: chunk by budget, summarize chunks in parallel, then summarize the summaries | Chunker + session progress UI |
| **Follow-up questions** | Text field under the summary; keeps the document text for the session | Multi-turn request shape per provider |
| **OCR for scanned PDFs** | Vision `VNRecognizeTextRequest` on rendered pages when PDFKit returns no text | Page rendering + progress |
| **Native PDF to Anthropic** | Send the PDF as a `document` block for layout/tables | Size limits, cost note in settings |
| **Double-tap modifier trigger** | CGEvent tap for "double-tap ⌥" | Accessibility permission; direct build only |
| **Summaries from other apps** | Preview / Safari frontmost-document path via AX or Apple Events | Per-app adapters |
| **History** | Opt-in local store of past summaries | Storage location decision |

**When Later work starts:** Developer ID first (removes the re-prompt landmine), then the App
Store build, then long-document mode.
