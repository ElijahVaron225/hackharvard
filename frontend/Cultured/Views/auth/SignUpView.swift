import SwiftUI
import Auth

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    
    var body: some View {
        ZStack {
            // Background color
            Color.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Title
                Text("Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.text)
                
                VStack(spacing: 16) {
                    // Username field
                    TextField("Username", text: $username)
                        .foregroundColor(.text)
                        .padding()
                        .background(Color.secondBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Email field
                    TextField("Email", text: $email)
                        .foregroundColor(.text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.secondBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .foregroundColor(.text)
                        .padding()
                        .background(Color.secondBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Confirm password field
                    SecureField("Confirm Password", text: $confirmPassword)
                        .foregroundColor(.text)
                        .padding()
                        .background(Color.secondBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                }
                .tint(.text)
                
                // Sign up button
                Button {
                    let user = User(id: UUID().uuidString, username: username, email: email, created_at: "")
                    Task {
                        try await Auth.shared.signUp(user: user, password: password)
                    }
                } label: {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.background)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primary)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Set placeholder text color globally
            UITextField.appearance().attributedPlaceholder = NSAttributedString(
                string: "",
                attributes: [.foregroundColor: UIColor(Color.text.opacity(0.5))]
            )
        }
    }
}
