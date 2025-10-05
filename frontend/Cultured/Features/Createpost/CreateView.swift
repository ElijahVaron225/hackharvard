
import SwiftUI

struct CreateView: View {
    @State private var userInput: String = ""
    @State private var interpretedText: String = ""
    
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
        }
    }
    
    // REPLACE YOUR OLD interpretParagraph() WITH THIS:
    func interpretParagraph() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            interpretedText = "Please enter some text first."
            return
        }
        
        // Use the ParagraphInterpreter struct
        let interpreter = ParagraphInterpreter(text: userInput)
        let analysis = interpreter.analyze()
        
        // Call backend API with the text analysis
        callBackendAPI(with: analysis)
        
        interpretedText = analysis.formattedOutput
    }
    
    // MARK: - Backend API Call
    func callBackendAPI(with analysis: TextAnalysis) {
        guard let url = URL(string: "http://localhost:8000/api/v1/api/send-prompt") else {
            print("❌ Invalid URL")
            return
        }
        
        // Create request body
        let requestBody: [String: Any] = [
            "prompt": analysis.formattedOutput
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            return
        }
        
        // Make the API call
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API call failed: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return
            }
            
            print("✅ API Response Status: \(httpResponse.statusCode)")
            
            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📝 API Response: \(jsonResponse)")
                        
                        // Update UI on main thread
                        DispatchQueue.main.async {
                            if let fileUrl = jsonResponse["file_url"] as? String {
                                // Handle the generated image URL
                                print("🖼️ Generated image URL: \(fileUrl)")
                                // You can store this URL or display it in your UI
                            }
                        }
                    }
                } catch {
                    print("❌ Error parsing JSON response: \(error)")
                }
            }
        }.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Color {
    static let brand = Color.accentColor
    static let surface = Color(.secondarySystemBackground)
}

extension Font {
    static let h1 = Font.system(size: 22, weight: .semibold)
    static let mono = Font.system(.body, design: .monospaced)
}
