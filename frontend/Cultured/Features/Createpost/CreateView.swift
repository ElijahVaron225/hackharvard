import SwiftUI

struct CreateView: View {
    @State private var userInput: String = ""
    @State private var interpretedText: String = ""
    @Environment(\.dismiss) private var dismiss
    
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
    }
    
    // MARK: - Interpret & Send
    func interpretParagraph() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            interpretedText = "Please enter some text first."
            return
        }
        
        // Use your existing types
        let interpreter = ParagraphInterpreter(text: userInput)
        let analysis = interpreter.analyze()
        
        // Update UI immediately
        interpretedText = analysis.formattedOutput
        
        // Call backend
        callBackendAPI(with: analysis)
    }
    
    // MARK: - Backend API Call
    struct RequestPayload: Encodable {
        let text: String      // <-- rename to whatever your API expects
    }
    
    func callBackendAPI(with analysis: TextAnalysis) {
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
        let payload = RequestPayload(text: analysis.formattedOutput)
        
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
                            try await CreatePostManager.shared.updatePost(post: Post(id: generationId, user_id: userID, thumbnail_url: supabaseThumbnail, user_scanned_item: "", generated_images: fileUrl, likes: 0, created_at: Date()))
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
