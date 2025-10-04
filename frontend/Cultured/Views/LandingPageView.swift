import SwiftUI
import Auth

struct LandingPageView: View {
    var body: some View {
        VStack {
            Button("Login") {
                LoginView()
            }
            Button("Sign Up") {
                SignUpView()
            }
        }
    }
}
