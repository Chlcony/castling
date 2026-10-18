# Castling

*In chess, castling is the one move where two pieces swap places and the king
relocates.*

Castling is an **unofficial** patch for [Vorssaint](https://github.com/vorssaint/vorssaint-utils)
that adds two things to its Displays section:

- **Saved display arrangements.** A strip of to-scale thumbnails, one per saved
  layout. Click one to move your screens back into it. Click the edit pill to
  save the current layout or delete one.
- **A main-display star** beside every display. Click a hollow star to make
  that display main without moving any screen, the same setting as System
  Settings › Displays › *Use as: Main display*.

The two are independent: applying an arrangement never changes your main
display, and starring a display never changes the arrangement.

Castling is not affiliated with or endorsed by Vorssaint. See [NOTICE.md](NOTICE.md).

> [!IMPORTANT]
> **Vorssaint's update banner offers a new version only once Castling supports
> it.** That is usually soon after its release, but it can take days when the
> patch needs porting. Click **Update** and Castling rebuilds the patched app.
> If you need an upstream fix right away, `~/castling/uninstall` brings back
> the official app.

## Compatibility

<!-- compat:start -->
| Vorssaint | Status |
|---|---|
| 3.4.1 | supported |
<!-- compat:end -->

Any other version: `./install` tells you it isn't supported and changes
nothing. Vorssaint betas aren't supported.

## Install

You need macOS 14 or newer on an Apple Silicon Mac. Castling builds Vorssaint
on your own Mac; nothing prebuilt is downloaded from this repository.

Paste this into Terminal:

```sh
git clone https://github.com/Chlcony/castling.git ~/castling && ~/castling/install
```

If macOS offers to install the command line developer tools, accept, wait for
them to finish, and paste the line again.

`install` builds the version of Vorssaint you already have (or the newest
supported one if you have none), or a specific one with `~/castling/install 3.4.1`. It:

1. checks that Vorssaint's source matches the exact commit this patch was
   reviewed against, and stops if it doesn't;
2. applies the patch, runs its tests, builds, and self-tests the result;
3. backs up your current app to `~/Library/Application Support/castling/backups/`
   (keeping the three newest) and puts it back if anything fails;
4. keeps all your Vorssaint settings;
5. explains the one permissions step below.

It never uses `sudo`. A build takes a few minutes.

### Permissions, once

The app you build is signed on your Mac, not by Vorssaint's maintainer, so macOS
treats it as a new app. Permissions you gave the official app still *look*
granted in System Settings but no longer apply. `install` offers to clear them;
then grant Accessibility and Screen & System Audio Recording again. Later
updates keep them.

## Update

When Castling supports a new Vorssaint release, Vorssaint's own update banner
offers it. Click **Update**: Castling rebuilds the patched app in the
background, which takes a few minutes, and Vorssaint restarts as the new
version. You can also update from Terminal:

```sh
~/castling/install
```

## Go back to the official app

```sh
~/castling/uninstall
```

This downloads the official, maintainer-signed Vorssaint of the same version
from Vorssaint's own releases, verifies its signature and installs it. Your
settings are kept.

## Contributing

Castling isn't accepting code contributions at the moment, but suggestions are
welcome: [open an issue](https://github.com/Chlcony/castling/issues) to report a
problem or propose an idea.

## License

[GPL-3.0-or-later](LICENSE), because the patch is derived from Vorssaint, which
is GPL-3.0-or-later.
