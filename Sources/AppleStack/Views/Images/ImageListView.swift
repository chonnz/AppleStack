import SwiftUI

struct ImageListView: View {
    @Bindable var viewModel: ImageListViewModel
    @Binding var selectedImage: Image?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Images")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(viewModel.images.count) images")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SearchField(text: $viewModel.searchText, placeholder: "")
                    .frame(width: 160)

                Button {
                    viewModel.showPullSheet = true
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

            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredImages.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    SwiftUI.Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No images")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                imageList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $viewModel.showPullSheet) {
            PullImageSheet(viewModel: viewModel)
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
                    Task { await viewModel.loadImages() }
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadImages()
        }
    }

    private var imageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredImages) { image in
                    ImageRowView(
                        image: image,
                        isSelected: selectedImage?.id == image.id,
                        onDelete: { Task { await viewModel.deleteImage(image) } }
                    )
                    .onTapGesture {
                        selectedImage = image
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
    ImageListView(
        viewModel: ImageListViewModel(service: ContainerServiceFactory.create()),
        selectedImage: .constant(nil)
    )
}
