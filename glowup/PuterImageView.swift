//
//  PuterImageView.swift
//  glowup
//
//  SwiftUI WebView wrapper for Puter.js Nano Banana image generation
//

import SwiftUI
import WebKit

struct PuterImageView: UIViewRepresentable {
    @Binding var prompt: String
    @Binding var generatedImage: UIImage?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // Load the HTML file
        if let htmlURL = Bundle.main.url(forResource: "puter_image_generator", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update prompt if needed
        if !prompt.isEmpty {
            let script = """
                document.getElementById('prompt').value = '\(prompt.replacingOccurrences(of: "'", with: "\\'"))';
            """
            webView.evaluateJavaScript(script)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PuterImageView
        
        init(_ parent: PuterImageView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("PuterImageView: WebView loaded successfully")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("PuterImageView: Navigation failed: \(error.localizedDescription)")
            parent.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Puter Image Generation Service

class PuterImageService: ObservableObject {
    @Published var generatedImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var webView: WKWebView?
    
    func generateImage(prompt: String) {
        guard !prompt.isEmpty else {
            errorMessage = "Please enter a prompt"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Create a new WebView for this generation
        let webView = WKWebView()
        webView.navigationDelegate = WebViewDelegate(
            onImageGenerated: { [weak self] image in
                DispatchQueue.main.async {
                    self?.generatedImage = image
                    self?.isLoading = false
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage = error
                    self?.isLoading = false
                }
            }
        )
        
        self.webView = webView
        
        // Load the HTML file
        if let htmlURL = Bundle.main.url(forResource: "puter_image_generator", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            
            // Wait for load to complete, then generate
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.executeGeneration(prompt: prompt, in: webView)
            }
        }
    }
    
    private func executeGeneration(prompt: String, in webView: WKWebView) {
        let script = """
            (async function() {
                try {
                    document.getElementById('prompt').value = '\(prompt.replacingOccurrences(of: "'", with: "\\'"))';
                    await new Promise(resolve => setTimeout(resolve, 500));
                    
                    const result = await puter.ai.txt2img('\(prompt.replacingOccurrences(of: "'", with: "\\'"))', { 
                        model: 'gemini-2.5-flash-image-preview' 
                    });
                    
                    return result.src;
                } catch (error) {
                    throw error.message || error;
                }
            })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                } else if let imageURL = result as? String {
                    self?.loadImageFromURL(imageURL)
                } else {
                    self?.errorMessage = "Failed to generate image"
                    self?.isLoading = false
                }
            }
        }
    }
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid image URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                } else if let data = data, let image = UIImage(data: data) {
                    self?.generatedImage = image
                    self?.isLoading = false
                } else {
                    self?.errorMessage = "Failed to load generated image"
                    self?.isLoading = false
                }
            }
        }.resume()
    }
}

// MARK: - WebView Delegate

class WebViewDelegate: NSObject, WKNavigationDelegate {
    let onImageGenerated: (UIImage) -> Void
    let onError: (String) -> Void
    
    init(onImageGenerated: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
        self.onImageGenerated = onImageGenerated
        self.onError = onError
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("PuterImageService: WebView loaded successfully")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onError(error.localizedDescription)
    }
}

// MARK: - SwiftUI View for Testing

struct PuterImageView_Previews: PreviewProvider {
    static var previews: some View {
        @State var prompt = "A beautiful sunset over mountains"
        @State var generatedImage: UIImage? = nil
        @State var isLoading = false
        @State var errorMessage: String? = nil
        
        return PuterImageView(
            prompt: $prompt,
            generatedImage: $generatedImage,
            isLoading: $isLoading,
            errorMessage: $errorMessage
        )
    }
}
