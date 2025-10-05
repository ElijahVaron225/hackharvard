import SwiftUI
import Auth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    @State private var goToContext = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Title
                    Text("Login")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.text)

                    VStack(spacing: 16) {
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
                    }
                    .tint(.text)

                    // Error (if any)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, -8)
                    }

                    // Login button
                    Button {
                        Task {
                            await signInAndMaybeNavigate()
                        }
                    } label: {
                        Text("Login")
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
            .navigationDestination(isPresented: $goToContext) {
                ContentView()   // push regardless of email verification, see logic below
            }
        }
    }

    @MainActor
    private func signInAndMaybeNavigate() async {
        do {
            try await Auth.shared.signIn(email: email, password: password)
            // Signed in successfully -> go to content
            goToContext = true
        } catch {
            // If the error is only about email confirmation, still navigate.
            // (Adjust this check to match your Auth error type/message.)
            let msg = error.localizedDescription
            if msg.localizedCaseInsensitiveContains("confirm")
                || msg.localizedCaseInsensitiveContains("verification") {
                // Optionally keep a non-blocking note for the user
                errorMessage = "Email not confirmed yet. You can keep browsing; some features may be limited."
                goToContext = true
            } else {
                // Real error -> show message, don't navigate
                errorMessage = msg
            }
        }
    }
}
