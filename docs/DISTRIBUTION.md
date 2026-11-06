# Distributing PreviewAI

PreviewAI ships two ways from the same sources:

| | Direct download (Developer ID) | Mac App Store |
|---|---|---|
| Build | `make app` + `scripts/release.sh` | Xcode project (not created yet) with `-DAPPSTORE` |
| Finder-selection shortcut | ✅ (Apple Events) | ❌ — use the Finder Service instead |
| Claude Code CLI / Codex CLI providers | ✅ free build (see `PROVIDER_TERMS.md`) | ❌ — sandboxed apps can't run them |
| Apple Intelligence, API keys, local servers | ✅ | ✅ |
| Status | Script written, **untested** until run with your certificate | Planned (see **Later** in BUILD_PLAN.md) |

> **What has been verified:** `make dist` produces an ad-hoc-signed zip whose app passes
> `codesign --verify --deep`, and the APPSTORE variant compiles with no Apple Events or `Process`
> code in its binary. **Not verified:** Developer ID signing, notarization, stapling, and anything
> App Store — they need your Apple Developer account.

## Direct download: Developer ID + notarization

### One-time setup

1. **Certificate.** Xcode → Settings → Accounts → your team → Manage Certificates → **+** →
   *Developer ID Application*. Check it's in your keychain:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
2. **Notary credentials.** Create an app-specific password at account.apple.com (Sign-In and
   Security → App-Specific Passwords), then store a keychain profile:
   ```bash
   xcrun notarytool store-credentials previewai-notary \
     --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
   ```

### Each release

0. Re-read the pages linked in `docs/PROVIDER_TERMS.md`; if a paid build is planned, follow its
   "paid build" row first.
1. Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Resources/Info.plist` and
   `PreviewAIInfo.version` in `Sources/PreviewAICore/PreviewAICore.swift`.
2. `make verify`
3. Sign, notarize, staple, zip:
   ```bash
   scripts/release.sh "Developer ID Application: Your Name (TEAMID)" previewai-notary
   ```
   The script signs with the **hardened runtime** and `Resources/PreviewAI-DeveloperID.entitlements`.
   That file carries `com.apple.security.automation.apple-events` — without it the hardened
   runtime blocks Apple Events and the Finder-selection shortcut stops working.
4. Upload `dist/PreviewAI-<version>.zip` to a GitHub Release.

Signing with a stable Developer ID also fixes the development annoyance where every rebuild
re-asks for the Finder (Automation) permission and Keychain access: macOS ties both to the code
signature, and ad-hoc signatures change with every build.

## Mac App Store (planned)

What the App Store build needs, given the architecture already in place:

1. **An Xcode project** wrapping the existing sources (SwiftPM can't build app extensions or
   archive for App Store Connect). Add `APPSTORE` to *Active Compilation Conditions*.
2. **Sandbox entitlements:** `Resources/PreviewAI-AppStore.entitlements` (app sandbox, outgoing
   network, user-selected read-only files).
3. **Entry points:** the `NSServices` Service already works sandboxed (macOS hands over the files
   with read access). Optionally add a Finder **Action extension** for a native Quick Action.
   The global shortcut can't read Finder's selection in the sandbox; the APPSTORE build already
   shows a hint pointing to the Service.
4. **Providers:** Apple Intelligence, Anthropic and OpenAI-compatible only (CLI providers are
   compiled out). `NSAllowsLocalNetworking` is already set for Ollama / LM Studio.
5. **Review notes:** explain that the app needs the user's own API key or a local server, and how
   to test with Apple Intelligence.
6. **Provider terms:** the App Store build has no CLI providers, which also keeps it clear of
   Anthropic's and OpenAI's rules on third-party use of plan logins (`docs/PROVIDER_TERMS.md`).
