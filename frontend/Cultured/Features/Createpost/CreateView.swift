import SwiftUI
import UIKit
// Entry points and results used below:
// - Video flow entry points: `VideoCaptureView` (camera, full-screen) and `VideoLibraryPicker` (library, sheet)
//   from `Cultured/Features/Createpost/Video/UI.swift`. They handle permissions internally and return a local URL via closure.
// - Upload service: `VideoUploadService.uploadVideo(from:)` from `Cultured/Features/Createpost/Video/VideoUploadService.swift`
//   returns a public URL (String) on success. We store that String in local state and include it in the post update payload.
// - Feature flag read: `video.attach.enabled` read from `supabase.plist` (default false). When false, CreateView behaves exactly as before.

struct CreateView: View {
    @State private var userInput: String = ""
    @State private var interpretedText: String = ""
    @State private var showLogin = false
    // Video attach state (optional / compilation-safe)
    @State private var showRecorder = false
    @State private var showLibrary = false
    @State private var isUploadingVideo = false
    @State private var attachedVideoPublicURL: String? = nil // Final public reference used in post payload if present
    @State private var lastPickedLocalVideoURL: URL? = nil // For lightweight UI indicator
    @State private var showVideoSourcePicker = false
    @State private var videoErrorMessage: String? = nil
    // Image attach state (optional / compilation-safe)
    @State private var showImageLibrary = false
    @State private var isUploadingImage = false
    @State private var attachedImagePublicURL: String? = nil // Final public reference used in post payload if present
    @State private var pickedImageThumbnail: UIImage? = nil // For lightweight UI indicator
    @Environment(\.dismiss) private var dismiss
    private let videoUploadService = VideoUploadService()
    private let imageUploadService = ImageUploadService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Please describe your item in as much detail as possible. Let me know what the item is, what it is used for, and any important features or characteristics that make it unique. You can also include context, such as where it is commonly found, why it is valuable or interesting, and anything else you think would help others understand it better.")
                        .font(.headline)
                    
                    TextEditor(text: $userInput)
                        .frame(height: 200)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Add Video button (feature-flagged). Visible only when `video.attach.enabled` is true.
                if isVideoAttachEnabled {
                    Button {
                        showVideoSourcePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "paperclip")
                            Text("Add Video")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(isUploadingVideo)
                }

                // Add Image button (feature-flagged). Visible only when `image.attach.enabled` is true.
                if isImageAttachEnabled {
                    Button {
                        showImageLibrary = true
                    } label: {
                        HStack {
                            Image(systemName: "photo")
                            Text("Add Image")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(isUploadingImage)
                }

                // Submit Button
                Button(action: interpretParagraph) {
                    Text("Submit")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Output Section
                if !interpretedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interpreted Output:")
                            .font(.headline)
                        
                        ScrollView {
                            Text(interpretedText)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Lightweight indicator when a video is attached (reuses simple text styling pattern)
                if let localURL = lastPickedLocalVideoURL {
                    VStack(spacing: 6) {
                        Text("Video attached: \(localURL.lastPathComponent)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        if isUploadingVideo {
                            ProgressView("Uploading video...")
                                .padding(.top, 2)
                        } else if attachedVideoPublicURL != nil {
                            Text("Ready to post")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                }

                // Lightweight indicator when an image is attached
                if pickedImageThumbnail != nil {
                    VStack(spacing: 6) {
                        Text("Image attached")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        if isUploadingImage {
                            ProgressView("Uploading image...")
                                .padding(.top, 2)
                        } else if attachedImagePublicURL != nil {
                            Text("Ready to post")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Paragraph Interpreter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        // Present existing video flows using the same entry points as in Video/UI.swift
        // Camera capture (full-screen)
        .fullScreenCover(isPresented: $showRecorder) {
            VideoCaptureView { url in
                handlePickedLocalVideo(url)
            } onCancel: {
                // Cancel is non-blocking; no state changes required
            }
            .ignoresSafeArea()
        }
        // Library picker (sheet)
        .sheet(isPresented: $showLibrary) {
            VideoLibraryPicker { url in
                handlePickedLocalVideo(url)
            } onCancel: {
                // Cancel is non-blocking; no state changes required
            }
        }
        // Image library picker (sheet)
        .sheet(isPresented: $showImageLibrary) {
            ImageLibraryPicker { image in
                handlePickedImage(image)
            } onCancel: {
                // Non-blocking; do nothing
            }
        }
        // Source picker (record vs library) matching existing module capabilities
        .confirmationDialog("Add Video", isPresented: $showVideoSourcePicker, titleVisibility: .visible) {
            Button("Record Video") { showRecorder = true }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        // Non-blocking error notice via alert if upload fails
        .alert("Video Error", isPresented: .constant(videoErrorMessage != nil), actions: {
            Button("OK") { videoErrorMessage = nil }
        }, message: {
            Text(videoErrorMessage ?? "")
        })
    }
    
    // MARK: - Interpret & Send
    func interpretParagraph() {
        // Check if user is logged in first
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            interpretedText = "Please enter some text first."
            return
        }
        
        // Validate authentication and try to restore session if needed
        Task {
            let isAuthenticated = await Auth.shared.ensureAuthenticated()
            
            await MainActor.run {
                guard isAuthenticated else {
                    showLogin = true
                    return
                }
                
                // Continue with the interpretation process
                continueInterpretation()
            }
        }
    }
    
    private func continueInterpretation() {
        // Use your existing types
        let interpreter = ParagraphInterpreter(text: userInput)
        let analysis = interpreter.analyze()
        
        // Update UI immediately
        interpretedText = analysis.formattedOutput
        
        // First create a post, then call backend to generate content
        Task {
            do {
                try await CreatePostManager.shared.createPost()
                // Get the post_id from the created post
                let postId = CreatePostManager.shared.post?.id
                callBackendAPI(with: analysis, userInput: userInput, postId: postId)
            } catch {
                print("❌ Error creating post: \(error)")
                DispatchQueue.main.async {
                    interpretedText = "Error creating post: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Backend API Call
    struct RequestPayload: Encodable {
        let text: String
        let post_id: String?
    }
    
    func callBackendAPI(with analysis: TextAnalysis, userInput: String, postId: String?) {
        guard let url = URL(string: "https://hackharvard-u5gt.onrender.com/api/v1/api/prompts/workflow") else {
            print("❌ Invalid URL")
            return
        }
        
        let userID = Auth.shared.userID ?? "Anonymous"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Build a proper JSON object payload (top-level dictionary)
        let payload = RequestPayload(text: analysis.formattedOutput, post_id: postId)
        
        print("📤 Sending workflow request with post_id: \(postId ?? "nil")")
        
        // Encode with JSONEncoder (handles dates etc if you add them later)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes] // nice-to-have
            request.httpBody = try encoder.encode(payload)
        } catch {
            print("❌ Error encoding request body: \(error)")
            return
        }
        
        // Log AFTER setting the body
        if let body = request.httpBody, let s = String(data: body, encoding: .utf8) {
            print("📦 HTTP Body (utf8):\n\(s)")
        } else {
            print("📭 HTTP Body is nil or not UTF-8")
        }
        print(request.curlString) // handy copy/paste for debugging
        
        // Make the API call
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API call failed: \(error)")
                DispatchQueue.main.async {
                    dismiss()
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return
            }
            print("✅ API Response Status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ No data in response")
                return
            }
            
            // Try JSON first, fall back to raw string
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📝 API Response JSON: \(json)")
                    // Extract all the URLs from the response
                    let fileUrl = json["file_url"] as? String
                    let thumbUrl = json["thumb_url"] as? String
                    let supabaseGenerated = json["supabase_generated"] as? String
                    let supabaseThumbnail = json["supabase_thumbnail"] as? String
                    let generationId = json["generation_id"] as? String
                    
                    print("🖼️ Generated image URL: \(fileUrl ?? "nil")")
                    print("📸 Thumbnail URL: \(thumbUrl ?? "nil")")
                    print("☁️ Supabase Generated URL: \(supabaseGenerated ?? "nil")")
                    print("☁️ Supabase Thumbnail URL: \(supabaseThumbnail ?? "nil")")
                    print("🆔 Generation ID: \(generationId ?? "nil")")
                    
                    // TODO: Now you can use these URLs to update your Post
                    // You can call CreatePostManager.shared.updatePost() with these URLs
                    Task {
                        do {
                            // Include optional attached media URLs if available (non-breaking). Server contract remains unchanged for non-media posts.
                            try await CreatePostManager.shared.updatePost(post: Post(id: generationId, user_id: userID, thumbnail_url: supabaseThumbnail, user_scanned_item: "", generated_images: fileUrl, video_url: attachedVideoPublicURL, image_url: attachedImagePublicURL, likes: 0, created_at: Date()))
                        } catch {
                            print("❌ Error updating post: \(error)")
                        }
                    }
                    
                    // Dismiss the view and return to ContentView
                    DispatchQueue.main.async {
                        dismiss()
                    }
                } else if let str = String(data: data, encoding: .utf8) {
                    print("📝 API Response (text): \(str)")
                } else {
                    print("📝 API Response (bytes): \(data.count)")
                }
            } catch {
                print("❌ Error parsing JSON response: \(error)")
                if let str = String(data: data, encoding: .utf8) {
                    print("Raw response:\n\(str)")
                }
            }
        }.resume()
    }
}

// MARK: - Preview
struct CreateView_Previews: PreviewProvider {
    static var previews: some View {
        CreateView()
    }
}

// MARK: - Nice curl logger (optional)
extension URLRequest {
    var curlString: String {
        var lines = ["curl -X \(httpMethod ?? "GET") '\(url?.absoluteString ?? "")'"]
        (allHTTPHeaderFields ?? [:]).forEach { k, v in lines.append("-H '\(k): \(v)'") }
        if let body = httpBody, let s = String(data: body, encoding: .utf8) {
            lines.append("--data '\(s)'")
        }
        return lines.joined(separator: " \\\n  ")
    }
}

// MARK: - Style helpers (unchanged)
extension Color {
    static let brand = Color.accentColor
    static let surface = Color(.secondarySystemBackground)
}
extension Font {
    static let h1 = Font.system(size: 22, weight: .semibold)
    static let mono = Font.system(.body, design: .monospaced)
}

// MARK: - Private helpers for feature flag and video handling
private extension CreateView {
    var isVideoAttachEnabled: Bool {
        // Read from supabase.plist to avoid changing Info.plist; defaults to false when missing or invalid.
        guard let url = Bundle.main.url(forResource: "supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return false }
        if let b = dict["video.attach.enabled"] as? Bool { return b }
        if let s = dict["video.attach.enabled"] as? String { return (s as NSString).boolValue }
        return false
    }
    
    func handlePickedLocalVideo(_ url: URL) {
        lastPickedLocalVideoURL = url
        attachedVideoPublicURL = nil
        isUploadingVideo = true
        Task {
            do {
                let publicURL = try await videoUploadService.uploadVideo(from: url)
                await MainActor.run {
                    attachedVideoPublicURL = publicURL
                    isUploadingVideo = false
                }
            } catch {
                print("❌ Upload failed: \(error.localizedDescription)")
                await MainActor.run {
                    isUploadingVideo = false
                    videoErrorMessage = error.localizedDescription
                }
            }
        }
    }
    var isImageAttachEnabled: Bool {
        guard let url = Bundle.main.url(forResource: "supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return false }
        if let b = dict["image.attach.enabled"] as? Bool { return b }
        if let s = dict["image.attach.enabled"] as? String { return (s as NSString).boolValue }
        return false
    }
    
    func handlePickedImage(_ image: UIImage) {
        pickedImageThumbnail = image
        attachedImagePublicURL = nil
        isUploadingImage = true
        Task {
            do {
                let publicURL = try await imageUploadService.uploadImage(image)
                await MainActor.run {
                    attachedImagePublicURL = publicURL
                    isUploadingImage = false
                }
            } catch {
                print("❌ Image upload failed: \(error.localizedDescription)")
                await MainActor.run {
                    isUploadingImage = false
                }
            }
        }
    }
}

// MARK: - Minimal UIKit image picker adapter (library only, parallel to video picker)
struct ImageLibraryPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage) -> Void
    var onCancel: (() -> Void)?
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = ["public.image"]
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .formSheet
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImageLibraryPicker
        init(parent: ImageLibraryPicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.onPicked(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCancel?()
        }
    }
}
