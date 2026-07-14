# PRD: lazy-environment

**Status:** Draft
**Version:** 0.1
**Date:** 2026-07-14
**Platform:** macOS (Apple Silicon, Swift/SwiftUI) + Bun/Hono backend
**Intended implementer:** Claude Code (this document is the spec handed into an implementation session)

---

## 1. Summary

`lazy-environment` is a native macOS GUI application that installs, updates, inspects, and organizes developer toolchains (languages, runtimes, CLIs, AI coding agents) in a consistent, disk-visible, user-controlled way. It replaces a pile of shell scripts with a single panel that shows what's installed, where it lives on disk, how much space it uses, and lets the user update everything with one click.

The app works fully offline/local without an account. Signing in (GitHub OAuth) unlocks personal environment profiles synced through a lightweight backend (Bun + Hono), so a user's exact toolchain setup can be restored on a new Mac in minutes instead of hours.

This PRD captures both the product requirements and the hard engineering constraints discovered while designing the underlying install scripts, so the implementer doesn't have to rediscover them.

---

## 2. Problem Statement

- Setting up a new Mac's dev environment from scratch is slow and repetitive (this project originated from exactly that: a new M5 Max Mac).
- Dev tool installers scatter files across `~/Library/Application Support`, `~/Library/Caches`, and other non-obvious locations, making disk usage and "what's actually installed" opaque.
- CLI version managers (nvm, sdkman, rbenv, rustup, uv, etc.) each have their own conventions, install methods, and quirks — there's no unified, visual way to manage them.
- There is no easy way to carry "my exact dev environment recipe" from one machine to another beyond personal dotfiles + tribal knowledge.

## 3. Goals

- G1: One GUI panel showing install status, resolved path, and disk usage for every managed environment.
- G2: One-click install and one-click update per environment.
- G3: A plugin/recipe abstraction so new environments (official or user-defined) can be added without touching core app code.
- G4: Local-first — full functionality without login.
- G5: Optional account (GitHub OAuth) to save/sync a personal environment profile across machines.
- G6: Conflict-aware sync — never silently overwrite local or remote state.

## 4. Non-Goals (v1)

- Not a general-purpose package manager (not replacing Homebrew, apt, etc.) — it orchestrates existing official installers/version managers.
- Not managing Xcode.app itself or the Mac App Store install flow.
- Not attempting to relocate iOS Simulator runtime data (see §9.5 — this is technically blocked by Apple, not a scoping choice).
- Not a CI/automation tool; this is a single-user desktop app.
- Windows/Linux support is out of scope for v1.

## 5. Target User

Primary: an individual developer (the requester) who wants a clean, inspectable, reproducible dev environment across machine refreshes. Secondary (future): any developer who wants a GUI alternative to hand-rolled dotfiles/bootstrap scripts.

---

## 6. Product Scope

### 6.1 Local Engine (no login required)
- Maintains a catalog of "Recipes" (see §10.1 data model) describing how to detect, install, update, and measure disk usage for an environment.
- Ships with built-in recipes for the environments enumerated in §9.
- Runs install/update commands as subprocesses, streams output to the UI.
- Persists local state (installed recipes, custom user recipes, last-known versions, cached disk usage) to `~/Library/Application Support/LazyEnvironment/` (SQLite or JSON — implementer's choice, see §12).
- Computes and caches disk usage per recipe's declared paths; refresh is manual or on a background timer, never blocking the UI thread.

### 6.2 GUI (SwiftUI)
- Main panel: list/grid of environments grouped by category (Language, Runtime, Mobile, Editor, AI Agent, Custom), each row showing: name, installed version, install path, disk usage, status (not installed / up to date / update available / broken), and an action button (Install / Update / —).
- Detail view per environment: full resolved paths, env vars it manages, raw log output of the last install/update run, uninstall action.
- "Add custom environment" flow: user fills in a form (or edits raw JSON) matching the Recipe schema (§10.1) to define their own environment.
- Global "Update All" action.
- Account panel: sign-in state, sync status, last synced time, manual "Sync now" and "Sign out" actions.

### 6.3 Auth & Backend Sync
- Unauthenticated: app fetches a **public, backend-hosted catalog** of default/curated recipes (read-only) and merges it with local state as available-but-not-personalized options.
- Sign in via GitHub OAuth (`ASWebAuthenticationSession` on the Swift side, standard OAuth code exchange + JWT session on the Hono side).
- Authenticated: app fetches the user's saved profile (their enabled recipes, pinned versions/paths, custom recipes) from the backend.
- **Conflict handling (critical UX, see §11.4):** on login, diff local state vs. fetched remote profile *per recipe*, not globally. For every recipe where local and remote disagree, surface it individually with options: *Use local* / *Use cloud* / *Keep both (as a named variant)* / *Delete this one*. Do not force one global resolution for everything.
- After resolution, local state is source of truth going forward until the user syncs again; syncing is push+pull, last-write-wins per recipe with the timestamp shown to the user, never silent.

---

## 7. Functional Requirements

| ID | Requirement |
|----|-------------|
| FR1 | App must function fully with no network access and no account. |
| FR2 | Each recipe's install/update command runs as a subprocess with live stdout/stderr streamed to a log view. |
| FR3 | Disk usage per recipe is computed from its declared `diskUsagePaths` and cached; user can force-refresh. |
| FR4 | User can add, edit, and delete custom recipes via a form or raw JSON editor. |
| FR5 | User can pin a specific version per recipe instead of "always latest," where the underlying tool supports it. |
| FR6 | Sign-in is optional and never blocks core functionality. |
| FR7 | On login, per-recipe conflicts between local and remote state are surfaced individually, never auto-merged silently. |
| FR8 | The app must clearly show, before running, exactly what command(s) a recipe's install/update will execute (no hidden remote script execution — see §11.2). |
| FR9 | Recipes that require an interactive shell to run (nvm, sdkman — see §9.6) must be flagged as such in the schema and handled via a distinct execution path from plain-binary recipes. |

## 8. Non-Functional Requirements

- **Performance:** disk usage scans must not block the UI; use background queues and cache results with a visible "last updated" timestamp.
- **Security:** installer scripts fetched from the network should be pinned to a known tag/commit where the upstream project supports it (nvm, neovim, etc. — both already expose tagged GitHub releases, see §9). Never execute unpinned "latest branch HEAD" scripts silently.
- **Transparency:** every subprocess command the app is about to run is shown to the user before or during execution (FR8). This app runs privileged-adjacent operations (writes into `/opt/homebrew`, mounts dmgs, writes to `defaults`) — trust must be earned with visibility, not hidden behind a spinner.
- **Resilience:** a failed install/update for one recipe must never crash the app or block other recipes from being managed.
- **Distribution:** ship notarized, outside the Mac App Store, for v1 (see §9.7 — sandboxing makes MAS distribution impractical for this feature set).

---

## 9. Built-in Environments & Engineering Notes

This section captures verified, non-obvious implementation details discovered while designing the underlying scripts. Treat this as required reading before implementing each recipe — several of these are not what the "obvious" official docs suggest.

### 9.1 Homebrew
- Bootstrapped via the official `NONINTERACTIVE=1` install script. This is the one unavoidable exception to "avoid brew" — nothing else works without it existing on the system.
- Per product decision: Homebrew itself is reserved for *auxiliary* tools only (`jq`, `git`, `gh`) and GUI casks (VS Code, Cursor) — **not** for the primary language/runtime recipes below. Several upstream installers *silently fall back to brew* if it's detected (see 9.6, 9.8) — this must be explicitly defeated where the "no-brew" policy applies to that recipe.
- Keep Homebrew's actual prefix at the default `/opt/homebrew` — installing to a custom prefix loses access to precompiled bottles and forces slow from-source builds for most formulae. If the user wants it to visually live under a custom apps folder, symlink, don't relocate.

### 9.2 JavaScript (Node / npm / pnpm / bun)
- **Node via nvm.** Official install script is version-pinned in its own URL; fetch the latest tag dynamically: `curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest` → `tag_name`, substitute into `https://raw.githubusercontent.com/nvm-sh/nvm/<tag>/install.sh`.
- **`nvm` is a shell function, not a binary — see §9.6.** This is the single most important gotcha for the automation engine.
- **pnpm** via official standalone script (`https://get.pnpm.io/install.sh`), respects a pre-set `PNPM_HOME`. Note: standalone script does not run on Intel Macs (n/a here — target is Apple Silicon only).
- **bun** via official script (`https://bun.sh/install`), respects a pre-set `BUN_INSTALL`.

### 9.3 Java
- **sdkman**, official script `https://get.sdkman.io`, respects a pre-set `SDKMAN_DIR`.
- **`sdk` is also a shell function — same category as nvm, see §9.6.**
- Gradle cache/home is shared with the React Native (Android) recipe via `GRADLE_USER_HOME` — model this as a shared dependency, not a duplicated path, so disk usage isn't double-counted.

### 9.4 Rust
- `rustup`, official script `https://sh.rustup.rs`, run non-interactively with `sh -s -- -y --default-toolchain stable`.
- Real executable — no shell-function issue. `RUSTUP_HOME` / `CARGO_HOME` control location.

### 9.5 Go
- No official version-manager needed: install one current toolchain directly from `https://go.dev/dl/?mode=json` (parse with `jq -r '.[0].version'` for latest), download `https://go.dev/dl/<version>.darwin-arm64.tar.gz`, extract.
- Set `GOTOOLCHAIN=auto` so Go's own built-in per-project toolchain switching (Go 1.21+, driven by `go.mod`) handles multi-version needs instead of a third-party version manager.
- Real executable, no shell-function issue.

### 9.6 Python
- `uv` (Astral), official script `https://astral.sh/uv/install.sh`. Respects `UV_CACHE_DIR`, `UV_TOOL_DIR`, `UV_PYTHON_INSTALL_DIR`, `UV_INSTALL_DIR` (uv/uvx binary location), `UV_TOOL_BIN_DIR` (installed tool shims).
- **Never touch or rely on the system `/usr/bin/python3` stub** (an Xcode CLT shim, not a real interpreter for dev use) — the app should not offer to "manage" it, only note its presence.
- Real executable, no shell-function issue.

### 9.7 Interactive-shell-required tools (critical engine note)
**`nvm` and `sdk` (sdkman) are POSIX shell functions sourced into the user's rc file — they are not standalone executables on `PATH`.** A subprocess call to `nvm install --lts` via `Process`/`NSTask` will fail (command not found), because there is no `nvm` binary — the function only exists inside a shell that has sourced `nvm.sh`.

Consequence for the execution engine: recipes for these tools must be flagged (e.g. `requiresInteractiveShell: true` in the schema) and executed via something like:
```
zsh -ic 'source "$NVM_DIR/nvm.sh" && nvm install --lts'
```
This is slower and noisier (oh-my-zsh/startup banners can leak into stdout) than a plain-binary `Process` call. Design the log-parsing/output-capture path to tolerate this noise, and prefer plain-binary tools (fnm, uv, rustup, rbenv) for anything the engine needs to drive *unattended*, where the user hasn't explicitly chosen a shell-function-based tool.

### 9.8 React Native support (Ruby / CocoaPods / Android)
- **Ruby via rbenv — do NOT use the official `rbenv-installer` script.** It auto-detects Homebrew and silently runs `brew install rbenv` if present, defeating the "no-brew for primary tooling" policy. Use direct git clone instead:
  ```
  git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
  git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
  ```
  `rbenv` itself (unlike nvm/sdkman) *is* a real executable once cloned — only the *installer script* has the brew fallback, not the tool itself.
- **CocoaPods**: `CP_HOME_DIR` env var relocates the repo/template directory; the separate `~/Library/Caches/CocoaPods` download cache has historically not always followed `CP_HOME_DIR` in every version — treat as best-effort, verify per CocoaPods version.
- **Android SDK**: `ANDROID_HOME` env var; the actual SDK path must still be entered manually in Android Studio's first-run setup wizard (no scriptable path here — flag as a manual step in the UI, not a "broken" recipe).

### 9.9 LunarVim (Neovim)
- **LunarVim's installer does not install Neovim.** On macOS, if Neovim is missing, it just prints an error suggesting `brew install neovim` and exits. To keep this brew-free, install Neovim independently first, from GitHub releases:
  ```
  curl -s https://api.github.com/repos/neovim/neovim/releases/latest → tag_name
  https://github.com/neovim/neovim/releases/download/<tag>/nvim-macos-arm64.tar.gz
  ```
- **The LunarVim install script URL is pinned to a release/neovim-compatibility branch** (e.g. `release-1.4/neovim-0.9`) that changes over time as new Neovim versions ship. Hardcoding it will go stale. The recipe for LunarVim should be marked as "verify install URL periodically" rather than assumed stable — this is a genuine maintenance burden the UI could surface (e.g. "last verified: <date>").
- Supports a `-y` flag for non-interactive dependency prompts; underlying npm/pip/cargo dependency installs will use whatever `node`/`python`/`cargo` are currently on `PATH` (i.e., the ones this app already manages) — no additional brew involvement expected, but not exhaustively verified for every optional LSP dependency.

### 9.10 Docker Desktop
- No pure-CLI, no-GUI-interaction install path exists for Docker Desktop itself. Scriptable portion: download `https://desktop.docker.com/mac/main/arm64/Docker.dmg` (stable "always latest" URL), `hdiutil attach`, copy `Docker.app` to `/Applications`, `hdiutil detach`.
- First launch (privileged helper install, license acceptance) is inherently manual/GUI — the app should launch Docker Desktop and stop there, not attempt to script past the OS-level permission prompt.
- Disk image / data location is configurable only through Docker Desktop's own Settings → Resources → Advanced — not independently scriptable; the app can deep-link or instruct, not automate this part.

### 9.11 Xcode-adjacent caches (not Xcode itself)
Xcode.app install/update is out of scope (App Store only). However, once installed, several of its data directories are safe to relocate and worth a recipe each:
- `~/Library/Developer/Xcode/DerivedData` — **official relocation exists**: `defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation <path>` (or Xcode → Settings → Locations GUI). Prefer this over symlinking.
- `~/Library/Developer/Xcode/Archives`, `iOS DeviceSupport`, `watchOS DeviceSupport`, `~/Library/Caches/org.swift.swiftpm` — no official relocation; safe via the standard move-then-symlink pattern (quit Xcode first).
- **Do NOT build a "relocate Simulator" feature.** Two separate reasons, both hard blockers, not preferences:
  1. Simulator device data (`~/Library/Developer/CoreSimulator/Devices`) has real-world reports of breaking when symlinked to a different volume/location — CoreSimulator's daemon is less tolerant of this than ordinary macOS apps.
  2. On current Xcode, the actual multi-gigabyte simulator **runtime images now live in `/System/Library/AssetsV2`**, which is SIP-protected — this cannot be moved, symlinked, or even `rm -rf`'d, by design, full stop.
  Instead, offer a "clean up simulator space" action that shells out to `xcrun simctl runtime delete <id>` and `xcrun simctl delete unavailable` — management via the supported CLI, not relocation.

### 9.12 AI Coding Agents
- **Claude Code**: official native installer is the currently-recommended method: `curl -fsSL https://claude.ai/install.sh | bash`. The older `npm install -g @anthropic-ai/claude-code` path is deprecated as of 2026 (still functions but shows deprecation warnings) — recipe should use the native installer. Config directory relocatable via `CLAUDE_CONFIG_DIR`; credentials are stored in macOS Keychain regardless (not something the recipe should try to relocate).
- **Codex CLI (OpenAI)**: `npm install -g @openai/codex` — note the scoped package name; the unscoped `codex` package on npm is an unrelated, wrong package, a common real-world install mistake worth guarding against in any recipe validation. Config dir relocatable via `CODEX_HOME`.
- **opencode**: `npm install -g opencode-ai`. Already follows the XDG base directory spec internally, so it inherits `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/etc. automatically without a dedicated env var — simplest recipe of the three.

### 9.13 macOS filesystem constraints (platform note, applies globally)
- The root volume (`/`) has been a sealed, read-only System volume since Catalina. The app must never assume it can create arbitrary top-level directories like `/development`; all managed paths live under `$HOME` (e.g. `~/development`, `~/apps`) by default.
- If a future feature wants a true top-level path, the only supported (non-SIP-disabling) mechanism is `/etc/synthetic.conf` (symlink/firmlink entries processed at boot) — this requires a reboot and root privileges and should be treated as an advanced/optional feature, not the default.

---

## 10. Data Model

### 10.1 Recipe (built-in or user-defined)

```json
{
  "id": "node-nvm",
  "displayName": "Node.js (nvm)",
  "category": "language",
  "detectCommand": "nvm --version",
  "currentVersionCommand": "nvm current",
  "installCommand": "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/{{latestTag}}/install.sh | bash",
  "updateCommand": "nvm install --lts && nvm alias default 'lts/*'",
  "uninstallCommand": null,
  "envVars": { "NVM_DIR": "$DEV_HOME/js/nvm" },
  "diskUsagePaths": ["$DEV_HOME/js/nvm"],
  "requiresInteractiveShell": true,
  "brewFallbackRisk": false,
  "sourcePinning": { "type": "github-latest-tag", "repo": "nvm-sh/nvm" },
  "lastVerified": "2026-07-14"
}
```

Fields of note:
- `requiresInteractiveShell` — drives which execution path the engine uses (§9.7).
- `brewFallbackRisk` — documents recipes whose *official* installer might invoke brew unexpectedly (§9.8); the app's own commands for that recipe should be the brew-free alternative, with this flag as a warning for anyone editing the recipe later.
- `sourcePinning` — how "latest" is resolved (GitHub latest release tag, a stable vendor URL, a specific pinned version) — used for the transparency/security requirement in §8.
- `lastVerified` — for recipes with known drift risk (LunarVim's branch-pinned URL), surfaced in the UI as a staleness indicator.

### 10.2 User Profile (backend-synced)

```json
{
  "userId": "gh_12345",
  "updatedAt": "2026-07-14T10:00:00Z",
  "environments": [
    { "recipeId": "node-nvm", "pinnedVersion": null, "customPath": null, "enabled": true }
  ],
  "customRecipes": [ ]
}
```

### 10.3 Sync/Conflict payload
On login, backend returns the user profile above; client diffs it against local state **per `recipeId`**, not as a single blob comparison, so unrelated recipes never trigger an unnecessary conflict prompt.

---

## 11. Backend (Bun + Hono)

### 11.1 Responsibilities
- GitHub OAuth (code exchange, session issuance as JWT).
- Serve the public default/curated recipe catalog (no auth) for guest mode.
- CRUD for authenticated user's profile (environments, pinned versions, custom recipes).
- Nothing else — no proxying of installer traffic, no execution of anything server-side. All installs run locally on the user's Mac.

### 11.2 Suggested stack
- Hono for routing/middleware (JWT auth middleware built-in).
- Bun as runtime.
- SQLite (via `bun:sqlite`) is sufficient at this scale; no need for a heavier DB for v1.
- Deploy target flexible given Hono's portability (Bun server, or Cloudflare Workers later if needed) — not a v1 decision that needs to be locked in.

### 11.3 Auth flow
1. Swift app opens `ASWebAuthenticationSession` pointed at the backend's `/auth/github` route.
2. Backend handles GitHub OAuth code exchange, issues a JWT, redirects back via a custom URL scheme.
3. Swift app stores the JWT in Keychain, attaches it to subsequent API calls.

### 11.4 Conflict resolution UX (expands FR7)
Do not implement a single "local vs. cloud, pick one" dialog. Implement a per-recipe diff list: only recipes where local and remote actually differ are shown, each with independent action buttons (Use local / Use cloud / Keep both as a variant / Delete). This should read like a short review list, not a modal blocking dialog with one global choice.

---

## 12. Local Persistence

- Location: `~/Library/Application Support/LazyEnvironment/`.
- Format: implementer's choice between SQLite (e.g. via GRDB.swift) and flat JSON files; given the modest scale (a few dozen recipes, one user profile), JSON files are simpler and sufficient — recommend starting there and only moving to SQLite if query complexity grows.
- Must never require network or login to read/write.

## 13. Rollout Plan (recommended phasing)

- **v0 (local-only MVP):** SwiftUI shell + hardcoded built-in recipes for the tools in §9 (no plugin abstraction yet, no backend). Validates the execution engine, especially the interactive-shell-required path (§9.7) and disk usage UI, which are the highest-risk/most novel parts.
- **v1 (extensibility):** Formalize the Recipe schema (§10.1), move built-in tools to recipe definitions, add the "add custom environment" UI/JSON editor.
- **v2 (accounts + sync):** Bun/Hono backend, GitHub OAuth, profile sync, per-recipe conflict resolution UX (§11.4).

Do not start v2 before v0/v1 are solid — the local engine and shell-execution quirks (§9.7, §9.8, §9.9) are the actual technical risk in this project; the backend is comparatively straightforward CRUD.

## 14. Open Questions

- Mac App Store distribution vs. notarized-outside-MAS — affects sandboxing and privileged operations (§9 generally). Recommendation: notarized-outside-MAS for v1, given the sandbox is incompatible with most of §9's operations.
- Should recipe execution ever require an explicit "review commands before running" confirmation step, beyond the always-visible log (§8)? Recommended yes, at least for first-run of any given recipe.
- Versioning/update strategy for the recipe catalog itself (e.g. LunarVim's branch drift, §9.9) — likely needs its own lightweight update mechanism independent of app releases (e.g. recipes fetched from the backend's public catalog even in local-only mode, so fixes don't require an app update).

## 15. Success Criteria

- A brand-new Mac can go from empty to "all built-in environments installed and correctly located" using this app plus the manual GUI-only steps that are inherently unscriptable (Docker Desktop first-launch, Android Studio SDK path, Xcode itself).
- `du`-verified disk usage numbers shown in the app match actual on-disk usage for each recipe's declared paths within a small margin.
- Signing in on a second Mac and syncing restores the same set of environments without silently clobbering anything already set up locally on that second machine.

---

## 16. Amendments (2026-07-14, requested by owner during implementation)

### 16.1 Privileged (admin) command execution — supersedes "no sudo anywhere"
Some operations legitimately require administrator rights (e.g. removing a root-owned `/usr/local/go`). Instead of excluding them, the app prompts for administrator credentials using the standard macOS authorization dialog:

- Recipes (and external-install candidates) can flag actions as requiring admin (`adminActions` on a recipe, `uninstallRequiresAdmin` on an external candidate).
- Flagged commands run via `/usr/bin/osascript -e 'do shell script "…" with administrator privileges'`, which triggers the system password prompt. No password ever touches the app.
- **Hard rule:** admin-flagged command strings must not rely on `$HOME`/`$DEV_HOME` at runtime (root's environment differs — `$HOME` becomes `/var/root`). The engine pre-expands those tokens to absolute paths before wrapping, and catalog authors should prefer absolute paths in admin commands.
- The command-review sheet clearly labels admin runs before execution (extends FR8).
- Homebrew's first bootstrap remains a manual Terminal step: its installer refuses to run as root, so `do shell script` wrapping is not applicable there.

### 16.2 External install detection, uninstall, and per-recipe install location (implemented)
- Recipes carry `externalCandidates`: known standard locations (`~/.nvm`, `~/.bun`, `~/.rustup`+`~/.cargo`, `/usr/local/go`, `~/Library/Android/sdk`, Homebrew, …). If the managed location is absent but a candidate matches, the recipe shows **Installed (external)** with the real path, version, and disk usage.
- External installs expose an uninstall targeting the detected location (tool-native uninstallers preferred: `rustup self uninstall`, `brew uninstall <formula>`), always behind the command-review sheet. Candidates without a safely determinable uninstall (unknown manager) expose none.
- A per-recipe custom base path can override the global dev home for install/detect/disk-scan (persisted as `customDevHome`). Relocation of existing installs was considered and rejected by the owner in favor of "solid uninstall + correct install path".

### 16.3 Menu bar resident mode, launch at login, app icon
- **Menu bar agent:** a status-bar item (icon only) is always available. Left click opens a compact summary popover: counts by status (installed / external / not installed), total managed disk usage, last scan time, and a "Show Details" button that opens the full main window. Right click opens a context menu: Open, Settings…, Quit.
- **Launch at login:** toggle in Settings backed by `SMAppService.mainApp` (macOS 13+). When "start in menu bar" is enabled, the app launches without showing the main window and without a Dock icon (`NSApplication.ActivationPolicy.accessory`); opening the main window switches the Dock icon back on, closing it returns to accessory mode.
- **App icon:** bundled asset catalog icon (macOS squircle, gradient + shippingbox glyph); the status-bar item uses a template SF Symbol so it adapts to menu bar appearance.
