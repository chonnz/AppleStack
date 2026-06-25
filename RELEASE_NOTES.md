# AppleStack 0.1.0 Release Notes

AppleStack 0.1.0 is the first release candidate for a native macOS client around Apple's `container` CLI. It focuses on making common Apple container workflows usable without memorizing commands while keeping the underlying CLI behavior transparent.

## Highlights

- Quick Start screen with guided actions for starting the runtime, creating containers, creating Linux machines, and opening Activity Monitor.
- Visual management for containers, images, volumes, networks, Linux machines, registries, system status, builder status, and common command examples.
- Built-in terminal and log views for running containers and machines.
- English and Simplified Chinese interface text for primary workflows.
- Safer release behavior:
  - Unimplemented framework backend requests now fall back to the CLI backend instead of crashing.
  - Missing Apple container CLI errors now explain the installation or Settings > CLI path fix.
  - Kill and prune actions require confirmation before they run.
  - The app bundle build script now packages the release executable.

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
```

`scripts/build-app.sh` builds with `swift build -c release` and places the app bundle at `build/AppleStack.app`.

## Verification

The release candidate has been checked with:

- `swift test`
- `scripts/build-app.sh`
- Manual smoke testing of the main navigation pages and non-destructive create/settings dialogs.

## Known Limitations

- The app is not signed or notarized yet.
- AppleStack depends on the installed Apple `container` CLI; CLI behavior and supported subcommands may vary by installed version.
- FrameworkBackend is not implemented in this release; the app intentionally uses CLIBackend.
- The app currently provides a local app bundle build, not a packaged `.dmg` or installer.
