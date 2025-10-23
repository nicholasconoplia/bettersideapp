import SwiftUI
import PhotosUI

struct InspirationInputView: View {
	@EnvironmentObject private var viewModel: VisualizationViewModel
	@Environment(\.dismiss) private var dismiss

	@State private var selectedCategory: InspirationCategory = .general
	@State private var description: String = ""
	@State private var selectedPhotoItem: PhotosPickerItem?
	@State private var selectedImage: UIImage?
	@State private var showCameraPicker = false

	var body: some View {
		NavigationStack {
			ZStack {
				GradientBackground.primary
					.ignoresSafeArea()

				ScrollView {
					VStack(spacing: 24) {
						headerSection
						categoryPicker
						imageSelector
						descriptionField
						applyButton
					}
					.padding()
					.padding(.bottom, 40)
				}
			}
			.navigationTitle("Add Inspiration")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
						.tint(.white)
				}
			}
		}
		.sheet(isPresented: $showCameraPicker) {
			CameraPickerView { image in
				selectedImage = image
			}
		}
		.onChange(of: selectedPhotoItem) { item in
			guard let item else { return }
			Task { await loadImage(from: item) }
		}
	}

	private var headerSection: some View {
		VStack(spacing: 12) {
			Image(systemName: "photo.stack.fill")
				.font(.system(size: 48))
				.foregroundStyle(
					LinearGradient(
						colors: [
							Color(red: 0.94, green: 0.34, blue: 0.56),
							Color(red: 1.0, green: 0.6, blue: 0.78)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)

			Text("Upload Inspiration")
				.font(.title2.bold())
				.foregroundStyle(.white)

			Text("Upload a photo of the look you want to try, and it will blend it with your image.")
				.font(.subheadline)
				.foregroundStyle(.white.opacity(0.75))
				.multilineTextAlignment(.center)
				.padding(.horizontal)
		}
	}

	private var categoryPicker: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("What kind of inspiration?")
				.font(.headline)
				.foregroundStyle(.white)

			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				ForEach(InspirationCategory.allCases, id: \.self) { category in
					Button {
						selectedCategory = category
					} label: {
						HStack {
							Image(systemName: category.systemImage)
								.font(.title3)
							Text(category.rawValue)
								.font(.subheadline.weight(.semibold))
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.fill(selectedCategory == category ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.stroke(selectedCategory == category ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
						)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}

	private var imageSelector: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Inspiration Photo")
				.font(.headline)
				.foregroundStyle(.white)

			if let image = selectedImage {
				Image(uiImage: image)
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 300)
					.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(Color.white.opacity(0.2), lineWidth: 1)
					)
					.shadow(color: .black.opacity(0.3), radius: 15, y: 10)
			} else {
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(Color.white.opacity(0.08))
					.frame(height: 200)
					.overlay(
						VStack(spacing: 12) {
							Image(systemName: "photo.badge.plus")
								.font(.system(size: 40))
								.foregroundStyle(.white.opacity(0.6))
							Text("No photo selected")
								.font(.subheadline)
								.foregroundStyle(.white.opacity(0.6))
						}
					)
			}

			HStack(spacing: 12) {
				PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
					Label("Choose Photo", systemImage: "photo.on.rectangle")
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				.tint(Color.white.opacity(0.18))

				Button { showCameraPicker = true } label: {
					Label("Take Photo", systemImage: "camera")
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				.tint(Color(red: 0.94, green: 0.34, blue: 0.56).opacity(0.7))
			}
		}
	}

	private var descriptionField: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Additional Details (Optional)")
				.font(.headline)
				.foregroundStyle(.white)

			TextField("E.g., 'Make it more subtle' or 'Keep my natural color'", text: $description, axis: .vertical)
				.textFieldStyle(.plain)
				.foregroundStyle(.white)
				.padding()
				.lineLimit(3...6)
				.background(Color.white.opacity(0.08))
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.stroke(Color.white.opacity(0.1), lineWidth: 1)
				)
		}
	}

	private var applyButton: some View {
		Button {
			guard let image = selectedImage else { return }
			Task {
				await viewModel.applyInspiration(
					image,
					category: selectedCategory,
					description: description.isEmpty ? nil : description
				)
				dismiss()
			}
		} label: {
			HStack(spacing: 12) {
				if viewModel.isProcessing {
					ProgressView()
						.progressViewStyle(.circular)
						.tint(.white)
				} else {
					Image(systemName: "wand.and.stars")
						.font(.headline.weight(.semibold))
					Text("Apply to My Photo")
						.font(.headline.weight(.semibold))
				}
			}
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(
						selectedImage == nil || viewModel.isProcessing
						? Color.white.opacity(0.2)
						: Color(red: 0.94, green: 0.34, blue: 0.56)
					)
			)
			.shadow(color: .black.opacity(0.2), radius: 12, y: 8)
		}
		.buttonStyle(.plain)
		.disabled(selectedImage == nil || viewModel.isProcessing)
		.padding(.top, 8)
	}

	private func loadImage(from item: PhotosPickerItem) async {
		do {
			if let data = try await item.loadTransferable(type: Data.self),
			   let image = UIImage(data: data) {
				await MainActor.run { selectedImage = image }
			}
		} catch {
			print("Failed to load image: \(error)")
		}
		await MainActor.run { selectedPhotoItem = nil }
	}
}

private struct CameraPickerView: UIViewControllerRepresentable {
	var onCapture: (UIImage) -> Void
	@Environment(\.dismiss) private var dismiss

	func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let controller = UIImagePickerController()
		controller.delegate = context.coordinator
		controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
		return controller
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

	final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		let parent: CameraPickerView

		init(parent: CameraPickerView) { self.parent = parent }

		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
			if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
			parent.dismiss()
		}

		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
	}
}


