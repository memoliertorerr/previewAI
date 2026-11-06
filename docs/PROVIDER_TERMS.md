# Provider terms — what PreviewAI may do with Claude Code and Codex logins

> Researched 2026-11-06 from public sources (quoted below; the Anthropic legal page was
> re-fetched and its quotes checked verbatim the same day). This is a reading of published
> policy, not legal advice. **Re-check the linked pages before every release** — Anthropic's
> page changed several times in 2026.

PreviewAI's API-key providers (Anthropic API, OpenAI-compatible) are ordinary API use and need no
special care beyond each provider's normal terms. The two **CLI providers** run the user's own
installed `claude` / `codex` and use whatever login that CLI already has. That is the part with
rules.

## Verdict

| | Claude Code CLI | Codex CLI |
|---|---|---|
| Free, open-source, direct download (today) | **Allowed with conditions** — fits Anthropic's carve-out for an end user signing in to the unmodified binary; Anthropic's Agent SDK page is stricter in tone (see below) | **Allowed with conditions** — no rule against it; OpenAI documents `codex exec` for scripting and apps, and open-source apps are eligible for plan usage |
| Paid build, or Mac App Store | **Get written approval from Anthropic first**, or ship without this provider | **Use OpenAI's "Sign in with ChatGPT" program** (paid apps: interest form), or ship without this provider |

The Mac App Store build already compiles both CLI providers out (sandboxed apps can't run them).

## What the sources say

### Anthropic

- **Claude Code — Legal and compliance**, https://code.claude.com/docs/en/legal-and-compliance
  - "Developers building products or services … including those using the Agent SDK, should use
    API key authentication … Anthropic does not permit third-party developers to offer Claude.ai
    login into their own applications, or to route requests through Free, Pro, Max, or Ultra plan
    credentials on behalf of their users … developers may not collect, store, or intermediate
    Claude.ai credentials or session tokens."
  - Carve-out: this does not prevent "an end user from signing in to the unmodified Claude Code
    binary with their own Claude subscription, including where a platform hosts Claude Code."
  - "Preinstalling or running Claude Code in your products or services … requires agreeing to our
    Commercial Terms of Service" and: the binary must not be modified or have its sign-in methods
    removed; customers "may not pay for, resell, or intermediate Claude usage on their end users'
    behalf. Each end user must authenticate with their own" credentials.
  - "Advertised usage limits for Pro, Max, and Ultra plans assume ordinary, individual usage of
    Claude Code and the Agent SDK."
  - Branding: you may say in plain text that your product runs Claude Code, but not use "Claude
    Code" or "Anthropic" as part of your product or feature name, or imply endorsement.
- **Agent SDK overview**, https://code.claude.com/docs/en/agent-sdk/overview — "Unless previously
  approved, Anthropic does not allow third party developers to offer claude.ai login or rate limits
  for their products … Use the API key authentication methods … instead."
- **Consumer Terms** (effective 2025-10-08), https://www.anthropic.com/legal/consumer-terms — no
  automated access "except … via an Anthropic API Key or where we otherwise explicitly permit it";
  no sharing credentials or reselling.
- **Support: "Use the Agent SDK with your Claude plan"**, https://support.claude.com/en/articles/15036540
  — updates dated 2026-06-15 and 2026-10-07 confirm `claude -p` signed in with a plan still draws
  from that plan's limits (i.e. Anthropic expects and permits this programmatic use).

**Ambiguity:** the Agent SDK page's "no claude.ai login or rate limits for their products" is
stricter than the legal page's end-user carve-out. PreviewAI never offers a Claude login (the
user signs in through Anthropic's own CLI flow), but a cautious reading would still call the
provider "offering plan rate limits". Hence the conditions below and the paid/App Store rule.

### OpenAI

- **Codex non-interactive mode**, https://learn.chatgpt.com/docs/non-interactive-mode — `codex
  exec` is for pipelines and scripts and "reuses saved CLI authentication by default"; its examples
  include "generating release notes and summaries".
- **Codex auth**, https://learn.chatgpt.com/docs/auth — "API keys are still the recommended
  default for automation"; "Don't expose Codex execution in untrusted or public environments."
- **Sign in with ChatGPT (SIWC)**, https://developers.openai.com/siwc/quickstart — "ChatGPT plan
  usage is available to all open-source partners and selected private clients"; paid or hosted
  apps should "complete the interest form" (https://developers.openai.com/siwc/token-sharing-open-source).
- **Terms of Use** — don't share credentials or make your account available to others; don't
  circumvent rate limits. (The live page couldn't be fetched during research; re-check
  https://openai.com/policies/terms-of-use/.)
- Codex CLI is Apache-2.0 (https://github.com/openai/codex), which grants no trademark rights.

## Conditions PreviewAI follows (enforced in code and docs)

1. **Only the user's own installed, unmodified CLI.** Never bundled, downloaded, patched, or
   wrapped; none of its sign-in methods are disabled.
2. **No credential handling.** PreviewAI never reads, stores, prompts for, logs, or passes CLI
   tokens or files (`~/.claude`, `~/.codex/auth.json`, `CLAUDE_CODE_OAUTH_TOKEN`). There is no
   in-app login; users sign in by running the CLI in Terminal.
3. **Local and individual.** One user, one Mac, one summary per user action. No server relay, no
   pooling, no background or batch jobs, no retry loops around rate limits (errors are shown).
4. **Descriptive labels, no implied affiliation.** "Claude Code CLI (your login)" / "Codex CLI
   (your login)"; a notice in Settings says PreviewAI isn't made by, affiliated with, or endorsed
   by Anthropic / OpenAI, that usage counts toward the user's plan limits, and that an API key is
   the recommended option. The About tab carries the same independence statement. No logos.
5. **API keys are the recommended path** for both vendors, and are presented as such.
6. **Paid builds and the Mac App Store** ship without the CLI providers unless Anthropic has
   approved it in writing (Claude) and PreviewAI is enrolled in Sign in with ChatGPT (Codex).
   The APPSTORE build already excludes them.

## Owner actions (not code)

- **Anthropic Commercial Terms.** "Preinstalling or running Claude Code in your products or
  services … requires agreeing to our Commercial Terms of Service." As the distributor of an app
  that runs Claude Code, accept them before shipping a build with the Claude Code CLI provider —
  creating a Claude Console account (platform.claude.com) for API access does this. Questions:
  Anthropic's "contact sales" link on the legal page.
- **Before a paid or App Store release:** written approval from Anthropic for the Claude Code CLI
  provider, and enrollment in OpenAI's Sign in with ChatGPT program for Codex — or ship without
  both (the APPSTORE build already does).

`Tests/PreviewAICoreTests/CLIProviderTests.swift` (`ProviderTermsTests`) pins the labels and the
notice text; change them only together with this document.
