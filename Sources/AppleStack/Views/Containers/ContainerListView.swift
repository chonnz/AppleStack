import SwiftUI

struct ContainerListView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selectedContainer: Container?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Containers")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(viewModel.containers.filter { $0.state == .running }.count) running")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SearchField(text: $viewModel.searchText, placeholder: "")
                    .frame(width: 160)

                Button {
                    viewModel.showCreateSheet = true
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

            if viewModel.isLoading && viewModel.containers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredContainers.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "shippingbox")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No containers")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                containerList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateContainerSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.showError },
            set: { viewModel.showError = $0 }
        )) {
            Button("OK") {
                viewModel.showError = false
            }
            if viewModel.errorMessage != nil {
                Button("Retry") {
                    viewModel.showError = false
                    Task { await viewModel.loadContainers() }
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadContainers()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var containerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredContainers) { container in
                    ContainerRowView(
                        container: container,
                        isSelected: selectedContainer?.id == container.id,
                        onStart: { Task { await viewModel.start(container) } },
                        onStop: { Task { await viewModel.stop(container) } },
                        onDelete: { Task { await viewModel.delete(container) } }
                    )
                    .onTapGesture {
                        selectedContainer = container
                    }

                    Divider()
                        .padding(.leading, 48)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ContainerListView(
        viewModel: ContainerListViewModel(service: ContainerServiceFactory.create()),
        selectedContainer: .constant(nil)
    )
}
