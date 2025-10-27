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
						.tint(GlowPalette.roseGold)
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
				.deepRoseText()

			Text("Upload a photo of the look you want to try, and it will blend it with your image.")
				.font(.subheadline)
				.foregroundStyle(GlowPalette.deepRose.opacity(0.75))
				.multilineTextAlignment(.center)
				.padding(.horizontal)
		}
	}

	private var categoryPicker: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("What kind of inspiration?")
				.font(.glowSubheading)
				.deepRoseText()

			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				ForEach(InspirationCategory.allCases, id: \.self) { category in
					Button {
						selectedCategory = category
					} label: {
						HStack {
							Image(systemName: category.systemImage)
								.font(.glowHeading)
							Text(category.rawValue)
								.font(.subheadline.weight(.semibold))
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.fill(selectedCategory == category ? GlowPalette.blushOverlay(0.35) : GlowPalette.softOverlay(0.8))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.stroke(selectedCategory == category ? GlowPalette.roseStroke(0.6) : GlowPalette.roseStroke(0.25), lineWidth: 2)
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
				.font(.glowSubheading)
				.deepRoseText()

			if let image = selectedImage {
				Image(uiImage: image)
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 300)
					.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.stroke(GlowPalette.roseStroke(0.45), lineWidth: 1)
					)
					.shadow(color: GlowShadow.soft.color.opacity(0.7), radius: 15, y: 10)
			} else {
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(GlowPalette.softOverlay(0.65))
				.frame(height: 200)
				.overlay(
					VStack(spacing: 12) {
						Image(systemName: "photo.badge.plus")
							.font(.system(size: 40))
							.foregroundStyle(GlowPalette.deepRose.opacity(0.6))
						Text("No photo selected")
							.font(.subheadline)
							.foregroundStyle(GlowPalette.deepRose.opacity(0.6))
					}
				)
				.overlay(
					RoundedRectangle(cornerRadius: 20, style: .continuous)
						.stroke(GlowPalette.roseStroke(0.35), lineWidth: 1)
				)
		}

			HStack(spacing: 12) {
				PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
					Label("Choose Photo", systemImage: "photo.on.rectangle")
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(GlowFilledButtonStyle())
				.tint(GlowPalette.roseStroke(0.3))

				Button { showCameraPicker = true } label: {
					Label("Take Photo", systemImage: "camera")
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(GlowFilledButtonStyle())
				.tint(Color(red: 0.94, green: 0.34, blue: 0.56).opacity(0.7))
			}
		}
	}

	private var descriptionField: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Additional Details (Optional)")
				.font(.glowSubheading)
				.deepRoseText()

			TextField("E.g., 'Make it more subtle' or 'Keep my natural color'", text: $description, axis: .vertical)
				.textFieldStyle(.plain)
				.deepRoseText()
				.padding()
				.lineLimit(3...6)
				.background(GlowPalette.softOverlay(0.8))
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.overlay(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.stroke(GlowPalette.roseStroke(0.3), lineWidth: 1)
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
						.tint(GlowPalette.roseGold)
				} else {
					Image(systemName: "wand.and.stars")
						.font(.headline.weight(.semibold))
					Text("Apply to My Photo")
						.font(.headline.weight(.semibold))
				}
			}
			.deepRoseText()
			.frame(maxWidth: .infinity)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(
						selectedImage == nil || viewModel.isProcessing
						? GlowPalette.roseStroke(0.45)
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

