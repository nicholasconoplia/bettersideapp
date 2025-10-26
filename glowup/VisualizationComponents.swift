import SwiftUI

struct StudioContainerView: View {
    @EnvironmentObject private var visualizationViewModel: VisualizationViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        ZStack {
            TabView {
                VisualizeView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Visualize", systemImage: "wand.and.stars.inverse")
                    }
                NotesView()
                    .environmentObject(visualizationViewModel)
                    .tabItem {
                        Label("Notes", systemImage: "note.text")
                    }
            }
            .allowsHitTesting(subscriptionManager.isSubscribed)

            if !subscriptionManager.isSubscribed {
                VStack(spacing: 16) {
                    Text("Studio (Locked)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Try on hairstyles, makeup, and outfits powered by your analysis.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        SuperwallService.shared.registerEvent("subscription_paywall")
                    } label: {
                        Text("🔓 Unlock Full Analysis")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.94, green: 0.34, blue: 0.56),
                                        Color(red: 1.0, green: 0.6, blue: 0.78)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.45))
                .ignoresSafeArea()
            }
        }
    }
}
//
//  VisualizationComponents.swift
//  glowup
//
//  Reusable UI elements for the Visualize experience.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PresetCard: View {
    let category: VisualizationPresetCategory
    let option: VisualizationPresetOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    if let icon = option.iconName {
                        Image(systemName: icon)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: category.systemImageName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Spacer()

                    if let swatch = option.swatchHex {
                        let color = Color(hex: swatch)
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            )
                    }
                }

                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                if !option.subtitle.isEmpty {
                    Text(option.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EditThumbnail: View {
    let image: UIImage
    let isActive: Bool
    let tapAction: () -> Void

    var body: some View {
        Button(action: tapAction) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isActive ? Color.pink : Color.white.opacity(0.35), lineWidth: isActive ? 3 : 1)
                )
                .shadow(color: .black.opacity(isActive ? 0.35 : 0.2), radius: isActive ? 12 : 6, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct PromptInputBar: View {
    @Binding var text: String
    var placeholder: String = "Describe the look…"
    let onSubmit: () -> Void
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(GlowPalette.deepRose)
                .tint(GlowPalette.roseGold)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(GlowPalette.softBeige)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GlowPalette.roseGold.opacity(0.3), lineWidth: 1)
                )

            Button {
                onSubmit()
            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(GlowPalette.creamyWhite)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(GlowPalette.creamyWhite)
                }
            }
            .disabled(isLoading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GlowPalette.roseGold)
            )
            .opacity(isLoading ? 0.6 : 1)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            GlowGradient.canvas
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct ImageSourcePicker: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onUseAnalysis: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(GlowPalette.creamyWhite.opacity(0.35))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            Text("Start a Visualization")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowPalette.creamyWhite)

            VStack(spacing: 12) {
                pickerButton(
                    title: "Use Analysis Photo",
                    subtitle: "Reuse the image from your latest analysis.",
                    icon: "sparkles.rectangle.stack.fill",
                    action: onUseAnalysis
                )

                pickerButton(
                    title: "Capture with Camera",
                    subtitle: "Take a fresh photo to visualize.",
                    icon: "camera.fill",
                    action: onCamera
                )

                pickerButton(
                    title: "Choose from Library",
                    subtitle: "Import a saved photo from your device.",
                    icon: "photo.fill.on.rectangle.fill",
                    action: onLibrary
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(GlowPalette.deepRose.opacity(0.95))
        )
        .padding()
    }

    private func pickerButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(GlowPalette.creamyWhite)
                    .frame(width: 48, height: 48)
                    .background(GlowPalette.creamyWhite.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(GlowPalette.creamyWhite)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(GlowPalette.creamyWhite.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(GlowPalette.creamyWhite.opacity(0.6))
                    .font(.body.weight(.semibold))
            }
            .padding()
            .background(GlowPalette.creamyWhite.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct LoadingOverlay: View {
    let label: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.3)

            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 40)
    }
}

// Color(hex:) is defined globally in GlowTheme.swift
