import SwiftUI
import Auth

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sign Up")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Sign Up") {
                // Handle signup logic here
                let user = User(id: UUID().uuidString, username: username, email: email, created_at: "")
                Task {
                    try await Auth.shared.signUp(user: user, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
        
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
