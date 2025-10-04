
import SwiftUI

struct CreateView: View {
    @State private var userInput: String = ""
    @State private var interpretedText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Give ")
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
        interpretedText = analysis.formattedOutput
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
