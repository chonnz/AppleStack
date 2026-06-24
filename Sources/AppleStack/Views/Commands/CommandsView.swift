import SwiftUI

struct CommandsView: View {
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    private let sections: [CommandSection] = [
        .init(
            title: "Get started",
            icon: "info.circle.fill",
            tint: ModuleTint.commands,
            summary: "Use Apple container commands directly from macOS.",
            items: [
                .init(title: "System status", detail: "Check whether the container system is running.", command: "container system status"),
                .init(title: "Start system", detail: "Start Apple Containers when commands cannot connect.", command: "container system start"),
            ]
        ),
        .init(
            title: "Containers",
            icon: "cube.box.fill",
            tint: ModuleTint.containers,
            summary: "Create, run, inspect, and debug containers.",
            items: [
                .init(title: "Run a web server", detail: "Start a detached container and publish port 8080.", command: "container run -d --name web -p 8080:80 nginx:latest"),
                .init(title: "Create without starting", detail: "Prepare a container with CPU and memory limits.", command: "container create --name worker --cpus 2 --memory 1G alpine:latest"),
                .init(title: "List containers", detail: "Show all containers in JSON for scripting.", command: "container list --all --format json"),
                .init(title: "Open a shell", detail: "Run an interactive shell inside a container.", command: "container exec -it web /bin/sh"),
                .init(title: "Follow logs", detail: "Stream the latest container logs.", command: "container logs --follow -n 200 web"),
                .init(title: "Copy files", detail: "Copy files between the container and macOS.", command: "container copy web:/app/logs ./logs"),
                .init(title: "Export filesystem", detail: "Save a container filesystem as an archive.", command: "container export --output web.tar web"),
            ]
        ),
        .init(
            title: "Images",
            icon: "square.3.layers.3d.down.right",
            tint: ModuleTint.images,
            summary: "Pull, build, tag, move, and publish images.",
            items: [
                .init(title: "Pull image", detail: "Download an image from a registry.", command: "container image pull ubuntu:24.04"),
                .init(title: "Build image", detail: "Build from a Containerfile in the current directory.", command: "container build -f Containerfile -t local/app:latest ."),
                .init(title: "Tag image", detail: "Create a new reference for an existing image.", command: "container image tag local/app:latest ghcr.io/me/app:latest"),
                .init(title: "Push image", detail: "Upload an image to a registry.", command: "container image push ghcr.io/me/app:latest"),
                .init(title: "Save image", detail: "Export an image archive.", command: "container image save --output app.tar local/app:latest"),
                .init(title: "Load image", detail: "Import an image archive.", command: "container image load --input app.tar"),
            ]
        ),
        .init(
            title: "Storage & Network",
            icon: "network",
            tint: ModuleTint.networks,
            summary: "Manage volumes, networks, DNS, and socket publishing.",
            items: [
                .init(title: "Create volume", detail: "Create a persistent data volume.", command: "container volume create data && container volume list"),
                .init(title: "Create network", detail: "Create an isolated development network.", command: "container network create devnet && container network list"),
                .init(title: "List DNS entries", detail: "Inspect system DNS configuration.", command: "container system dns list"),
                .init(title: "Publish socket", detail: "Expose a Unix socket into the container.", command: "container run --publish-socket /tmp/app.sock:/run/app.sock image"),
            ]
        ),
        .init(
            title: "Machines & Builder",
            icon: "desktopcomputer",
            tint: ModuleTint.machines,
            summary: "Create Linux machines and manage the image builder.",
            items: [
                .init(title: "Create machine", detail: "Create an Ubuntu machine with resources and home mount.", command: "container machine create --name dev --cpus 4 --memory 8G --home-mount rw ubuntu:24.04"),
                .init(title: "Machine shell", detail: "Open a machine shell.", command: "container machine run --name dev"),
                .init(title: "Builder status", detail: "Inspect builder availability.", command: "container builder status"),
                .init(title: "Start builder", detail: "Start the image builder.", command: "container builder start"),
                .init(title: "Disk usage", detail: "Inspect system disk usage.", command: "container system df"),
                .init(title: "Properties", detail: "List system properties.", command: "container system property list"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: language.localized("Commands"), subtitle: "\(commandCount) \(language.localized("Apple container commands"))") {}

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sections) { section in
                        commandSectionView(section)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
        }
        .background(AppTheme.paneBackground)
    }

    private var commandCount: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }

    private func commandSectionView(_ section: CommandSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SwiftUI.Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.localized(section.title))
                        .font(.system(size: 18, weight: .semibold))
                    Text(language.localized(section.summary))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(section.items) { item in
                    commandEntryView(item)
                    if item.id != section.items.last?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(AppTheme.chromeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.subtleBorder, lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func commandEntryView(_ item: CommandEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(language.localized(item.title))
                    .font(.system(size: 13, weight: .semibold))
                Text(language.localized(item.detail))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(item.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.command, forType: .string)
            } label: {
                SwiftUI.Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(AppTheme.detailTabBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(language.localized("Copy"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct CommandSection: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let tint: Color
    let summary: String
    let items: [CommandEntry]
}

private struct CommandEntry: Identifiable {
    var id: String { title + command }
    let title: String
    let detail: String
    let command: String
}

#Preview {
    CommandsView()
}
