import SwiftUI

struct VolumeListView: View {
    @State private var volumes: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
 @State private var newVolumeName = ""

    private let cliBackend = CLIBackend()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volumes")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(volumes.count) volumes")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showCreateSheet = true
                } label: {
                    SwiftUI.Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadVolumes() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if volumes.isEmpty {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "externaldrive")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No volumes")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                volumeList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showCreateSheet) {
            createVolumeSheet
        }
        .task {
            await loadVolumes()
        }
    }

    private var volumeList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(volumes, id: \.self) { volume in
                    HStack(spacing: 12) {
                        SwiftUI.Image(systemName: "externaldrive.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .frame(width: 28, height: 28)
                            .padding(.leading, 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            deleteVolume(volume)
                        } label: {
                            SwiftUI.Image(systemName: "trash")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Delete volume")
                        .padding(.trailing, 8)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)

                    Divider()
                        .padding(.leading, 48)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var createVolumeSheet: some View {
        VStack(spacing: 16) {
            Text("Create Volume")
                .font(.headline)

            TextField("Volume name", text: $newVolumeName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showCreateSheet = false
                    newVolumeName = ""
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    createVolume(newVolumeName)
                    showCreateSheet = false
                    newVolumeName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newVolumeName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 180)
    }

    // MARK: - Actions

    private func loadVolumes() async {
        isLoading = true
        errorMessage = nil
        do {
            volumes = try await cliBackend.listVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createVolume(_ name: String) {
        Task {
            do {
                try await cliBackend.createVolume(name: name)
                await loadVolumes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteVolume(_ name: String) {
        Task {
            do {
                try await cliBackend.removeVolume(name: name)
                await loadVolumes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    VolumeListView()
}
