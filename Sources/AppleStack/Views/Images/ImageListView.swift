import SwiftUI

struct ImageListView: View {
    @Bindable var viewModel: ImageListViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchField(text: $viewModel.searchText, placeholder: "Search images...")

                Button {
                    viewModel.showPullSheet = true
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
            }
            .padding()

            Divider()

            if viewModel.isLoading && viewModel.images.isEmpty {
                Spacer()
                ProgressView("Loading images...")
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
                        Task { await viewModel.loadImages() }
                    }
                }
                Spacer()
            } else if viewModel.filteredImages.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "photo.stack")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No images found")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(viewModel.filteredImages) { image in
                    ImageRowView(
                        image: image,
                        onDelete: { Task { await viewModel.deleteImage(image) } }
                    )
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Images")
        .sheet(isPresented: $viewModel.showPullSheet) {
            PullImageSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadImages()
        }
    }
}

#Preview {
    ImageListView(viewModel: ImageListViewModel(
        service: ContainerServiceFactory.create()
    ))
}
