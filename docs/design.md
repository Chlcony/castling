# Design

How the patch is built and why. Read this before changing behaviour; most of
the choices that look odd have a reason here.

## Footprint

A patch set has two files. `01-displays.patch` adds four files to Vorssaint
and edits one:

| File | Role |
|---|---|
| `Services/Display/DisplayArrangementSupport.swift` | Pure logic: presets, matching, geometry, storage. No AppKit, so it can be tested on its own. |
| `Services/Display/DisplayArrangementService.swift` | Reads the live displays and reconfigures them. |
| `Services/Display/DisplayArrangementStrings.swift` | Every string, in every language Vorssaint ships. |
| `UI/MenuPanel/ArrangementStrip.swift` | The strip of thumbnails, and the star. |
| `UI/MenuPanel/BrightnessSection.swift` (edited) | Hosts the strip and the star, turns on the section's edit pill, starts the service. |

Every other upstream file this feature could have touched is a conflict
waiting for the next release. That is why:

- **The preference key lives in the service**, not in `Core/Defaults.swift`.
  Its string is `displayArrangementPresets`; never change it, or saved
  arrangements are lost.
- **The service starts when the Displays section appears**, not at app launch
  from `FeatureRuntime.swift`.
- **The strings file sits beside the service**, not in `Core/`. Upstream's test
  generator collects `Core/*Strings.swift` into its test build, where this file
  would not compile.
- **Tests live in this repository** (`tests/`), not in upstream's `Tests/`,
  which upstream compiles wholesale into its test build.
- **Saved arrangements are not in settings backups**, because that list lives
  in `Core/SettingsBackupSupport.swift`.
- **The Displays tab follows upstream's own rule**: it appears only while
  brightness controls are on.

## Arrangements and the main display are independent

In CoreGraphics the main display is the one at (0,0), so a set of display
origins carries both the arrangement and which display is main. Stored as is,
the two controls would fight: starring a display shifts every origin so no
preset matches any more, and applying a preset drags the main display back to
wherever it was at save time.

So **a preset is a shape, not a position**:

- Comparison normalises both layouts to their bounding-box corner, so a
  translation is not a difference. Starring keeps the highlight.
- `apply` translates the stored shape so the *current* main display stays at
  (0,0). Applying a preset moves screens and never changes the main display.
- A preset that does not include the current main display is applied as saved.

The cost: "same layout, different main display" cannot be saved as two
presets. The main display is one sticky choice, made with the star.

## Reconfiguring displays

- **One transaction per arrangement.** All origins go into a single
  `CGBeginDisplayConfiguration` … `CGCompleteDisplayConfiguration`. Applied one
  display at a time, macOS closes the gaps after each move and the layout lands
  somewhere nobody saved.
- **Main thread only.** CoreGraphics runs reconfiguration callbacks inline on
  the calling thread, and those callbacks are AppKit's. Off the main thread it
  deadlocks (upstream issue #747). Every entry point checks.
- **Never ask the display server from a SwiftUI body** (upstream issue #969).
  The service publishes `mainDisplayID` and `mainDisplayKey`; views read those.
- **Permanent configuration**, the same as System Settings writes.
- **Displays are keyed by UUID**, not `CGDirectDisplayID`, which can change
  between boots. Mirrored displays are skipped: they follow their source.
- **Untrusted input is validated.** A preset with an origin outside Int32, or
  fewer than two displays, is dropped at decode; placement also clamps, so a
  bad value can never trap.
- **Screen-change notifications are coalesced** (0.1 s), since one change
  arrives as a burst and applying an arrangement triggers one itself.

## Panel behaviour

- The strip and the star appear only with two or more displays connected. With
  nothing saved and not editing, the section looks exactly like upstream's.
- At most 10 presets: past that, a row of thumbnails stops being something you
  can pick from at a glance.
- An apply failure is cleared when the strip reappears and when editing
  toggles, so an old error never describes a problem that is gone.
- The edit affordance is upstream's standard `slider.horizontal.3` pill.
- **Every display gets a star**, including one Vorssaint cannot adjust, such
  as Sidecar. Upstream lists only displays with a brightness route, so the
  patch adds a row of its own for the rest: the same layout, with a faded
  disabled slider and a tooltip saying brightness can't be adjusted there. These rows
  appear only with two or more displays connected.

## Colour

Follow the rule upstream uses for its section tabs:

| | Menu bar panel | Dynamic Island |
|---|---|---|
| Not selected | `Color.secondary` | same |
| Selected thumbnail, filled star | `Color.accentColor` | `Color.white` |
| Selected container | accent at 0.13 light / 0.20 dark | white at 0.12 |

The accent is deliberately absent inside the Dynamic Island, which always
renders dark. The delete badge takes a fixed fill per colour scheme (dark in
light mode, light in dark mode), never `Color.primary`, so it contrasts in
every surface.

Check every visual change in the light panel, the dark panel and the Dynamic
Island.

## The update hook

`02-update-hook.patch` makes Vorssaint's own update banner Castling's update
path. It adds `Services/Update/CastlingUpdates.swift` (the app side) and
`CastlingUpdateSupport.swift` (the pure filter, tested in `tests/`), and edits
`Services/Update/UpdateService.swift` in two places:

1. **The filter, in `check(manual:)`.** Before Vorssaint picks a release to
   offer, every release Castling's `supported.json` doesn't list as
   `supported` is dropped. If the list can't be read (offline, GitHub down),
   nothing is offered and the check reports a failure rather than "up to
   date": an update that silently removes Castling is worse than one that
   arrives an hour later.
2. **The redirect, at the top of `downloadAndInstall()`,** the Update
   button's one entry point. Instead of downloading the official DMG, it runs
   Castling's installer for that version and shows "Installing…". The
   installer builds the patched app, replaces this one and relaunches it.

Why it's shaped this way:

- **Not in `UpdateServiceSupport.swift`.** That file is compiled into
  upstream's test build (`build.sh` `TEST_SOURCES`), where Castling's code
  would not compile.
- **Its own `URLSession`, never `URLSession.shared`.** The filter runs inside
  the release check's shared-session callback and waits for `supported.json`.
  A request on the shared session would be answered on the queue that wait is
  holding: a deadlock that left "Checking…" spinning forever and stalled every
  other shared-session request in the app.
- **The installer runs detached,** through a shell that exits at once, so the
  app is not its ancestor. Upstream's `build.sh --install` quits the running
  app with `pkill`, which never matches its own ancestors; started directly,
  the old app survived the update and kept showing "Installing…".
- **Failure is noticed by polling.** A detached installer can't report back,
  so the app checks every few seconds whether it is still running. If it has
  stopped and this app is still alive, the update failed (success replaces
  and relaunches the app): it posts a notification and offers the update
  again.
- **Where the installer lives** is recorded by `install` in
  `~/Library/Application Support/castling/installer`, so the button works
  wherever Castling was cloned. The installer's output goes to `update.log`
  beside it.
- **Testing a release under review:**
  `defaults write com.vorssaint.utils castlingCandidate -int <PR>` points both
  the filter and the installer at that pull request.
- **Betas** follow Vorssaint's own beta setting, but only versions in
  `supported.json` are ever offered.
