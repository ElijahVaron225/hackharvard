import SwiftUI
import Auth

struct LoginView: View {
    @Binding var showingSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Login") {
                // Handle login logic here
                Task {
                    try await Auth.shared.signIn(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Don't have an account? Sign Up") {
                showingSignUp = true
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}