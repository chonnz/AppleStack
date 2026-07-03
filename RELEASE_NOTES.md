# AppleStack 0.1.0 Release Notes

AppleStack 0.1.0 is the first release candidate for a native macOS client around Apple's `container` CLI. It focuses on making common Apple container workflows usable without memorizing commands while keeping the underlying CLI behavior transparent.

## Highlights

- Quick Start screen with guided actions for starting the runtime, creating containers, creating Linux machines, and opening Activity Monitor.
- First-launch guidance now points new users to the `container` CLI path, system runtime status, and Quick Start flow before creating resources.
- Visual management for containers, images, volumes, networks, Linux machines, registries, system status, builder status, and common command examples.
- Built-in terminal and log views for running containers and machines.
- The release DMG includes `AppleStack.app`, an `Applications` drag target, and `First Open.txt` with the unsigned first-open and CLI path notes.
- English and Simplified Chinese interface text for primary workflows.
- Safer release behavior:
  - Changing the `container` CLI path in Settings now refreshes the active backend without relaunching AppleStack.
  - Linux machine quick create now performs preflight checks, shows useful progress logs, and offers retry/continue actions after failures.
  - Unimplemented framework backend requests now fall back to the CLI backend instead of crashing.
  - Missing Apple container CLI errors now explain the installation or Settings > CLI path fix.
  - Kill and prune actions require confirmation before they run.
  - The app bundle build script now packages the release executable and creates `build/AppleStack.dmg`.

## Requirements

- macOS 15 or later.
- Apple silicon is recommended.
- Xcode command line tools or Xcode with Swift 6 support.
- Apple's `container` CLI installed and reachable from `PATH`, or configured in AppleStack Settings > CLI.

## Build

```bash
swift test
scripts/build-app.sh
open build/AppleStack.app
open build/AppleStack.dmg
```

`scripts/build-app.sh` builds with `swift build -c release`, places the app bundle at `build/AppleStack.app`, and creates a drag-to-Applications disk image at `build/AppleStack.dmg`.

## Verification

The release candidate has been checked with:

- `swift test`
- `scripts/build-app.sh`
- Manual smoke testing of the main navigation pages and non-destructive create/settings dialogs.

## Known Limitations

- The app is not signed or notarized yet.
- AppleStack depends on the installed Apple `container` CLI; CLI behavior and supported subcommands may vary by installed version.
- FrameworkBackend is not implemented in this release; the app intentionally uses CLIBackend.
- The app is distributed as an unsigned `.dmg`; there is no installer package yet.
