import SwiftUI

struct BuilderView: View {
    @State private var output = ""
    @State private var errorMessage: String?
    private let cliBackend = CLIBackend()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            outputView
        }
        .background(AppTheme.paneBackground)
        .task {
            await status()
        }
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Builder")
                    .font(.system(size: 16, weight: .semibold))
                Text("Manage image builder instance")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Status") { Task { await status() } }
                .buttonStyle(.bordered)
            Button("Start") { Task { await start() } }
                .buttonStyle(.borderedProminent)
            Button("Stop") { Task { await stop() } }
                .buttonStyle(.bordered)
            Button("Delete") { Task { await delete() } }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
        }
        .padding(16)
        .background(AppTheme.paneBackground)
    }

    private var outputView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(errorMessage ?? (output.isEmpty ? "No builder output" : output))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(errorMessage == nil ? Color.primary : Color.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private func status() async {
        await run { try await cliBackend.builderStatus(format: "json") }
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
