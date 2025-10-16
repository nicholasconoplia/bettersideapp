//
//  PuterTestView.swift
//  glowup
//
//  Test view for Puter.js image generation integration
//

import SwiftUI

struct PuterTestView: View {
    @StateObject private var puterService = PuterImageService()
    @State private var prompt = ""
    @State private var showWebView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground.primary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "wand.and.stars.inverse")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                            
                            Text("Nano Banana Image Generator")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Powered by Puter.js - No API limits!")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Input Section
                        VStack(spacing: 16) {
                            TextField("Describe your image...", text: $prompt, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showWebView = true
                            } label: {
                                Label("Open Image Generator", systemImage: "photo.on.rectangle.angled")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.94, green: 0.34, blue: 0.56), Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(15)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Alternative Service Test
                        VStack(spacing: 16) {
                            Text("Or test the service directly:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button {
                                Task {
                                    await generateImageDirectly()
                                }
                            } label: {
                                HStack {
                                    if puterService.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(puterService.isLoading ? "Generating..." : "Generate Image")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            .disabled(puterService.isLoading || prompt.isEmpty)
                            .padding(.horizontal, 20)
                            
                            // Display generated image
                            if let image = puterService.generatedImage {
                                VStack(spacing: 12) {
                                    Text("Generated Image:")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(15)
                                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                                        .padding(.horizontal, 20)
                                    
                                    Button {
                                        saveImageToPhotos(image)
                                    } label: {
                                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            
                            // Display error
                            if let error = puterService.errorMessage {
                                Text("Error: \(error)")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to use:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                instructionRow("1.", "Enter a detailed description of the image you want")
                                instructionRow("2.", "Click 'Open Image Generator' to use the full interface")
                                instructionRow("3.", "Or use 'Generate Image' for direct generation")
                                instructionRow("4.", "Generated images can be saved to your Photos app")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("Nano Banana Test")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWebView) {
                PuterWebViewSheet(prompt: prompt)
            }
        }
    }
    
    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private func generateImageDirectly() async {
        guard !prompt.isEmpty else { return }
        puterService.generateImage(prompt: prompt)
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

// MARK: - WebView Sheet

struct PuterWebViewSheet: View {
    let prompt: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PuterImageView(
                prompt: .constant(prompt),
                generatedImage: .constant(nil),
                isLoading: .constant(false),
                errorMessage: .constant(nil)
            )
            .navigationTitle("Image Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PuterTestView()
}
