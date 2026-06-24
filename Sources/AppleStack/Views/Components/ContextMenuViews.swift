import SwiftUI

/// 容器行右键菜单
struct ContainerContextMenu: View {
    let container: Container
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onRemove: () -> Void
    let onInspect: () -> Void
    let onKill: () -> Void
    let onExport: () -> Void
    let onCopy: () -> Void
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Group {
            Button {
                onStart()
            } label: {
                Label(language.localized("Start"), systemImage: "play.fill")
            }
            .disabled(container.state == .running)

            Button {
                onStop()
            } label: {
                Label(language.localized("Stop"), systemImage: "stop.fill")
            }
            .disabled(container.state != .running)

            Button {
                onRestart()
            } label: {
                Label(language.localized("Restart"), systemImage: "arrow.clockwise")
            }
            .disabled(container.state != .running)

            Divider()

            Button {
                onInspect()
            } label: {
                Label(language.localized("Inspect"), systemImage: "info.circle")
            }

            Button {
                onExport()
            } label: {
                Label(language.localized("Export"), systemImage: "square.and.arrow.up")
            }

            Button {
                onCopy()
            } label: {
                Label(language.localized("Copy Files"), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                onKill()
            } label: {
                Label(language.localized("Kill"), systemImage: "bolt.fill")
            }
            .disabled(container.state != .running)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label(language.localized("Remove"), systemImage: "trash")
            }
        }
    }
}

/// 镜像行右键菜单
struct ImageContextMenu: View {
    let image: Image
    let onPull: () -> Void
    let onRemove: () -> Void
    let onInspect: () -> Void
    let onTag: () -> Void
    let onPush: () -> Void
    let onSave: () -> Void
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        Group {
            Button {
                onPull()
            } label: {
                Label(language.localized("Pull Latest"), systemImage: "arrow.down.circle")
            }

            Button {
                onInspect()
            } label: {
                Label(language.localized("Inspect"), systemImage: "info.circle")
            }

            Button {
                onTag()
            } label: {
                Label(language.localized("Tag"), systemImage: "tag")
            }

            Button {
                onPush()
            } label: {
                Label(language.localized("Push"), systemImage: "arrow.up.circle")
            }

            Button {
                onSave()
            } label: {
                Label(language.localized("Save"), systemImage: "square.and.arrow.down")
            }

            Divider()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label(language.localized("Remove"), systemImage: "trash")
            }
        }
    }
}

/// 批量操作工具栏
struct BatchOperationToolbar: View {
    let selectedCount: Int
    let onStartAll: () -> Void
    let onStopAll: () -> Void
    let onRemoveAll: () -> Void
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(selectedCount) \(language.localized("selected"))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                onStartAll()
            } label: {
                SwiftUI.Image(systemName: "play.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(language.localized("Start all selected"))

            Button {
                onStopAll()
            } label: {
                SwiftUI.Image(systemName: "stop.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(language.localized("Stop all selected"))

            Button(role: .destructive) {
                onRemoveAll()
            } label: {
                SwiftUI.Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(language.localized("Remove all selected"))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ContainerContextMenu(
            container: Container(
                id: "abc123",
                name: "test-container",
                image: "nginx:latest",
                status: .running,
                state: .running,
                created: "2 hours ago",
                ports: "8080:80",
                cpus: 2,
                memory: "512m"
            ),
            onStart: {},
            onStop: {},
            onRestart: {},
            onRemove: {},
            onInspect: {},
            onKill: {},
            onExport: {},
            onCopy: {}
        )

        BatchOperationToolbar(
            selectedCount: 3,
            onStartAll: {},
            onStopAll: {},
            onRemoveAll: {}
        )
    }
    .padding()
}
