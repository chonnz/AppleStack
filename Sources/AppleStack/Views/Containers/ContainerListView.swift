import SwiftUI

// 使用 SwiftUI.Image 避免与自定义 Image 模型冲突
typealias SwiftUIImage = SwiftUI.Image

struct ContainerListView: View {
    @Bindable var viewModel: ContainerListViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchField(text: $viewModel.searchText, placeholder: "Search containers...")

                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(ContainerFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Toggle("All", isOn: $viewModel.showAllContainers)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("Show all containers including system")
                    .onChange(of: viewModel.showAllContainers) {
                        viewModel.toggleShowAll()
                    }

                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if viewModel.isLoading && viewModel.containers.isEmpty {
                Spacer()
                ProgressView("Loading containers...")
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await viewModel.loadContainers() }
                    }
                }
                Spacer()
            } else if viewModel.filteredContainers.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "shippingbox")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No containers found")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(viewModel.filteredContainers) { container in
                    ContainerRowView(
                        container: container,
                        onStart: { Task { await viewModel.start(container) } },
                        onStop: { Task { await viewModel.stop(container) } },
                        onDelete: { Task { await viewModel.delete(container) } }
                    )
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Containers")
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateContainerSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadContainers()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

#Preview {
    ContainerListView(viewModel: ContainerListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
