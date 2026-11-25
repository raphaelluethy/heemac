# Heemac

Heemac is a macOS menu bar app that moves keyboard focus to a visible window in the direction you press, across displays and without moving or resizing windows.

| Shortcut | Focus |
| --- | --- |
| ⌃⌥⇧⌘H | Left |
| ⌃⌥⇧⌘J | Down |
| ⌃⌥⇧⌘K | Up |
| ⌃⌥⇧⌘L | Right |

With Raycast configured to use a Hyper Key that excludes Shift, use Hyper+Shift+H/J/K/L. The menu bar mascot glances in the chosen direction and blinks when there is no target. The menu lists any shortcuts that couldn't be registered.

## Install from source

Requires macOS 14 or later and Xcode or its Command Line Tools with Swift 6.0 or later. Rex and Raycast are optional.

```sh
git clone https://github.com/raphaelluethy/heemac.git
cd heemac
make install
```

`make install` builds the app, replaces any existing `/Applications/Heemac.app`, and launches it. If you can't write to `/Applications`, run `make app` and copy `build/Heemac.app` into `~/Applications` yourself.

Grant **Heemac** access in **System Settings → Privacy & Security → Accessibility** so it can identify and focus other apps' windows. Use **Open at Login** in Heemac's menu if desired.

The build uses the first available Apple Development signing identity, falling back to ad hoc signing. Set `SIGN_IDENTITY` to choose an identity or `-` to force ad hoc signing. A stable identity helps preserve the Accessibility grant across rebuilds; if access stops working after a rebuild, remove the old entry and grant access to the new app.

To uninstall, turn off **Open at Login**, quit Heemac, delete the app, and remove its Accessibility entry.

## How navigation works

- Normal windows and dialogs on the current Spaces are eligible, including those on other displays. Heemac does not switch Spaces or wrap around screen edges.
- By default, at least 5% of the window's on-screen area must be uncovered. Same-app windows stacked at approximately the same frame are grouped so overlays don't hide their own window.
- Windows in the same row or column are preferred over closer diagonal windows.
- In Rex, Heemac tries to focus a pane via the `rex` CLI before falling back to another window. At the pane layout edge, or if the CLI is unavailable, window navigation still works.

Heemac gets window geometry from Core Graphics and uses Accessibility and private macOS APIs (including SkyLight) to focus windows. Because these APIs aren't supported by Apple, a macOS update can break focus behavior. Heemac processes window information locally and does not send telemetry.

## Settings and diagnostics

```sh
# Require 10% visibility instead of the default 5%.
defaults write io.github.raphaelluethy.heemac minVisibleFraction -float 0.1

# Disable Rex pane navigation, or point Heemac at a specific Rex executable.
defaults write io.github.raphaelluethy.heemac paneNavigation -bool false
defaults write io.github.raphaelluethy.heemac rexPath -string /path/to/rex
```

Use `defaults delete io.github.raphaelluethy.heemac <setting>` to restore a default.

```sh
HEEMAC=/Applications/Heemac.app/Contents/MacOS/Heemac
"$HEEMAC" --windows       # window diagnostics; * marks the focused candidate
"$HEEMAC" --focus left    # one-shot move: left, right, up or down
"$HEEMAC" --login status  # also accepts on or off

log stream --info --predicate 'subsystem == "io.github.raphaelluethy.heemac"'
```

Diagnostic output can include app names, window IDs, and window geometry. Review it before sharing.

## Development and releases

```sh
make check SIGN_IDENTITY=-  # build the app, run tests, and verify the bundle
make run                    # launch the local build
make icon                   # regenerate Resources/AppIcon.icns
make zip SIGN_IDENTITY=-    # produce build/Heemac.zip for local testing
```

CI runs `make check` on macOS. Before tagging a release, update both version fields in [`Resources/Info.plist`](Resources/Info.plist) and manually test Accessibility setup, the four shortcuts, same-app window switching, and optional Rex pane navigation in a logged-in macOS session. The automated tests cover geometry and visibility, not live focus or permissions.

The local ZIP targets the build machine's architecture and is **not notarized**. For public binary distribution, sign with a Developer ID Application identity, notarize and staple the app, and regenerate the ZIP from that bundle. Publish the corresponding source alongside the binary.

## License

Copyright © 2026 Raphael Lüthy. Heemac is licensed under the [GNU General Public License v3.0 only](LICENSE) (`GPL-3.0-only`). See [third-party notices](THIRD_PARTY_NOTICES.md) for upstream credits and license terms.
