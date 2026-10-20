# Castling — instructions for agents

Castling is an unofficial patch for [Vorssaint](https://github.com/vorssaint/vorssaint-utils)
that adds saved display arrangements and a main-display star to its Displays
section. This repository ships the patch as source; users build it on their own
Mac with `./install`.

Design rules and their reasons: `docs/design.md`. Open bugs: `docs/bugs.md`.

## Hard rules

- **Never publish a built app or DMG.** Upstream's `TRADEMARKS.md` forbids
  redistributing builds that carry the Vorssaint name, icon, bundle id
  `com.vorssaint.utils` or update feed. Patches and build scripts only.
- **License: GPL-3.0-or-later.** The patch derives from GPL-3.0-or-later code.
- **Never merge.** Agents open pull requests; the owner tests and merges every
  release. This code reconfigures physical displays. The one exception is the
  watcher's own `AUTO_PUBLISH_CLEAN` switch, which only the owner turns on: it
  publishes a port that fit unchanged with every check passed. Anything an AI
  touched always waits for the owner.
- **No release while `docs/bugs.md` lists an open bug.** A PR that marks a
  version `supported` stays a draft until the list is empty.
- **Do not contact upstream.** No issues, PRs or comments on
  vorssaint/vorssaint-utils.
- **Patches, not merge branches.** Upstream has rewritten its history. Apply
  onto a release tag with `git am -3`. A patch set lives in `patches/cl-<date>/`,
  named after the day it was made (`cl-2026-10-18`; add `.2` for a second set
  the same day). Inside a set, one file per area of Vorssaint the patch
  changes, numbered in the order they apply and named after the area:
  `01-displays.patch` (the Displays section), later `02-update-hook.patch`.
  Versions it fits unchanged reuse it: `supported.json` says which set each
  version uses. Add a new set only when the patch itself has to change.
- **Versions:** release tags are `<upstream>+<patch set>` (e.g.
  `3.4.1+cl-2026-10-18`), written by `release.yml` when the owner merges.
  Everything after `+` is ignored by Vorssaint's updater; never put the patch
  name after a `-` instead, which it reads as a pre-release of an older
  version. Never change the app's own version string.
- **Minimal footprint.** Add files freely, but edit only
  `Sources/Vorssaint/UI/MenuPanel/BrightnessSection.swift` upstream (later also
  two hooks in `Sources/Vorssaint/Services/Update/UpdateService.swift`). Never
  put patch code in a file upstream compiles into its test build (`build.sh`
  `TEST_SOURCES`). Every other upstream file touched is a future conflict.
- **Never commit secrets, email addresses or chat ids.** Credentials live in
  repository secrets.

## Code follows Vorssaint's conventions

The patch must read as if upstream wrote it. Re-read upstream's
`CONTRIBUTING.md` and `docs/AI-CONTRIBUTIONS.md` at the target tag on every
port; they change. In short:

- Behaviour in `Sources/Vorssaint/Services/`, SwiftUI views only in
  `Sources/Vorssaint/UI/`. Services never import SwiftUI.
- Singletons as `Type.shared`, `ObservableObject` with Combine, no Observation
  macros.
- Comments explain why, not what, and are rare.
- No new dependencies.
- Every user-facing string exists in every supported language.
- Match the style of the file being edited.
- Commit titles `type(scope): lowercase imperative phrase`, reusing upstream
  scopes.

**The one allowed deviation:** the patch keeps its own strings file beside its
service instead of editing `Core/Localization.swift`, to keep the footprint.

## Building and verifying

- Build upstream with `./build.sh` only; `swift build` does not work there.
- Every build recompiles ~530 files (2–3 minutes). Batch changes.
- `tools/watch/try-port <version>` runs all of the following on a fresh clone.
- A port is verified when, on a fresh clone at the target tag:
  1. `git am -3 patches/<set>/*.patch` applies with zero conflicts;
  2. `./build.sh` finishes without warnings;
  3. `./build.sh --test` passes (upstream's `switcher` tests depend on the
     connected displays; compare against a clean upstream run before blaming
     the patch);
  4. the patch's own tests pass;
  5. `build/stage/Vorssaint.app/Contents/MacOS/Vorssaint --selftest` prints
     `SELFTEST OK`;
  6. `git diff <tag> --stat` lists only the patch's new files and the allowed
     upstream files.
- Tests cannot see the menu bar panel. Every PR that changes UI lists the
  visual checks for the owner: light panel, dark panel and Dynamic Island;
  save, apply and delete an arrangement; starring makes that display main and
  keeps the highlight; applying an arrangement never changes the main display.

## The update hook

`02-update-hook.patch` reroutes Vorssaint's update banner through Castling;
`docs/design.md` explains it. When porting it:

- It may only touch `Services/Update/UpdateService.swift`: the filter in
  `check(manual:)` and the redirect at the top of `downloadAndInstall()`.
  Everything else goes in `CastlingUpdates.swift`, and logic that needs no
  AppKit in `CastlingUpdateSupport.swift`, which `tests/` compiles. Never edit
  `UpdateServiceSupport.swift`, which upstream compiles into its test build.
- Keep `CastlingUpdates` on its own `URLSession`, and keep launching the
  installer detached. Both fix real hangs; the design doc says why.
- If upstream reworks its updater so the two hooks no longer fit, rework the
  hook to fit the new code: the same behaviour (offer only supported
  versions, nothing when the list can't be read; Update runs Castling's
  installer), still only in `UpdateService.swift`. If it can't fit there,
  stop and explain in the PR; the owner decides.

## Porting to a new upstream release

1. Clone upstream at the release tag; apply the latest patch set with `git am -3`.
2. Resolve conflicts within the rules above. If a fix would need another
   upstream file, stop and say so in the PR instead.
3. Run the full verification.
4. If the patch had to change, export it with `git format-patch` as a new set,
   `patches/cl-<today>/`; if not, reuse the existing set. Add the version to
   `supported.json` (`tools/watch/try-port <version> [--patches <set>] --export`
   does this), and open a PR describing what upstream changed and what you
   changed and why.
5. Never merge.
