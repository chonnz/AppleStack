import SwiftUI

struct BuilderView: View {
    @Environment(\.cliBackend) private var cliBackend
    @State private var output = ""
    @State private var errorMessage: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Builder", subtitle: isRunning ? "Running" : "Stopped") {
                Button("Status") { Task { await status() } }
                    .buttonStyle(.bordered)
                Button("Start") { Task { await start() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                Button("Stop") { Task { await stop() } }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
                Button("Delete") { Task { await delete() } }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
            }

            if let error = errorMessage {
                ErrorStateView(message: error, retryAction: { Task { await status() } })
            } else if output.isEmpty {
                EmptyStateView(icon: "hammer", title: "Builder", subtitle: "Start the builder to begin building images")
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(output)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .background(AppTheme.paneBackground)
        .task { await status() }
    }

    private func updateRunningState() {
        isRunning = output.localizedCaseInsensitiveContains("running")
    }

    private func status() async {
        await run { try await cliBackend.builderStatus(format: "json") }
        updateRunningState()
    }

    private func start() async {
        await runAction { try await cliBackend.builderStart() }
    }

    private func stop() async {
        await runAction { try await cliBackend.builderStop() }
    }

    private func delete() async {
        await runAction { try await cliBackend.builderDelete() }
    }

    private func run(_ operation: () async throws -> String) async {
        do {
            errorMessage = nil
            output = try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(_ operation: () async throws -> Void) async {
        do {
            errorMessage = nil
            try await operation()
            await status()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    BuilderView()
}
