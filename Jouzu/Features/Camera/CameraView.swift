import SwiftUI
import PhotosUI
import Translation

struct CameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // App icon / hero area
                VStack(spacing: 12) {
                    Image("AppMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 124, height: 124)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color.red.opacity(0.22), radius: 18, y: 10)

                    Text("Jouzu")
                        .font(.largeTitle.bold())

                    Text("Photograph Japanese text to get\ninstant definitions and translations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        viewModel.captureFromCamera()
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("")
            .overlay {
                if viewModel.isProcessing {
                    ProgressOverlay()
                }
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                ImagePickerView(sourceType: .camera) { image in
                    viewModel.processImage(image)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            viewModel.processImage(image)
                        } else {
                            viewModel.errorMessage = "Could not read the selected photo."
                        }
                    } catch {
                        viewModel.errorMessage = "Failed to load photo: \(error.localizedDescription)"
                    }
                }
                selectedPhotoItem = nil
            }
            .navigationDestination(isPresented: showAnalysisBinding) {
                if let analysisViewModel = viewModel.analysisViewModel {
                    AnalysisView(viewModel: analysisViewModel)
                        .id(analysisViewModel.result.id)
                }
            }
            .background {
                TranslationCoordinatorView(
                    taskID: viewModel.translationTaskID,
                    configuration: viewModel.translationConfiguration
                ) { session in
                    await viewModel.handleTranslationSession(session)
                }
            }
        }
    }

    private var showAnalysisBinding: Binding<Bool> {
        Binding(
            get: { viewModel.analysisViewModel != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissAnalysis()
                }
            }
        )
    }
}

private struct TranslationCoordinatorView: View {
    let taskID: UUID
    let configuration: TranslationSession.Configuration?
    let action: @MainActor (TranslationSession) async -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .id(taskID)
            .translationTask(configuration) { session in
                await action(session)
            }
    }
}

// MARK: - Processing Overlay

private struct ProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Analyzing text...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - UIKit Camera Wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    CameraView()
        .modelContainer(PreviewSampleData.previewModelContainer)
}
