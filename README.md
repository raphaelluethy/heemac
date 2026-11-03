# heemac

A tiny macOS menu bar app that moves keyboard focus to the nearest visible
window in a direction.

| Hotkey | Action |
| --- | --- |
| ⌃⌥⇧⌘H | Focus window to the left |
| ⌃⌥⇧⌘J | Focus window below |
| ⌃⌥⇧⌘K | Focus window above |
| ⌃⌥⇧⌘L | Focus window to the right |

With Raycast's Hyper Key (Shift not included) that is Hyper+Shift+H/J/K/L.

The menu bar mascot glances toward where focus went and blinks when there is
nowhere to go.

## Panes

In Rex, the hotkeys first move between panes of the current Rex window (via the
`rex` CLI) and only jump to the next window at the layout edge, like
vim-tmux-navigator. Turn it off with
`defaults write io.github.raphaelluethy.heemac paneNavigation -bool false`; point
it at a different `rex` binary with `defaults write ... rexPath /path/to/rex`.

## Which windows count

- Normal windows and dialogs on the current Spaces, on every display.
- A window must be at least 5% visible. Windows fully covered by other apps'
  windows are skipped.
- Windows of the same app stacked at exactly the same frame count as one. Some
  apps (for example Rex) draw an overlay window above the real one; tools that
  treat that overlay as an occluder can never focus the app.
- Windows that share a row (left/right) or column (up/down) with the current
  window win over closer ones that don't. The screen edge is a dead end.

## Install

Requires macOS 14+ and Xcode command line tools.

```sh
make install   # builds, signs, copies to /Applications and launches
```

Grant Accessibility access when asked (System Settings → Privacy & Security →
Accessibility). Toggle "Open at Login" from the menu bar icon, or with
`Heemac --login on|off|status`.

`make icon` re-renders `Resources/AppIcon.icns` from `scripts/make-icon.swift`.

The build signs with your first "Apple Development" identity so the
Accessibility grant survives rebuilds; override with `SIGN_IDENTITY=...`.

## CLI

```sh
/Applications/Heemac.app/Contents/MacOS/Heemac --windows      # candidate windows, * = focused
/Applications/Heemac.app/Contents/MacOS/Heemac --focus left   # one-shot move
/Applications/Heemac.app/Contents/MacOS/Heemac --login status  # open at login: on/off
```

Decisions are logged:

```sh
log stream --info --predicate 'subsystem == "io.github.raphaelluethy.heemac"'
```

## Settings

```sh
defaults write io.github.raphaelluethy.heemac minVisibleFraction -float 0.1
```

## How it works

Window list and stacking order come from `CGWindowListCopyWindowInfo`; window
types and focus use the Accessibility API. Focusing a specific window uses the
same SkyLight calls as AltTab (`_SLPSSetFrontProcessWithOptions` plus a
key-window event), then raises it via Accessibility and verifies the switch.
