import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    @State private var goToContext = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Button("Login") {
                    Task {
                        await signInAndMaybeNavigate()
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
            .navigationDestination(isPresented: $goToContext) {
                ContentView()   // push regardless of email verification, see logic below
            }
        }
    }

    @MainActor
    private func signInAndMaybeNavigate() async {
        print("🚀 Login button tapped - starting sign in process")
        do {
            try await Auth.shared.signIn(email: email, password: password)
            print("✅ Sign in successful, navigating to content")
            // Signed in successfully -> go to content
            goToContext = true
        } catch {
            print("❌ Sign in failed with error: \(error)")
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
