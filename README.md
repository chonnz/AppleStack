# AppleStack

[简体中文](README.zh-CN.md)

AppleStack is a native macOS desktop app for managing Apple's open source [`container`](https://github.com/apple/container) CLI with a visual workflow inspired by OrbStack. It provides a focused GUI for containers, images, volumes, networks, Linux machines, registries, live resource monitoring, and common Apple container commands.

AppleStack is not an Apple product. It is an independent open source client built on top of Apple's `container` command line tool.

## Features

- **Containers**: list, create, start, stop, restart, kill, delete, inspect, view logs, open terminals, copy files, and export filesystems.
- **Images**: pull, build, load, tag, push, save, inspect, group by usage, and delete images.
- **Volumes and networks**: create, inspect, delete, prune, and search local resources.
- **Linux machines**: create, start, stop, delete, inspect, view logs, configure CPU/memory/home mount, and build machine-oriented images.
- **Registry management**: view registry logins, log in, and log out.
- **Activity Monitor**: view container and machine resource rows with live CPU, memory, network, and disk charts.
- **System dashboard**: check runtime status, disk usage, logs, DNS, properties, kernel settings, and builder status.
- **Commands reference**: copy ready-to-run `container` command examples for common workflows.
- **Menu bar utility**: monitor runtime status and quickly start/stop containers or the Apple container system.
- **Internationalization**: English and Simplified Chinese, switchable in Settings.

## Requirements

- macOS 15 or later.
- Xcode command line tools or Xcode with Swift 6 support.
- Apple's [`container`](https://github.com/apple/container) CLI installed.
- Apple silicon is recommended because Apple's container stack is optimized for it.

## Install Apple container

Install the `container` CLI from Apple's official project:

- GitHub: <https://github.com/apple/container>
- Documentation: <https://apple.github.io/container/documentation/>

After installation, verify that the CLI is available:

```bash
container system status
```

If `container` is installed outside your shell `PATH`, open AppleStack Settings and set the CLI path manually.

## Build and Run

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

Run tests:

```bash
swift test
```

## Settings

AppleStack currently supports these settings:

- Interface language: English or Simplified Chinese.
- Apple Containers CLI path.
- Container list behavior, including whether stopped containers are shown by default.
- List refresh interval.
- Terminal font size.
- System controls for runtime status, DNS, kernel path, logs, properties, and builder state.

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

## Development Notes

AppleStack talks to the local `container` CLI instead of linking directly to Apple's container internals. This keeps the app simple and makes CLI compatibility easy to test. Most behavior is implemented through small SwiftUI views and backend command builders with tests covering command argument generation and parsing.

Common development commands:

```bash
swift test
scripts/build-app.sh
open build/AppleStack.app
```

See [RELEASE_NOTES.md](RELEASE_NOTES.md) for the current release scope, verification checklist, and known limitations.

## Roadmap

- Better coverage for every `container` CLI subcommand.
- More complete machine and builder workflows.
- Improved diagnostics when the Apple container system is not running.
- Import/export helpers for app settings.
- More localized strings and additional languages.
- Signed and notarized release builds.

## Contributing

Issues and pull requests are welcome. For UI changes, please keep the app native, compact, and consistent with macOS desktop conventions. For backend changes, prefer adding or updating tests that verify the exact `container` CLI arguments and output parsing behavior.

## License

AppleStack is released under the MIT License. See [LICENSE](LICENSE).
