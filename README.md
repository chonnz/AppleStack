# AppleStack

[简体中文](README.zh-CN.md)

## Releases

[Download latest release](https://github.com/chonnz/AppleStack/releases)


AppleStack is a native macOS app for managing Apple's open source [`container`](https://github.com/apple/container) CLI from a visual desktop interface. It keeps the power of the command line, but turns daily container, image, volume, network, Linux machine, registry, monitoring, and diagnostic workflows into clickable macOS screens.

AppleStack is not an Apple product. It is an independent open source client built on top of Apple's `container` command line tool.

## What It Does

- **Manage containers**: create, start, stop, restart, kill, delete, inspect, view logs, open terminals, copy files, and export filesystems.
- **Manage images**: pull, build, load, tag, push, save, inspect, group by usage, and remove local images.
- **Work with storage and networks**: create, inspect, search, prune, and delete volumes and networks.
- **Create Linux machines**: build ready-to-use Linux machines from presets, configure CPU, memory, and home folder access, then open logs, files, terminals, and inspect output.
- **Use registries**: review registry login state, log in, and log out.
- **Monitor resources**: view live CPU, memory, network, and disk usage for containers and machines.
- **Run common commands faster**: copy ready-to-run `container` command examples from the built-in command reference.
- **Control the runtime from macOS**: use the main window or menu bar utility to check status and start or stop the Apple container system.

## Who It Is For

- Developers who use Apple `container` and want a faster local desktop workflow.
- Teams evaluating Apple's container stack on macOS and Apple silicon.
- Engineers who remember Docker Desktop or OrbStack-style workflows and want similar navigation for Apple `container`.
- Users who can run container commands, but prefer visual status, guided forms, and safer destructive actions.
- People helping less technical teammates use local containers without teaching every CLI subcommand first.

## Highlights

- **Native macOS UI**: SwiftUI app with sidebar navigation, compact toolbars, menu bar access, keyboard shortcuts, system sheets, and light/dark mode support.
- **Beginner-friendly path**: Quick Start helps users check the CLI path, start the runtime, create the first container or Linux machine, and open resource monitoring.
- **Operational safety**: destructive actions use confirmation dialogs, long image and machine operations show progress, and runtime connection errors offer retry/start-system actions.
- **Machine-first support**: Linux machine creation includes system presets, resource presets, default-machine options, logs, files, terminals, and inspect views.
- **CLI-compatible design**: AppleStack calls the local `container` executable, so behavior remains close to the official CLI and is easier to test.
- **Bilingual interface**: English and Simplified Chinese are available in Settings.

## Requirements

- macOS 15 or later.
- Xcode Command Line Tools or Xcode with Swift 6 support.
- Apple's [`container`](https://github.com/apple/container) CLI installed.
- Apple silicon is recommended because Apple's container stack is optimized for it.

## Install Apple Container

Install the `container` CLI from Apple's official project:

- GitHub: <https://github.com/apple/container>
- Documentation: <https://apple.github.io/container/documentation/>

Verify the CLI after installation:

```bash
container system status
```

If `container` is installed outside your shell `PATH`, open AppleStack Settings and set the CLI path manually.

## Deploy Locally

Clone the repository:

```bash
git clone <repo-url>
cd AppleStack
```

Build the Swift package:

```bash
swift build
```

Create a runnable macOS app bundle:

```bash
scripts/build-app.sh
```

Open the app:

```bash
open build/AppleStack.app
```

Run the test suite:

```bash
swift test
```

## How To Use

1. Open AppleStack and go to **Settings > CLI** if the `container` executable is not found automatically.
2. Use **Quick Start** to start the Apple container runtime.
3. Create a container, pull an image, or create a Linux machine from the sidebar or Quick Start cards.
4. Select an item in a list to inspect details, logs, files, terminal access, stats, and raw CLI output.
5. Use **Activity Monitor** to watch live resource usage.
6. Use the menu bar item for quick status checks and runtime/container controls.

## Project Structure

```text
Sources/AppleStack/
  Models/          Data models for containers, images, networks, machines, stats, and configs
  Services/        CLI execution, backend protocol, terminal session, and shared environment keys
  ViewModels/      Observable state for containers, images, system status, and logs
  Views/           SwiftUI views grouped by feature area
Tests/             Swift Testing test suites
Resources/         App bundle metadata
scripts/           Local build scripts
```

## Development

AppleStack talks to the local `container` CLI instead of linking directly to Apple container internals. Prefer small SwiftUI changes, exact CLI argument tests, and source-level checks for user-facing workflows.

Common development commands:

```bash
swift test
scripts/build-app.sh
open build/AppleStack.app
```

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for the current release scope, verification checklist, and known limitations.

## License

AppleStack is released under the MIT License. See [LICENSE](LICENSE).
